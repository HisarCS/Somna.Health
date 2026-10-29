//
//  WispHeroCard.swift
//  SleepApp
//
//  Ana sayfanin ust karti: Wisp avatari + ruh hali + seri.
//  Somna cihazi bagliysa ruh halini cihaz belirler (WispView ile ayni yuz),
//  degilse uygulamadaki verilerden (saat, check-in, hazirlik, stres) turetilir.
//

import SwiftUI
import UIKit

// MARK: - Ruh haline gore renk

extension WispMood {
    /// Damlanin rengi duyguya gore degisir (mor yok; su temasi + sicak tonlar)
    var color: Color {
        switch self {
        case .calm: return Color(hex: 0x4FB3E8)      // berrak su mavisi
        case .listen: return Color(hex: 0x7CC8F2)    // buz mavisi
        case .search: return Color(hex: 0x9CC3DB)    // sisli mavi
        case .breathe: return Color(hex: 0x45C2AE)   // deniz kopugu
        case .proud: return Color(hex: 0xF2A93B)     // sicak amber
        case .active: return Color(hex: 0xF58C6C)    // mercan
        case .tired: return Color(hex: 0xD9919E)     // pudra gul
        case .tense: return Color(hex: 0xE8625A)     // sicak kirmizi
        case .sleepy: return Color(hex: 0x3B82DB)    // derin okyanus
        case .unknown: return Color(hex: 0x7CC8F2)
        }
    }

    /// Kart arka planindaki hafif ton
    var tint: Color { color.opacity(0.10) }

    /// Cihaz bagli degilken uygulama verisinden ruh hali
    static func fromAppData(hour: Int, checkInLevel: Int, readiness: Int?, stress: Int?) -> WispMood {
        if hour >= 22 || hour < 6 { return .sleepy }
        if let stress, stress >= 50 { return .tense }
        switch checkInLevel {
        case 1, 2: return .tired
        case 4, 5: return (readiness ?? 0) >= 80 ? .proud : .active
        case 3: return .calm
        default: break
        }
        if let readiness {
            if readiness >= 80 { return .proud }
            if readiness < 50 { return .tired }
        }
        if hour >= 20 { return .breathe }
        return .calm
    }
}

// MARK: - Hero panel (siyah kadran)

/// Apple Watch yuzu gibi siyah panel: ortada parlayan Wisp, buyuk baslik,
/// altinda istege bagli icerik (skor cubuklari).
struct WispHeroCard<Footer: View>: View {
    @EnvironmentObject var themeManager: ThemeManager
    let mood: WispMood
    /// Somna bileklikten canli mi geliyor
    let isLive: Bool
    let streak: Int
    var streakPop: Bool = false
    var milestoneMessage: String? = nil
    var hapticsEnabled: Bool = true
    @ViewBuilder var footer: () -> Footer

    @State private var pokes = 0
    @State private var breathe = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            statusRow
                .padding(.bottom, DS.Spacing.xs)

            avatar
                .padding(.vertical, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.xs) {
                Text(mood.title + ".")
                    .font(DS.Typography.display)
                    .foregroundStyle(DS.Panel.text)
                    .contentTransition(.opacity)
                    .multilineTextAlignment(.center)

                if mood == .breathe {
                    BreathGuide(color: mood.color)
                } else {
                    Text(mood.message)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Panel.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DS.Spacing.md)
                }
            }
            .frame(maxWidth: .infinity)

            if Footer.self != EmptyView.self {
                Rectangle()
                    .fill(DS.Panel.hairline)
                    .frame(height: 1)
                    .padding(.vertical, DS.Spacing.lg)
                footer()
            }
        }
        .watchPanel(padding: DS.Spacing.lg, glow: mood.color)
        .animation(DS.Motion.smooth, value: mood)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { breathe = true }
        }
    }

    // MARK: Parcalar

    /// Ust satir: canli/sabit kaynak + seri (Watch komplikasyonlari gibi)
    private var statusRow: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(isLive ? DS.Metric.readinessGlow : DS.Panel.muted)
                    .frame(width: 7, height: 7)
                    .shadow(color: isLive ? DS.Metric.readinessGlow : .clear, radius: 4)
                Text(isLive ? "LIVE" : "WISP")
                    .font(DS.Typography.dialLabel)
                    .tracking(0.8)
                    .foregroundStyle(DS.Panel.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(
                        LinearGradient(colors: [DS.Metric.strainLight, DS.Metric.streak], startPoint: .top, endPoint: .bottom)
                    )
                Text("\(streak)")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(DS.Panel.text)
                    .scaleEffect(streakPop ? 1.2 : 1)
                    .animation(DS.Motion.bouncy, value: streakPop)
                Text(milestoneMessage ?? (streak == 1 ? "day" : "days"))
                    .font(DS.Typography.footnote)
                    .foregroundStyle(DS.Panel.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.08), in: Capsule())
            .animation(DS.Motion.snappy, value: milestoneMessage)
        }
    }

    private var avatar: some View {
        ZStack {
            // Urun fotografi gibi: Wisp'in arkasinda nefes alan isik
            Circle()
                .fill(RadialGradient(colors: [mood.color.opacity(0.55), mood.color.opacity(0.0)],
                                     center: .center, startRadius: 4, endRadius: 110))
                .frame(width: 220, height: 220)
                .scaleEffect(breathe ? 1.06 : 0.94)
                .blur(radius: 6)

            // Zemindeki yansima
            Ellipse()
                .fill(mood.color.opacity(0.35))
                .frame(width: 96, height: 14)
                .blur(radius: 8)
                .offset(y: 76)

            WispView(mood: mood, size: 150, color: mood.color)
                .id(mood)
                .phaseAnimator([false, true], trigger: pokes) { content, phase in
                    content
                        .scaleEffect(phase ? 1.1 : 1, anchor: .bottom)
                        .rotationEffect(.degrees(phase ? -5 : 0), anchor: .bottom)
                } animation: { _ in
                    DS.Motion.bouncy
                }
        }
        .frame(height: 190)
        .contentShape(Rectangle())
        .onTapGesture { pokes += 1 }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: pokes) { _, _ in hapticsEnabled }
        .accessibilityLabel("Wisp: \(mood.title)")
        .accessibilityAddTraits(.isButton)
    }
}

extension WispHeroCard where Footer == EmptyView {
    init(mood: WispMood, isLive: Bool, streak: Int, streakPop: Bool = false,
         milestoneMessage: String? = nil, hapticsEnabled: Bool = true) {
        self.init(mood: mood, isLive: isLive, streak: streak, streakPop: streakPop,
                  milestoneMessage: milestoneMessage, hapticsEnabled: hapticsEnabled, footer: { EmptyView() })
    }
}

// MARK: - Nefes rehberi

/// BREATHE'de Wisp ile ayni saatte: 4 sn "Breathe in", 6 sn "and out".
/// WispView ayni formulu kullandigi icin yazi Wisp'in sisip sonmesiyle esit gider.
struct BreathGuide: View {
    let color: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let b = WispMood.breath(at: context.date.timeIntervalSinceReferenceDate)
            VStack(spacing: DS.Spacing.xs) {
                Text(b.inhaling ? "Breathe in…" : "…and out")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(color)
                    .contentTransition(.opacity)
                // 4 s / 6 s bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DS.Panel.track)
                        Capsule()
                            .fill(color)
                            .frame(width: max(geo.size.width * CGFloat(b.fill), 6))
                    }
                }
                .frame(width: 140, height: 6)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(b.inhaling ? "Breathe in" : "Breathe out")
        }
    }
}
