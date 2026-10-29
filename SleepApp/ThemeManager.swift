//
//  ThemeManager.swift
//  SleepApp
//

import SwiftUI
import Combine
import UIKit

enum AppTheme {
    case day
    case night

    static var current: AppTheme {
        let hour = Calendar.current.component(.hour, from: Date())
        return (hour >= 6 && hour < 18) ? .day : .night
    }

    // MARK: - Ana renkler (Apple notrleri + su / buz mavisi vurgu)

    /// Ana vurgu: gunduz derin su mavisi, gece buz mavisi
    var primaryColor: Color {
        switch self {
        case .day: return Color(red: 0.039, green: 0.506, blue: 0.937)   // #0A81EF su mavisi
        case .night: return Color(red: 0.420, green: 0.835, blue: 1.0)    // #6BD5FF buz mavisi
        }
    }

    /// Ikincil vurgu: sicak kum/altin (yildizlar, ipuclari)
    var secondaryColor: Color {
        Color(red: 0.902, green: 0.659, blue: 0.290)                      // #E6A84A
    }

    var accentGlow: Color {
        switch self {
        case .day: return Color(red: 0.494, green: 0.800, blue: 0.957).opacity(0.35)
        case .night: return Color(red: 0.494, green: 0.800, blue: 0.957).opacity(0.25)
        }
    }

    /// Ekran zemini: o anki gercek gokyuzu (SkyBackground.swift).
    /// Gunduz buz mavisi -> #F5F5F7, gece lacivert -> OLED siyah; gece yildizlar
    /// ve gercek ay evresi. Eski adla birakildi, tum ekranlar degisiklik olmadan alir.
    var backgroundGradient: SkyBackground {
        SkyBackground(theme: self)
    }

    /// Eski ekranlarla uyum icin korunuyor; yeni kodda `surface` + `.somnaCard()` kullanin.
    var cardBackground: Color {
        surface
    }

    // MARK: - Metin hiyerarsisi (apple.com notrleri)

    var titleGradient: LinearGradient {
        switch self {
        case .day:
            return LinearGradient(
                colors: [Color(red: 0.114, green: 0.114, blue: 0.122), Color(red: 0.039, green: 0.506, blue: 0.937)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .night:
            return LinearGradient(
                colors: [Color.white, Color(red: 0.420, green: 0.835, blue: 1.0)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    var headingColor: Color {
        switch self {
        case .day: return Color(red: 0.114, green: 0.114, blue: 0.122)   // #1D1D1F
        case .night: return Color(red: 0.961, green: 0.961, blue: 0.969) // #F5F5F7
        }
    }

    var textColor: Color {
        switch self {
        case .day: return Color(red: 0.165, green: 0.165, blue: 0.180)   // #2A2A2E
        case .night: return Color(red: 0.898, green: 0.898, blue: 0.918) // #E5E5EA
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .day: return Color(red: 0.431, green: 0.431, blue: 0.451)   // #6E6E73
        case .night: return Color(red: 0.596, green: 0.596, blue: 0.616) // #98989D
        }
    }

    var mutedTextColor: Color {
        switch self {
        case .day: return Color(red: 0.631, green: 0.631, blue: 0.651)   // #A1A1A6
        case .night: return Color(red: 0.388, green: 0.388, blue: 0.400) // #636366
        }
    }

    var icon: String {
        switch self {
        case .day: return "sun.max.fill"
        case .night: return "moon.stars.fill"
        }
    }

    /// UIKit renk karsiligi, navigasyon cubugu icin
    var uiHeadingColor: UIColor {
        switch self {
        case .day: return UIColor(red: 0.114, green: 0.114, blue: 0.122, alpha: 1.0)
        case .night: return UIColor(red: 0.961, green: 0.961, blue: 0.969, alpha: 1.0)
        }
    }
}

class ThemeManager: ObservableObject {
    @Published var theme: AppTheme = AppTheme.current {
        didSet {
            applyNavigationBarAppearance()
        }
    }

    init() {
        applyNavigationBarAppearance()
    }

    /// Sabit temali yerel yonetici (ornegin hep siyah kalan Today ekrani).
    /// Global navigasyon cubugu gorunumune dokunmaz.
    init(fixed theme: AppTheme) {
        self.theme = theme
    }

    func refresh() {
        theme = AppTheme.current
    }

    private func applyNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.largeTitleTextAttributes = [.foregroundColor: theme.uiHeadingColor]
        appearance.titleTextAttributes = [.foregroundColor: theme.uiHeadingColor]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = theme.uiHeadingColor
    }
}

// =============================================================================
// MARK: - Gercek gokyuzu arka plani (backgroundGradient bunu dondurur)
// =============================================================================
//  - Renkler saate gore: safak, ogle, ikindi, aksam alacasi, derin gece, safak oncesi.
//  - Gunduz: gunesin sicak isigi sabah soldan aksam saga kayar, hafif bulutlar.
//  - Gece: yildizlar ve bu gecenin gercek ay evresi (26 Ekim 2026 dolunay,
//    9 Kasim 2026 yeni ay); birkac yildiz parlar, nadiren kayan yildiz gecer.
//  - Ince film greni: duz dijital gecis yerine gokyuzu fotografi gibi.
//  - Mor yok: gece lacivert -> OLED siyah, gunduz buz mavisi -> #F5F5F7.
//  - `.oled`: hep siyah Today ekrani (gece yildiz + ay, gunduz hafif isik).
//  - Hareketi Azalt acikken parlama ve kayan yildiz durur.


enum SkyStyle {
    /// Follows the app theme (day / night canvas)
    case themed
    /// Always black (Today): stars + moon at night, faint sunlight by day
    case oled
}

struct SkyBackground: View {
    let theme: AppTheme
    var style: SkyStyle = .themed

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if style == .oled {
            oledSky
        } else {
            themedSky
        }
    }

    /// Black screen: what the sky is doing outside right now, very quietly.
    private var oledSky: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let realTheme = AppTheme.current
            let hour = Sky.hour(context.date, theme: realTheme)
            ZStack {
                Color.black
                if realTheme == .night {
                    NightSky(hour: hour, date: context.date, animated: !reduceMotion)
                } else {
                    SunGlow(hour: hour, strength: 0.16)
                }
                Image(uiImage: Sky.grainTile)
                    .resizable(resizingMode: .tile)
                    .opacity(0.10)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var themedSky: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let hour = Sky.hour(context.date, theme: theme)
            let sky = Sky.colors(hour: hour, theme: theme)
            ZStack {
                LinearGradient(stops: [
                    .init(color: sky.top, location: 0),
                    .init(color: sky.mid, location: 0.55),
                    .init(color: sky.bottom, location: 1),
                ], startPoint: .top, endPoint: .bottom)

                if theme == .day {
                    SunGlow(hour: hour, strength: 0.45)
                    Clouds(date: context.date)
                } else {
                    NightSky(hour: hour, date: context.date, animated: !reduceMotion)
                }

                // haze low over the horizon
                LinearGradient(colors: [sky.haze.opacity(0), sky.haze.opacity(0.5)],
                               startPoint: .center, endPoint: .bottom)

                Image(uiImage: Sky.grainTile)
                    .resizable(resizingMode: .tile)
                    .opacity(theme == .night ? 0.16 : 0.12)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Sky maths

private enum Sky {
    struct Colors {
        let top: Color, mid: Color, bottom: Color, haze: Color
    }

    typealias RGB = (Double, Double, Double)

    /// Hour of day as a number (e.g. 21.5), kept inside the theme's half of
    /// the day so the colours always match the text colours.
    static func hour(_ date: Date, theme: AppTheme) -> Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        var h = Double(c.hour ?? 12) + Double(c.minute ?? 0) / 60
        switch theme {
        case .day:
            h = min(max(h, 6), 18)
        case .night:
            if h < 6 { h += 24 }            // 0:00-6:00 -> 24-30
            h = min(max(h, 18), 30)
        }
        return h
    }

    // (hour, top, mid, bottom, haze) - hex colours
    private static let dayKeys: [(Double, UInt32, UInt32, UInt32, UInt32)] = [
        (6,  0xDCEBF7, 0xF2F2F4, 0xF7EFE6, 0xFBE3CC),   // dawn: ice blue above, warm low
        (9,  0xE0F0FC, 0xF3F4F6, 0xF5F5F7, 0xFFFFFF),   // morning
        (12, 0xE6F3FD, 0xF5F5F7, 0xF5F5F7, 0xFFFFFF),   // midday = the app's day canvas
        (15, 0xE3EFFA, 0xF4F4F6, 0xF6F1EA, 0xFBEBD8),   // afternoon, a little warmer
        (18, 0xDDE6F2, 0xF2EFEC, 0xF5E4D3, 0xF6CFA8),   // sun going down
    ]

    private static let nightKeys: [(Double, UInt32, UInt32, UInt32, UInt32)] = [
        (18, 0x0B1A2E, 0x0A1424, 0x231A16, 0x5A3A22),   // dusk: navy, last amber low
        (20, 0x07111F, 0x040A14, 0x0A1220, 0x1A2436),   // evening
        (23, 0x05101B, 0x02060B, 0x000000, 0x0A1420),   // deep night = the app's night canvas
        (27, 0x05101B, 0x02060B, 0x000000, 0x0A1420),   // 3:00
        (30, 0x0A1A2E, 0x0B1626, 0x1F2A3A, 0x3A4A5E),   // pre-dawn: cool steel
    ]

    static func colors(hour: Double, theme: AppTheme) -> Colors {
        let keys = theme == .day ? dayKeys : nightKeys
        var i = 0
        while i < keys.count - 2 && hour > keys[i + 1].0 { i += 1 }
        let a = keys[i], b = keys[i + 1]
        let f = min(max((hour - a.0) / (b.0 - a.0), 0), 1)
        func mix(_ x: UInt32, _ y: UInt32) -> Color {
            let p = rgb(x), q = rgb(y)
            return Color(red: p.0 + (q.0 - p.0) * f,
                         green: p.1 + (q.1 - p.1) * f,
                         blue: p.2 + (q.2 - p.2) * f)
        }
        return Colors(top: mix(a.1, b.1), mid: mix(a.2, b.2),
                      bottom: mix(a.3, b.3), haze: mix(a.4, b.4))
    }

    static func rgb(_ hex: UInt32) -> RGB {
        (Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
    }

    /// 0 = new moon, 0.5 = full moon, back to 1. Accurate to about a day.
    static func moonPhase(_ date: Date) -> Double {
        let knownNewMoon = Date(timeIntervalSince1970: 947_182_440)   // 6 Jan 2000, 18:14 UTC
        let days = date.timeIntervalSince(knownNewMoon) / 86_400
        let p = (days / 29.530588853).truncatingRemainder(dividingBy: 1)
        return p < 0 ? p + 1 : p
    }

    /// Stars fade in after dusk and out before dawn.
    static func starVisibility(hour: Double) -> Double {
        let fadeIn = min(max((hour - 18.3) / 1.5, 0), 1)
        let fadeOut = min(max((29.6 - hour) / 1.5, 0), 1)
        return fadeIn * fadeOut
    }

    struct Star {
        let x: Double, y: Double, size: Double, brightness: Double
        let twinkles: Bool, speed: Double, offset: Double
    }

    static let stars: [Star] = {
        var rng = SplitMix(seed: 2026)
        return (0..<95).map { _ in
            Star(x: Double.random(in: 0...1, using: &rng),
                 y: pow(Double.random(in: 0...1, using: &rng), 1.6) * 0.8,   // more near the top
                 size: Double.random(in: 0.6...2.0, using: &rng),
                 brightness: Double.random(in: 0.25...0.9, using: &rng),
                 twinkles: Double.random(in: 0...1, using: &rng) < 0.2,
                 speed: Double.random(in: 0.5...1.6, using: &rng),
                 offset: Double.random(in: 0...(2 * Double.pi), using: &rng))
        }
    }()

    /// One tile of film grain, made once.
    static let grainTile: UIImage = {
        let side: CGFloat = 160
        var rng = SplitMix(seed: 7)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            for _ in 0..<9000 {
                let x = CGFloat(Double.random(in: 0..<Double(side), using: &rng))
                let y = CGFloat(Double.random(in: 0..<Double(side), using: &rng))
                let alpha = CGFloat(Double.random(in: 0.05...0.5, using: &rng))
                let white: CGFloat = Bool.random(using: &rng) ? 1 : 0
                cg.setFillColor(UIColor(white: white, alpha: alpha).cgColor)
                cg.fill(CGRect(x: x, y: y, width: 0.34, height: 0.34))
            }
        }
    }()
}

/// Small deterministic random generator, so stars and grain look the same
/// on every launch.
private struct SplitMix: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Day: the sun's glow

private struct SunGlow: View {
    let hour: Double          // 6 ... 18
    var strength: Double = 0.45

    var body: some View {
        GeometryReader { geo in
            let progress = (hour - 6) / 12                    // 0 morning, 1 evening
            let x = -0.15 + 1.3 * progress
            let y = 0.02 - 0.12 * sin(Double.pi * progress)   // higher at noon
            let lowSun = 1 - sin(Double.pi * progress)        // 1 at sunrise/sunset
            let warm = Color(red: 1.0,
                             green: 0.96 - 0.14 * lowSun,
                             blue: 0.88 - 0.30 * lowSun)
            RadialGradient(colors: [warm.opacity(strength), warm.opacity(strength * 0.3), warm.opacity(0)],
                           center: UnitPoint(x: x, y: y),
                           startRadius: 0,
                           endRadius: max(geo.size.width, geo.size.height) * 0.75)
        }
    }
}

/// A few soft high clouds. Their shapes come from the date, so every day
/// has its own sky, and they drift slowly across it during the day.
private struct Clouds: View {
    let date: Date

    var body: some View {
        GeometryReader { geo in
            let cal = Calendar.current
            let day = cal.ordinality(of: .day, in: .year, for: date) ?? 1
            let minutes = Double(cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date))
            let drift = minutes / 1440 * 0.35
            let clouds = Self.clouds(seed: UInt64(day))
            ZStack {
                ForEach(0..<clouds.count, id: \.self) { i in
                    let c = clouds[i]
                    let x = (c.x + drift).truncatingRemainder(dividingBy: 1.4) - 0.2
                    Ellipse()
                        .fill(Color.white.opacity(c.opacity))
                        .frame(width: geo.size.width * c.width, height: geo.size.height * c.height)
                        .blur(radius: geo.size.height * c.height * 0.45)
                        .position(x: geo.size.width * x, y: geo.size.height * c.y)
                }
            }
        }
    }

    struct Cloud { let x: Double, y: Double, width: Double, height: Double, opacity: Double }

    static func clouds(seed: UInt64) -> [Cloud] {
        var rng = SplitMix(seed: seed &* 7919)
        return (0..<4).map { _ in
            Cloud(x: Double.random(in: 0...1.2, using: &rng),
                  y: Double.random(in: 0.06...0.38, using: &rng),
                  width: Double.random(in: 0.55...1.0, using: &rng),
                  height: Double.random(in: 0.035...0.07, using: &rng),
                  opacity: Double.random(in: 0.18...0.32, using: &rng))
        }
    }
}

// MARK: - Night: stars and the moon

private struct NightSky: View {
    let hour: Double          // 18 ... 30
    let date: Date
    let animated: Bool

    var body: some View {
        GeometryReader { geo in
            let visibility = Sky.starVisibility(hour: hour)
            let progress = (hour - 18) / 12
            let moonX = geo.size.width * (0.82 - 0.2 * progress)
            let moonY = geo.size.height * (0.24 - 0.07 * sin(Double.pi * progress))
            ZStack {
                if animated {
                    TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { tl in
                        StarField(time: tl.date.timeIntervalSinceReferenceDate,
                                  visibility: visibility, meteors: true)
                    }
                } else {
                    StarField(time: 0, visibility: visibility, meteors: false)
                }
                Moon(phase: Sky.moonPhase(date), radius: 16)
                    .position(x: moonX, y: moonY)
                    .opacity(0.35 + 0.65 * visibility)
            }
        }
    }
}

private struct StarField: View {
    let time: Double
    let visibility: Double
    let meteors: Bool

    var body: some View {
        Canvas { ctx, size in
            guard visibility > 0 else { return }
            for s in Sky.stars {
                var a = s.brightness * visibility
                if s.twinkles { a *= 0.6 + 0.4 * sin(time * s.speed + s.offset) }
                let rect = CGRect(x: s.x * size.width - s.size / 2,
                                  y: s.y * size.height - s.size / 2,
                                  width: s.size, height: s.size)
                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(a)))
            }
            guard meteors, visibility > 0.6 else { return }
            // one shooting star about every 50 s, ~1 s long
            let period = 50.0
            let p = (time / period).truncatingRemainder(dividingBy: 1)
            let length = 0.02
            guard p < length else { return }
            let k = p / length
            var rng = SplitMix(seed: UInt64(max(0, time / period)))
            let sx = Double.random(in: 0.1...0.7, using: &rng) * size.width
            let sy = Double.random(in: 0.05...0.3, using: &rng) * size.height
            let travel = size.width * 0.3
            let head = CGPoint(x: sx + travel * k, y: sy + travel * 0.4 * k)
            let tail = CGPoint(x: head.x - travel * 0.35, y: head.y - travel * 0.14)
            var path = Path()
            path.move(to: tail)
            path.addLine(to: head)
            ctx.stroke(path,
                       with: .linearGradient(Gradient(colors: [.white.opacity(0), .white.opacity(0.85 * (1 - k))]),
                                             startPoint: tail, endPoint: head),
                       lineWidth: 1.3)
        }
    }
}

private struct Moon: View {
    let phase: Double
    let radius: CGFloat

    private var lit: Double { (1 - cos(2 * Double.pi * phase)) / 2 }
    private let cream = Color(red: 0.96, green: 0.93, blue: 0.84)

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [cream.opacity(0.30 * lit), cream.opacity(0)],
                                     center: .center, startRadius: radius, endRadius: radius * 4.5))
                .frame(width: radius * 9, height: radius * 9)
            Circle()                                  // earthshine: the dark side, barely there
                .fill(Color.white.opacity(0.06))
                .frame(width: radius * 2, height: radius * 2)
            MoonLitPart(phase: phase)
                .fill(LinearGradient(colors: [cream, Color(red: 0.88, green: 0.85, blue: 0.78)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: radius * 2, height: radius * 2)
        }
    }
}

/// The lit part of the moon for a phase (northern hemisphere view:
/// waxing lit on the right, waning on the left).
private struct MoonLitPart: Shape {
    let phase: Double

    func path(in rect: CGRect) -> Path {
        let r = Double(min(rect.width, rect.height) / 2)
        let cx = Double(rect.midX), cy = Double(rect.midY)
        let side: Double = phase < 0.5 ? 1 : -1
        let c = cos(2 * Double.pi * phase)          // terminator width
        let n = 48
        var p = Path()
        for i in 0...n {                            // bright edge, top to bottom
            let t = Double.pi * Double(i) / Double(n)
            let pt = CGPoint(x: cx + side * sin(t) * r, y: cy - cos(t) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        for i in 0...n {                            // terminator, bottom back to top
            let t = Double.pi * (1 - Double(i) / Double(n))
            p.addLine(to: CGPoint(x: cx + side * c * sin(t) * r, y: cy - cos(t) * r))
        }
        p.closeSubpath()
        return p
    }
}

#Preview("Night") {
    SkyBackground(theme: .night).ignoresSafeArea()
}

#Preview("Today (black)") {
    SkyBackground(theme: .night, style: .oled).ignoresSafeArea()
}

#Preview("Day") {
    SkyBackground(theme: .day).ignoresSafeArea()
}
