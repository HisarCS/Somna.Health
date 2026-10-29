//
//  SomnaBLEManager.swift
//  SleepApp
//
//  Talks to the Somna wrist device over Bluetooth LE (protocol v1).
//
//  What happens on every connection:
//    1. subscribe to Summary (live records) and History (old records)
//    2. read Status  -> device uptime (to date old records) + reboot check
//    3. send the time (0x01)
//    4. ask for every record after the last one we have (0x02)
//    5. receive them, then confirm "I have up to seq N" (0x04)
//    6. while the app is on screen: live mode (0x03 01), each new record arrives at once
//
//  Reconnecting: after the first pairing the device's identifier is saved.
//  iOS keeps a connection request open forever, so every time Somna opens its
//  BLE window (every 30 s in the demo, 5 min in the product) the phone connects
//  by itself - also in the background, when the app has the
//  "Uses Bluetooth LE accessories" background mode.
//

import Foundation
import CoreBluetooth
import Combine

final class SomnaBLEManager: NSObject, ObservableObject {
    static let shared = SomnaBLEManager()

    enum ConnectionState: Equatable {
        case notStarted, bluetoothOff, unauthorized, searching, waiting, connecting, connected

        var label: String {
            switch self {
            case .notStarted: return "Not connected"
            case .bluetoothOff: return "Bluetooth is off"
            case .unauthorized: return "Bluetooth permission needed"
            case .searching: return "Searching for Somna..."
            case .waiting: return "Waiting for Somna"
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            }
        }
    }

    @Published private(set) var state: ConnectionState = .notStarted
    @Published private(set) var latest: SomnaRecord?
    @Published private(set) var records: [SomnaRecord] = []
    @Published private(set) var lastSync: Date?
    @Published private(set) var status: SomnaStatus?

    private enum UUIDs {
        static let service = CBUUID(string: "08A20001-8CB5-46AA-A904-125A62229120")
        static let summary = CBUUID(string: "08A20002-8CB5-46AA-A904-125A62229120")
        static let control = CBUUID(string: "08A20003-8CB5-46AA-A904-125A62229120")
        static let history = CBUUID(string: "08A20004-8CB5-46AA-A904-125A62229120")
        static let status = CBUUID(string: "08A20005-8CB5-46AA-A904-125A62229120")
    }

    private enum Keys {
        static let deviceID = "somnaDeviceID"
        static let lastSeq = "somnaLastSeq"
    }

    private enum Command: UInt8 {
        case setTime = 0x01, sendAfter = 0x02, mode = 0x03, ack = 0x04
    }

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var characteristics: [CBUUID: CBCharacteristic] = [:]
    private var uptimeOffset: TimeInterval?
    private var seenSeqs = Set<UInt32>()
    private var wantsLive = false
    private var ackTask: Task<Void, Never>?
    private let maxStored = 2 * 24 * 120        // two days of 30 s records

    var isPaired: Bool { UserDefaults.standard.string(forKey: Keys.deviceID) != nil }

    /// Highest seq with no gap below it (-1 = nothing yet).
    private var lastSeq: Int {
        get { UserDefaults.standard.object(forKey: Keys.lastSeq) as? Int ?? -1 }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lastSeq) }
    }

    private override init() {
        super.init()
        records = SomnaRecordStore.load()
        latest = records.last
    }

    // MARK: - Public

    /// First call shows the Bluetooth permission prompt.
    func start() {
        if central == nil {
            var options: [String: Any] = [CBCentralManagerOptionShowPowerAlertKey: true]
            if Self.hasBluetoothBackgroundMode {
                options[CBCentralManagerOptionRestoreIdentifierKey] = "somna.ble.central"
            }
            // queue nil = delegate callbacks on the main queue
            central = CBCentralManager(delegate: self, queue: nil, options: options)
        } else {
            connectOrScan()
        }
    }

    /// Unpair: the next start() searches for a device again.
    func forget() {
        if let p = peripheral { central?.cancelPeripheralConnection(p) }
        central?.stopScan()
        peripheral = nil
        characteristics = [:]
        UserDefaults.standard.removeObject(forKey: Keys.deviceID)
        lastSeq = -1
        seenSeqs = []
        state = .notStarted
    }

    /// App on screen -> live mode (every record at once); background -> eco.
    func setLive(_ live: Bool) {
        wantsLive = live
        sendMode()
    }

    /// Steps today (from the 30 s records).
    var stepsToday: Int {
        let start = Calendar.current.startOfDay(for: Date())
        return records.filter { $0.date >= start }.reduce(0) { $0 + $1.steps }
    }

    // MARK: - Connection

    private static var hasBluetoothBackgroundMode: Bool {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        return modes?.contains("bluetooth-central") ?? false
    }

    private func connectOrScan() {
        guard let central, central.state == .poweredOn else { return }

        if let p = peripheral {
            if p.state == .disconnected {
                central.connect(p)          // a pending connect never times out
                state = .waiting
            }
            return
        }
        if let idString = UserDefaults.standard.string(forKey: Keys.deviceID),
           let id = UUID(uuidString: idString),
           let known = central.retrievePeripherals(withIdentifiers: [id]).first {
            attach(known)
            central.connect(known)
            state = .waiting
            return
        }
        state = .searching
        central.scanForPeripherals(withServices: [UUIDs.service])
    }

    private func attach(_ p: CBPeripheral) {
        peripheral = p
        p.delegate = self
    }

    // MARK: - Commands

    private func le32(_ v: UInt32) -> [UInt8] {
        [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)]
    }

    private func write(_ bytes: [UInt8]) {
        guard let p = peripheral, p.state == .connected,
              let c = characteristics[UUIDs.control] else { return }
        p.writeValue(Data(bytes), for: c, type: .withResponse)
    }

    private func sendTime() {
        write([Command.setTime.rawValue] + le32(UInt32(Date().timeIntervalSince1970)))
    }

    private func requestHistory() {
        let after: UInt32 = lastSeq < 0 ? 0xFFFF_FFFF : UInt32(lastSeq)
        write([Command.sendAfter.rawValue] + le32(after))
    }

    private func sendMode() {
        write([Command.mode.rawValue, wantsLive ? 1 : 0])
    }

    /// Confirm a little after the last record of a burst, not after every record.
    private func scheduleAck() {
        ackTask?.cancel()
        ackTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, let self else { return }
            if self.lastSeq >= 0 {
                self.write([Command.ack.rawValue] + self.le32(UInt32(self.lastSeq)))
            }
            SomnaRecordStore.save(self.records)
        }
    }

    // MARK: - Incoming data

    private func handleStatus(_ data: Data) {
        guard let st = SomnaStatus(data: data) else { return }
        status = st
        uptimeOffset = Date().timeIntervalSince1970 - st.uptime
        // Device restarted -> its seq started again from 0
        if st.lastSeq < lastSeq || (st.lastSeq == 0 && st.held <= 1 && lastSeq > 0) {
            lastSeq = -1
            seenSeqs = []
        }
        sendTime()
        requestHistory()
        sendMode()
    }

    private func handleRecord(_ data: Data) {
        guard let r = SomnaRecord(data: data, uptimeOffset: uptimeOffset) else { return }
        lastSync = Date()
        guard !seenSeqs.contains(r.seq) else { return }
        seenSeqs.insert(r.seq)

        records.append(r)
        records.sort { $0.date < $1.date }
        if records.count > maxStored { records.removeFirst(records.count - maxStored) }
        if latest == nil || r.date >= (latest?.date ?? .distantPast) { latest = r }

        var s = lastSeq
        while seenSeqs.contains(UInt32(s + 1)) { s += 1 }
        lastSeq = s
        scheduleAck()
    }
}

// MARK: - CBCentralManagerDelegate

extension SomnaBLEManager: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: connectOrScan()
        case .poweredOff: state = .bluetoothOff
        case .unauthorized: state = .unauthorized
        default: break
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        if let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
           let p = restored.first {
            attach(p)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        central.stopScan()
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: Keys.deviceID)
        attach(peripheral)
        state = .connecting
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        state = .connected
        characteristics = [:]
        peripheral.discoverServices([UUIDs.service])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        characteristics = [:]
        guard self.peripheral != nil else { return }   // forgotten on purpose
        state = .waiting
        central.connect(peripheral)                      // wait for the next window
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        state = .waiting
        central.connect(peripheral)
    }
}

// MARK: - CBPeripheralDelegate

extension SomnaBLEManager: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == UUIDs.service }) else { return }
        peripheral.discoverCharacteristics(
            [UUIDs.summary, UUIDs.control, UUIDs.history, UUIDs.status], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        for c in service.characteristics ?? [] {
            characteristics[c.uuid] = c
            if c.uuid == UUIDs.summary || c.uuid == UUIDs.history {
                peripheral.setNotifyValue(true, for: c)
            }
        }
        if let st = characteristics[UUIDs.status] {
            peripheral.readValue(for: st)     // continues in handleStatus
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        switch characteristic.uuid {
        case UUIDs.status: handleStatus(data)
        case UUIDs.summary, UUIDs.history: handleRecord(data)
        default: break
        }
    }
}
