//
//  DetailComponents.swift
//  SleepApp
//
//  Skor detay ekranlari (Sleep, Readiness, Strain, Stress, Health) icin ortak sablon.
//  Halka yok: skor, bolgeli yatay skala uzerinde gosterilir (Apple Watch dili).
//

import SwiftUI

// MARK: - Degerlendirme skalalari (uygulamadaki esiklerle birebir ayni)

struct ScoreScale {
    struct Zone {
        let upperBound: Double   // bu bolgenin ust siniri (haric, son bolge dahil)
        let label: String
        let color: Color
    }

    let maxValue: Double
    let zones: [Zone]

    func zone(for value: Double) -> Zone {
        zones.first { value < $0.upperBound } ?? zones[zones.count - 1]
    }

    /// Uyku ve hazirlik: 0-49 Poor, 50-79 Fair, 80-100 Good
    static let hundred = ScoreScale(maxValue: 100, zones: [
        Zone(upperBound: 50, label: "Poor", color: DS.Metric.stressHigh),
        Zone(upperBound: 80, label: "Fair", color: DS.Metric.quality),
        Zone(upperBound: 101, label: "Good", color: DS.Metric.readinessGlow)
    ])

    /// Efor: 0-10 Light, 10-16 Moderate, 16-21 High
    static let strain = ScoreScale(maxValue: 21, zones: [
        Zone(upperBound: 10, label: "Light", color: DS.Metric.sleepGlow),
        Zone(upperBound: 16, label: "Moderate", color: DS.Metric.quality),
        Zone(upperBound: 22, label: "High", color: DS.Metric.strainGlow)
    ])

    /// Stres: 0-20 Low, 20-50 Moderate, 50-100 High
    static let stress = ScoreScale(maxValue: 100, zones: [
        Zone(upperBound: 20, label: "Low", color: DS.Metric.readinessGlow),
        Zone(upperBound: 50, label: "Moderate", color: DS.Metric.quality),
        Zone(upperBound: 101, label: "High", color: DS.Metric.stressHigh)
    ])
}

// MARK: - Bolgeli yatay skala

/// Skalanin bolgelerini ince bir serit olarak, skoru ise parlayan bir isaretci olarak gosterir.
struct ScaleBar: View {
    let value: Double
    let scale: ScoreScale
    var showsLabels: Bool = true

    @State private var animated: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    // Bolgeler
                    HStack(spacing: 3) {
                        ForEach(Array(scale.zones.enumerated()), id: \.offset) { index, zone in
                            let lower = index == 0 ? 0 : scale.zones[index - 1].upperBound
                            let upper = min(zone.upperBound, scale.maxValue)
                            Capsule()
                                .fill(zone.color.opacity(scale.zone(for: value).label == zone.label ? 0.9 : 0.28))
                                .frame(width: max((upper - lower) / scale.maxValue * w - 3, 4))
                        }
                    }
                    .frame(height: 8)

                    // Isaretci
                    let x = min(max(animated / scale.maxValue, 0), 1) * w
                    Circle()
                        .fill(.white)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(scale.zone(for: value).color, lineWidth: 4))
                        .shadow(color: scale.zone(for: value).color.opacity(0.8), radius: 8)
                        .offset(x: x - 9)
                }
                .frame(height: 18)
            }
            .frame(height: 18)

            if showsLabels {
                GeometryReader { geo in
                    HStack(spacing: 3) {
                        ForEach(Array(scale.zones.enumerated()), id: \.offset) { index, zone in
                            let lower = index == 0 ? 0 : scale.zones[index - 1].upperBound
                            let upper = min(zone.upperBound, scale.maxValue)
                            Text(zone.label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(scale.zone(for: value).label == zone.label ? zone.color : DS.Panel.muted)
                                .lineLimit(1)
                                .frame(width: max((upper - lower) / scale.maxValue * geo.size.width - 3, 4), alignment: .leading)
                        }
                    }
                }
                .frame(height: 14)
            }
        }
        .onAppear {
            withAnimation(.smooth(duration: 1.0).delay(0.15)) { animated = value }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(DS.Motion.smooth) { animated = newValue }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(scale.zone(for: value).label), \(Int(value)) of \(Int(scale.maxValue))")
    }
}

// MARK: - Hero panel (siyah kadran)

struct HeroStat: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let value: String
}

struct ScoreHeroPanel: View {
    let title: String
    let icon: String
    let value: String
    var unit: String? = nil
    /// Skala uzerindeki sayisal deger
    let score: Double
    let scale: ScoreScale
    /// Paneli ve etiketi renklendiren metrik rengi
    let tint: Color
    var statusOverride: String? = nil
    var isCalibrating: Bool = false
    var stats: [HeroStat] = []

    var body: some View {
        let zone = scale.zone(for: score)

        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption.weight(.bold))
                Text(title.uppercased()).font(DS.Typography.dialLabel).tracking(0.6)
            }
            .foregroundStyle(tint)

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 64, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(DS.Panel.text)
                    if let unit {
                        Text(unit)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(DS.Panel.secondary)
                    }
                }
                Spacer()
                Text(isCalibrating ? "Calibrating" : (statusOverride ?? zone.label))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isCalibrating ? DS.Panel.secondary : zone.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background((isCalibrating ? Color.white : zone.color).opacity(0.14), in: Capsule())
            }

            ScaleBar(value: score, scale: scale)

            if isCalibrating {
                Label("Learning your baseline — personalized scores start in a few days.", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.footnote)
                    .foregroundStyle(DS.Panel.secondary)
            }

            if !stats.isEmpty {
                Rectangle().fill(DS.Panel.hairline).frame(height: 1)
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(stat.label, systemImage: stat.icon)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(DS.Panel.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(stat.value)
                                .font(.system(.title3, design: .rounded).weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(DS.Panel.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if index < stats.count - 1 {
                            Rectangle().fill(DS.Panel.hairline).frame(width: 1, height: 40)
                                .padding(.horizontal, DS.Spacing.sm)
                        }
                    }
                }
            }
        }
        .watchPanel(padding: DS.Spacing.lg - 2, glow: tint.opacity(0.7))
    }
}

// MARK: - Koc karti

struct CoachCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let message: String
    var tint: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            CardLabel(title: "Coach", icon: "sparkles", color: tint ?? themeManager.theme.primaryColor)
            Text(message)
                .font(DS.Typography.body)
                .foregroundStyle(themeManager.theme.textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .somnaCard(padding: DS.Spacing.md + 2)
    }
}

// MARK: - Trend satir karti

/// Detay ekranlarindaki "Trends" kartlari: deger + durum + mini grafik.
struct TrendRowCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let label: String
    let tint: Color
    let value: String
    var unit: String? = nil
    var status: String? = nil
    var statusColor: Color? = nil
    var statusIcon: String? = nil
    var sparkline: [Double] = []
    var showsChevron: Bool = true

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                CardLabel(title: label, icon: icon, color: tint)

                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(value)
                        .font(DS.Typography.value)
                        .monospacedDigit()
                        .foregroundStyle(themeManager.theme.headingColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let unit, !unit.isEmpty {
                        Text(unit)
                            .font(DS.Typography.callout.weight(.medium))
                            .foregroundStyle(themeManager.theme.secondaryTextColor)
                    }
                }

                if let status {
                    let c = statusColor ?? DS.Metric.readiness
                    HStack(spacing: 5) {
                        if let statusIcon, !statusIcon.isEmpty {
                            Image(systemName: statusIcon)
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(c)
                                .frame(width: 16, height: 16)
                                .background(c.opacity(0.16), in: Circle())
                        }
                        Text(status)
                            .font(DS.Typography.footnote.weight(.semibold))
                            .foregroundStyle(c)
                    }
                }
            }

            Spacer(minLength: DS.Spacing.xs)

            if sparkline.count >= 2 {
                Sparkline(values: sparkline, color: tint)
                    .frame(width: 96, height: 46)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(themeManager.theme.mutedTextColor)
            }
        }
        .somnaCard(padding: DS.Spacing.md + 2)
    }
}

// MARK: - Mini grafik

struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let range = max(maxV - minV, 0.001)
            let w = geo.size.width
            let h = geo.size.height - 6
            let step = w / CGFloat(max(values.count - 1, 1))
            let pts = values.enumerated().map { i, v in
                CGPoint(x: CGFloat(i) * step, y: 3 + h - CGFloat((v - minV) / range) * h)
            }

            ZStack {
                Path { p in
                    guard let first = pts.first, let last = pts.last else { return }
                    p.move(to: CGPoint(x: first.x, y: geo.size.height))
                    p.addLine(to: first)
                    pts.dropFirst().forEach { p.addLine(to: $0) }
                    p.addLine(to: CGPoint(x: last.x, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [color.opacity(0.28), color.opacity(0)], startPoint: .top, endPoint: .bottom))

                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: first)
                    pts.dropFirst().forEach { p.addLine(to: $0) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                if let last = pts.last {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .shadow(color: color.opacity(0.6), radius: 4)
                        .position(last)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Detay ekrani iskeleti

struct DetailScaffold<Content: View>: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                content()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.xs)
            .padding(.bottom, DS.Spacing.xl)
        }
        .background(themeManager.theme.backgroundGradient.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Durum renkleri (onceki kayda gore)

enum TrendStatusStyle {
    static let normal = DS.Metric.readiness
    static let changed = DS.Metric.quality
    static let noData = Color.gray.opacity(0.5)
}
