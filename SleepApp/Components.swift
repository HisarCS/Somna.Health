//
//  Components.swift
//  SleepApp
//
//  Tum ekranlarda tekrar kullanilan Somna bilesenleri (Apple Health/Fitness dili).
//

import SwiftUI

// MARK: - Kart

struct SomnaCardModifier: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager
    var padding: CGFloat = DS.Spacing.md
    var radius: CGFloat = DS.Radius.md
    var fill: Color? = nil

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill ?? themeManager.theme.surface,
                        in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: themeManager.theme.cardShadow, radius: 14, x: 0, y: 6)
    }
}

extension View {
    /// Standart Somna karti: beyaz yuzey, kenarsiz, cok hafif mavi golge
    func somnaCard(padding: CGFloat = DS.Spacing.md, radius: CGFloat = DS.Radius.md, fill: Color? = nil) -> some View {
        modifier(SomnaCardModifier(padding: padding, radius: radius, fill: fill))
    }
}

// MARK: - Bolum basligi

struct SectionHeader: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(DS.Typography.title.weight(.bold))
                .foregroundStyle(themeManager.theme.headingColor)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(DS.Typography.footnote)
                    .foregroundStyle(themeManager.theme.mutedTextColor)
            }
        }
        .padding(.horizontal, DS.Spacing.xxs)
        .padding(.top, DS.Spacing.xs)
    }
}

// MARK: - Renkli kart etiketi (Apple Health: "♥ Heart Rate")

struct CardLabel: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: icon)
        }
        .font(DS.Typography.label)
        .foregroundStyle(color)
        .labelStyle(.titleAndIcon)
    }
}

// MARK: - Siyah kadran paneli (Apple Watch yuzu gibi)

struct WatchPanelModifier: ViewModifier {
    var padding: CGFloat = DS.Spacing.lg
    /// Panelin ust kenarinda yanan hafif renk (ornegin Wisp'in duygu rengi)
    var glow: Color? = nil

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    LinearGradient(colors: [DS.Panel.top, DS.Panel.bottom], startPoint: .top, endPoint: .bottom)
                    if let glow {
                        RadialGradient(colors: [glow.opacity(0.32), .clear],
                                       center: .top, startRadius: 0, endRadius: 260)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.03)],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: 1
                        )
                )
            }
            .environment(\.colorScheme, .dark)
    }
}

extension View {
    /// Her iki temada da siyah kalan, Apple Watch kadrani gibi panel
    func watchPanel(padding: CGFloat = DS.Spacing.lg, glow: Color? = nil) -> some View {
        modifier(WatchPanelModifier(padding: padding, glow: glow))
    }
}

// MARK: - Yatay skor cubugu (halka yerine, Apple Watch Activity dili)

/// Ustte buyuk harfli etiket ve buyuk renkli rakam, altta parlayan yatay cubuk.
/// `onPanel: true` iken siyah kadran uzerinde kullanilir.
struct ScoreBar: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let icon: String
    /// nil ise "—" ve bos cubuk
    let value: String?
    var unit: String? = nil
    var caption: String? = nil
    let progress: Double
    /// Cubugun canli ucu ve rakam rengi
    let color: Color
    /// Cubugun acik basi
    let lightColor: Color
    var onPanel: Bool = true
    var showsChevron: Bool = true

    @State private var animatedProgress: Double = 0

    private var labelColor: Color { onPanel ? DS.Panel.secondary : themeManager.theme.secondaryTextColor }
    private var mutedColor: Color { onPanel ? DS.Panel.muted : themeManager.theme.mutedTextColor }
    private var trackColor: Color { onPanel ? DS.Panel.track : themeManager.theme.surfaceSunken }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xs) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Image(systemName: icon)
                            .font(.caption.weight(.bold))
                        Text(title.uppercased())
                            .font(DS.Typography.dialLabel)
                            .tracking(0.6)
                    }
                    .foregroundStyle(color)

                    if let caption {
                        Text(caption)
                            .font(DS.Typography.caption)
                            .foregroundStyle(labelColor)
                    }
                }

                Spacer(minLength: DS.Spacing.xs)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value ?? "—")
                        .font(DS.Typography.dial)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(value == nil ? mutedColor : color)
                    if let unit, value != nil {
                        Text(unit)
                            .font(DS.Typography.footnote.weight(.semibold))
                            .foregroundStyle(labelColor)
                    }
                }

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(mutedColor)
                        .padding(.leading, 2)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(trackColor)
                    Capsule()
                        .fill(LinearGradient(colors: [lightColor, color], startPoint: .leading, endPoint: .trailing))
                        .frame(width: animatedProgress > 0 ? max(geo.size.width * animatedProgress, 12) : 0)
                        .shadow(color: color.opacity(onPanel ? 0.7 : 0.35), radius: onPanel ? 8 : 5, x: 0, y: 0)
                }
            }
            .frame(height: 12)
        }
        .contentShape(Rectangle())
        .onAppear {
            withAnimation(.smooth(duration: 1.1).delay(0.15)) {
                animatedProgress = value == nil ? 0 : min(max(progress, 0), 1)
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(DS.Motion.smooth) {
                animatedProgress = value == nil ? 0 : min(max(newValue, 0), 1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value ?? "no data")")
    }
}

// MARK: - Yatay bilgi satiri (liste icinde)

struct InfoRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let icon: String
    let tint: Color
    let value: String
    var valueColor: Color? = nil
    var detail: String? = nil

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            IconTile(icon: icon, color: tint, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(DS.Typography.body)
                    .foregroundStyle(themeManager.theme.textColor)
                if let detail {
                    Text(detail)
                        .font(DS.Typography.caption)
                        .foregroundStyle(themeManager.theme.secondaryTextColor)
                }
            }
            Spacer(minLength: DS.Spacing.xs)
            Text(value)
                .font(DS.Typography.callout.weight(.semibold))
                .foregroundStyle(valueColor ?? themeManager.theme.headingColor)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(themeManager.theme.mutedTextColor)
        }
        .padding(.vertical, DS.Spacing.xs)
        .contentShape(Rectangle())
    }
}

// MARK: - Metrik karosu (Apple Health ozet karti gibi)

struct MetricTile: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let icon: String
    let tint: Color
    let value: String
    var valueColor: Color? = nil
    let detail: String
    var showsChevron: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                CardLabel(title: title, icon: icon, color: tint)
                Spacer(minLength: 0)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(themeManager.theme.mutedTextColor)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(DS.Typography.valueSmall)
                    .foregroundStyle(valueColor ?? themeManager.theme.headingColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(detail)
                    .font(DS.Typography.caption)
                    .foregroundStyle(themeManager.theme.secondaryTextColor)
                    .lineLimit(1)
            }
        }
        .somnaCard()
    }
}

// MARK: - Istatistik karosu (deger + onceki doneme gore degisim)

struct StatTile: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let icon: String
    let tint: Color
    let value: String
    /// Ornek: "+12m", "-0.3". nil ise gosterilmez
    var delta: String? = nil
    /// Degisim iyi yonde mi (renk icin)
    var deltaIsGood: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            CardLabel(title: title, icon: icon, color: tint)
            Text(value)
                .font(DS.Typography.value)
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(themeManager.theme.headingColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let delta {
                Label(delta, systemImage: deltaIsGood ? "arrow.up.right" : "arrow.down.right")
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(deltaIsGood ? DS.Metric.readiness : themeManager.theme.secondaryTextColor)
            } else {
                Text("vs. previous period")
                    .font(DS.Typography.caption)
                    .foregroundStyle(themeManager.theme.mutedTextColor)
                    .hidden()
            }
        }
        .somnaCard()
    }
}

// MARK: - Aliskanliklar

enum Habit: CaseIterable {
    case caffeine, screen, exercise, alcohol

    var title: String {
        switch self {
        case .caffeine: return "Caffeine"
        case .screen: return "Screen before bed"
        case .exercise: return "Exercise"
        case .alcohol: return "Alcohol"
        }
    }

    var icon: String {
        switch self {
        case .caffeine: return "cup.and.saucer.fill"
        case .screen: return "iphone"
        case .exercise: return "figure.run"
        case .alcohol: return "wineglass.fill"
        }
    }

    var color: Color {
        switch self {
        case .caffeine: return Color(hex: 0xB48A62)   // kahve
        case .screen: return Color(hex: 0x5B7C99)      // arduvaz
        case .exercise: return DS.Metric.readiness
        case .alcohol: return DS.Metric.heart
        }
    }

    func isOn(_ entry: SleepEntry) -> Bool {
        switch self {
        case .caffeine: return entry.hadCaffeine
        case .screen: return entry.hadScreenBeforeBed
        case .exercise: return entry.didExercise
        case .alcohol: return entry.hadAlcohol
        }
    }
}

/// Liste satirlarinda kullanilan kucuk yuvarlak aliskanlik ikonu
struct HabitDot: View {
    let habit: Habit

    var body: some View {
        Image(systemName: habit.icon)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(habit.color, in: Circle())
            .accessibilityLabel(habit.title)
    }
}

/// Ayarlar tarzi renkli kare ikon (Apple Settings gibi)
struct IconTile: View {
    let icon: String
    let color: Color
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [color.opacity(0.75), color], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            )
    }
}

// MARK: - Butonlar

struct SomnaPrimaryButtonStyle: ButtonStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md - 1)
            .background(
                LinearGradient(colors: [color.opacity(0.85), color], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 5)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(DS.Motion.snappy, value: configuration.isPressed)
    }
}

struct SomnaSecondaryButtonStyle: ButtonStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.callout.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(color.opacity(0.14), in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(DS.Motion.snappy, value: configuration.isPressed)
    }
}

// MARK: - Ruh hali secici (1-5)

struct MoodPicker: View {
    @EnvironmentObject var themeManager: ThemeManager
    let selected: Int?
    var emojiSize: CGFloat = 24
    let onSelect: (Int) -> Void

    static func emoji(for level: Int) -> String {
        switch level {
        case 1: return "🧟"
        case 2: return "😴"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "⚡️"
        default: return "😐"
        }
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(1...5, id: \.self) { level in
                let isSelected = selected == level
                Button {
                    onSelect(level)
                } label: {
                    Text(Self.emoji(for: level))
                        .font(.system(size: emojiSize))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.xs + 2)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                .fill(isSelected ? themeManager.theme.primaryColor.opacity(0.18) : themeManager.theme.surfaceSunken)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                .strokeBorder(isSelected ? themeManager.theme.primaryColor : .clear, lineWidth: 1.5)
                        )
                        .scaleEffect(isSelected ? 1.04 : 1)
                        .animation(DS.Motion.bouncy, value: isSelected)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: isSelected)
            }
        }
    }
}

// MARK: - Bos durum

struct EmptyStateView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(themeManager.theme.mutedTextColor)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(DS.Typography.title3)
                .foregroundStyle(themeManager.theme.headingColor)
            Text(message)
                .font(DS.Typography.callout)
                .foregroundStyle(themeManager.theme.secondaryTextColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, DS.Spacing.lg)
    }
}

// MARK: - Sure formatlama

enum SleepFormat {
    static func duration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    static func signedDuration(_ minutes: Int) -> String {
        let sign = minutes >= 0 ? "+" : "−"
        return sign + duration(abs(minutes))
    }
}
