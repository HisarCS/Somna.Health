//
//  SomnaDeviceView.swift
//  SleepApp
//
//  The "Wisp" tab: Somna wrist device over BLE - Wisp's mood, the latest
//  30 s values, connection state and recent records.
//

import SwiftUI

struct SomnaDeviceView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var ble = SomnaBLEManager.shared

    @State private var breathe = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    wispCard
                    if ble.latest != nil {
                        SectionHeader(title: "Live vitals", trailing: "every 30 s")
                        metricsGrid
                        moodRibbon
                        recentList
                    }
                    Text("Somna is a prototype for wellness insight, not a medical device.")
                        .font(DS.Typography.footnote)
                        .foregroundStyle(themeManager.theme.mutedTextColor)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, DS.Spacing.xs)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.xl)
            }
            .background(themeManager.theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Wisp")
        }
    }

    // MARK: - Wisp

    private var currentMood: WispMood {
        guard ble.state == .connected || isFresh else { return .search }
        return ble.latest?.mood ?? .search
    }

    /// Latest record younger than 2 sync windows.
    private var isFresh: Bool {
        guard let d = ble.latest?.date else { return false }
        return Date().timeIntervalSince(d) < 90
    }

    /// Siyah kadran: buyuk Wisp + ruh hali + baglanti durumu
    private var wispCard: some View {
        VStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [currentMood.color.opacity(0.55), currentMood.color.opacity(0)],
                                         center: .center, startRadius: 4, endRadius: 120))
                    .frame(width: 240, height: 240)
                    .scaleEffect(breathe ? 1.06 : 0.94)
                    .blur(radius: 6)
                Ellipse()
                    .fill(currentMood.color.opacity(0.35))
                    .frame(width: 100, height: 14)
                    .blur(radius: 8)
                    .offset(y: 84)
                WispView(mood: currentMood, size: 170, color: currentMood.color)
                    .id(currentMood)
            }
            .frame(height: 210)
            .onAppear {
                withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { breathe = true }
            }

            VStack(spacing: DS.Spacing.xs) {
                Text(currentMood.title + ".")
                    .font(DS.Typography.display)
                    .foregroundStyle(DS.Panel.text)
                    .multilineTextAlignment(.center)
                if currentMood == .breathe {
                    BreathGuide(color: currentMood.color)
                } else {
                    Text(currentMood.message)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Panel.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Rectangle().fill(DS.Panel.hairline).frame(height: 1)

            connectionRow
        }
        .watchPanel(padding: DS.Spacing.lg, glow: currentMood.color)
        .animation(DS.Motion.smooth, value: currentMood)
    }

    // MARK: - Connection

    private var connectionRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            Circle()
                .fill(stateColor)
                .frame(width: 9, height: 9)
                .shadow(color: stateColor, radius: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(ble.state.label)
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Panel.text)
                if let sync = ble.lastSync {
                    Text("Last update \(sync, style: .relative) ago")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Panel.secondary)
                } else if !ble.isPaired {
                    Text("Turn on Somna and keep it close to your phone.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Panel.secondary)
                }
            }
            Spacer()
            if ble.isPaired {
                Menu {
                    Button("Reconnect") { ble.start() }
                    Button("Forget device", role: .destructive) { ble.forget() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.bold))
                        .foregroundStyle(DS.Panel.text)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
            } else {
                Button("Connect") { ble.start() }
                    .font(DS.Typography.callout.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Metric.sleepLight, in: Capsule())
            }
        }
    }

    private var stateColor: Color {
        switch ble.state {
        case .connected: return DS.Metric.readinessGlow
        case .waiting, .connecting, .searching: return DS.Metric.quality
        default: return DS.Panel.muted
        }
    }

    // MARK: - Values

    /// Son ~10 dakikanin (20 kayit) degerleri, mini grafik icin
    private func series(_ value: (SomnaRecord) -> Double?) -> [Double] {
        ble.records.suffix(20).compactMap(value)
    }

    private var metricsGrid: some View {
        let r = ble.latest
        let heart = series { rec in rec.bpm.map { Double($0) } }
        let hrv = series { rec in rec.rmssd.map { Double($0) } }
        let oxygen = series { rec in rec.spo2.map { Double($0) } }
        let skin = series { rec in rec.temperature }
        let steps = ble.records.suffix(20).map { Double($0.steps) }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Spacing.sm), GridItem(.flexible())], spacing: DS.Spacing.sm) {
            metric("Heart rate", r?.bpm.map { "\($0)" }, unit: "BPM", icon: "heart.fill", tint: DS.Metric.heart, spark: heart)
            metric("HRV (RMSSD)", r?.rmssd.map { "\($0)" }, unit: "ms", icon: "waveform.path.ecg", tint: DS.Metric.hrv, spark: hrv)
            metric("SpO2", r?.spo2.map { "\($0)" }, unit: "%", icon: "lungs.fill", tint: DS.Metric.sleep, spark: oxygen)
            metric("Skin temp", r?.temperature.map { String(format: "%.1f", $0) }, unit: "°C",
                   icon: "thermometer.medium", tint: DS.Metric.strain, spark: skin)
            metric("Steps today", "\(ble.stepsToday)", unit: "", icon: "figure.walk", tint: DS.Metric.readiness,
                   spark: steps.contains(where: { $0 > 0 }) ? steps : [])
            metric("Updated", r.map { $0.date.formatted(date: .omitted, time: .shortened) }, unit: "",
                   icon: "clock", tint: themeManager.theme.secondaryTextColor, spark: [])
        }
    }

    private func metric(_ title: String, _ value: String?, unit: String, icon: String, tint: Color, spark: [Double]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            CardLabel(title: title, icon: icon, color: tint)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value ?? "--")
                    .font(DS.Typography.value)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(themeManager.theme.headingColor)
                Text(unit)
                    .font(DS.Typography.caption.weight(.medium))
                    .foregroundStyle(themeManager.theme.secondaryTextColor)
            }
            // son ~10 dakika: yon gosterir, sayi degil
            Group {
                if spark.count >= 2 {
                    Sparkline(values: spark, color: tint)
                } else {
                    Color.clear
                }
            }
            .frame(height: 30)
        }
        .somnaCard(padding: DS.Spacing.md)
    }

    // MARK: - Wisp today (gunun ruh hali seridi)

    private var todayRecords: [SomnaRecord] {
        let start = Calendar.current.startOfDay(for: Date())
        return Array(ble.records.filter { $0.date >= start }.suffix(60))
    }

    private func moodWord(_ m: WispMood) -> String {
        switch m {
        case .calm: return "calm"
        case .active: return "on the move"
        case .sleepy: return "sleepy"
        case .tense: return "tense"
        case .tired: return "tired"
        case .proud: return "proud"
        case .breathe: return "breathing slowly"
        case .listen: return "listening"
        case .search, .unknown: return "off your wrist"
        }
    }

    private var moodRibbon: some View {
        let today = todayRecords
        let counts = Dictionary(grouping: today, by: { $0.mood }).mapValues { $0.count }
        let dominant = counts.max { $0.value < $1.value }?.key
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            CardLabel(title: "Wisp today", icon: "drop.fill", color: dominant?.color ?? themeManager.theme.primaryColor)
            HStack(spacing: 2) {
                ForEach(today) { rec in
                    Capsule()
                        .fill(rec.mood.color)
                        .frame(maxWidth: 10)
                        .frame(height: 22)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let dominant {
                Text("Mostly \(moodWord(dominant)), from \(today.count) readings")
                    .font(DS.Typography.caption)
                    .foregroundStyle(themeManager.theme.secondaryTextColor)
            }
        }
        .somnaCard(padding: DS.Spacing.md)
    }

    // MARK: - Recent records

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardLabel(title: "Recent", icon: "list.bullet", color: themeManager.theme.primaryColor)
                .padding(.bottom, DS.Spacing.xs)
            ForEach(Array(ble.records.suffix(10).reversed().enumerated()), id: \.element.id) { index, r in
                HStack(spacing: DS.Spacing.sm) {
                    Circle().fill(r.mood.color).frame(width: 8, height: 8)
                    Text(r.date.formatted(date: .omitted, time: .standard))
                        .font(DS.Typography.caption.monospacedDigit())
                        .foregroundStyle(themeManager.theme.secondaryTextColor)
                        .frame(width: 78, alignment: .leading)
                    Text(r.bpm.map { "\($0) bpm" } ?? "-- bpm")
                    Spacer()
                    Text(r.rmssd.map { "\($0) ms" } ?? "--")
                    Spacer()
                    Text(r.spo2.map { "\($0)%" } ?? "--")
                    Spacer()
                    Text(r.mood.title)
                        .font(DS.Typography.caption.weight(.medium))
                        .foregroundStyle(r.mood.color)
                        .lineLimit(1)
                }
                .font(.system(.subheadline, design: .rounded).monospacedDigit())
                .foregroundStyle(themeManager.theme.textColor)
                .padding(.vertical, DS.Spacing.xs)
                if index < min(ble.records.count, 10) - 1 {
                    Divider().overlay(themeManager.theme.stroke)
                }
            }
        }
        .somnaCard(padding: DS.Spacing.md)
    }
}
