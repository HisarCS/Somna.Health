//
//  SomnaRecord.swift
//  SleepApp
//
//  One 30-second summary from the Somna wrist device (BLE protocol v1).
//  The device packs it into 18 bytes, little-endian:
//    ver u8 | seq u32 | time u32 | bpm u8 | rmssd u8 | spo2 u8 |
//    temp i16 (0.01 C) | steps u16 | mood u8 | flags u8
//

import Foundation

/// Wisp's mood, same order as MOODS in somna_avatar.py on the device.
enum WispMood: Int, Codable, CaseIterable {
    case search = 0, listen, proud, breathe, tired, active, tense, sleepy, calm
    case unknown = 255

    var title: String {
        switch self {
        case .search: return "Looking for you"
        case .listen: return "Listening"
        case .proud: return "Proud of you"
        case .breathe: return "Let's breathe"
        case .tired: return "A bit tired"
        case .active: return "On the move"
        case .tense: return "A little tense"
        case .sleepy: return "Sleepy"
        case .calm: return "Calm"
        case .unknown: return "Wisp"
        }
    }

    var message: String {
        switch self {
        case .search: return "Put Somna on your wrist so I can feel your pulse."
        case .listen: return "Reading your heartbeat, hold still for a moment."
        case .proud: return "Another 1000 steps. Nice work!"
        case .breathe: return "Slow down with me: in for 4, out for 6."
        case .tired: return "You've walked a lot today. A short rest would help."
        case .active: return "Keep going, your body likes this."
        case .tense: return "Your heart is racing while you're sitting. Try a short break."
        case .sleepy: return "Your body is winding down."
        case .calm: return "Everything looks steady."
        case .unknown: return ""
        }
    }
}

struct SomnaRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let seq: UInt32
    let date: Date
    let bpm: Int?
    let rmssd: Int?
    let spo2: Int?
    let temperature: Double?
    let steps: Int
    let mood: WispMood
    let contact: Bool
    let still: Bool
    let timeSynced: Bool
    let motion: Bool

    static let byteCount = 18

    /// - Parameter uptimeOffset: phone time minus device uptime (seconds), used for
    ///   records made before the phone set the device clock.
    init?(data: Data, uptimeOffset: TimeInterval?) {
        let b = [UInt8](data)
        guard b.count >= Self.byteCount, b[0] == 1 else { return nil }

        func u16(_ i: Int) -> UInt16 { UInt16(b[i]) | (UInt16(b[i + 1]) << 8) }
        func u32(_ i: Int) -> UInt32 {
            UInt32(b[i]) | (UInt32(b[i + 1]) << 8) | (UInt32(b[i + 2]) << 16) | (UInt32(b[i + 3]) << 24)
        }

        id = UUID()
        seq = u32(1)
        let rawTime = TimeInterval(u32(5))
        let flags = b[17]
        contact = flags & 0x01 != 0
        still = flags & 0x02 != 0
        timeSynced = flags & 0x04 != 0
        motion = flags & 0x08 != 0

        if timeSynced {
            date = Date(timeIntervalSince1970: rawTime)
        } else if let offset = uptimeOffset {
            date = Date(timeIntervalSince1970: offset + rawTime)
        } else {
            date = Date()
        }

        bpm = b[9] == 0 ? nil : Int(b[9])
        rmssd = b[10] == 0 ? nil : Int(b[10])
        spo2 = b[11] == 0 ? nil : Int(b[11])
        let t = Int16(bitPattern: u16(12))
        temperature = t == Int16.min ? nil : Double(t) / 100.0
        steps = Int(u16(14))
        mood = WispMood(rawValue: Int(b[16])) ?? .unknown
    }
}

/// Status characteristic (16 bytes): fw u8 | last seq u32 | held u16 |
/// total steps u32 | flags u8 (bit0 time set) | uptime s u32
struct SomnaStatus: Equatable {
    let firmware: Int
    let lastSeq: Int
    let held: Int
    let totalSteps: Int
    let timeSet: Bool
    let uptime: TimeInterval

    init?(data: Data) {
        let b = [UInt8](data)
        guard b.count >= 16 else { return nil }
        func u16(_ i: Int) -> Int { Int(b[i]) | (Int(b[i + 1]) << 8) }
        func u32(_ i: Int) -> Int {
            Int(b[i]) | (Int(b[i + 1]) << 8) | (Int(b[i + 2]) << 16) | (Int(b[i + 3]) << 24)
        }
        firmware = Int(b[0])
        lastSeq = u32(1)
        held = u16(5)
        totalSteps = u32(7)
        timeSet = b[11] & 0x01 != 0
        uptime = TimeInterval(u32(12))
    }
}

/// Small local store (JSON in Application Support). Kept out of SwiftData on
/// purpose: the SwiftData store syncs to CloudKit, and a new model type would
/// need a production CloudKit schema change while the app is live.
enum SomnaRecordStore {
    private static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("somna_records.json")
    }

    static func load() -> [SomnaRecord] {
        guard let data = try? Data(contentsOf: url),
              let records = try? JSONDecoder().decode([SomnaRecord].self, from: data) else { return [] }
        return records
    }

    static func save(_ records: [SomnaRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
