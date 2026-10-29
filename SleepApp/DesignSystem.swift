//
//  DesignSystem.swift
//  SleepApp
//
//  Somna tasarim sistemi: tek kaynak.
//  Yeni ekranlarda sabit sayi / Color(red:) yazmak yerine buradaki tokenlari kullanin.
//
//  Prensip: Apple Watch + apple.com.
//  - Siyah "kadran" paneller (Panel): uzerinde parlayan canli gradyanlar
//  - Gunduz beyaz/acik gri zemin (#F5F5F7), gece tam siyah (OLED)
//  - Buz mavisi vurgu, buyuk ve cesur tipografi, bol bosluk
//  - Yatay gosterimler (halka yok). Mor kullanilmaz.
//

import SwiftUI

enum DS {

    // MARK: - Bosluk (4pt grid)

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Kose yuvarlakligi (sadece 3 deger)

    enum Radius {
        /// Chip, kucuk buton, emoji secici
        static let sm: CGFloat = 12
        /// Standart kart
        static let md: CGFloat = 18
        /// Hero kart (Wisp)
        static let lg: CGFloat = 24
        /// Siyah kadran paneli
        static let panel: CGFloat = 30
    }

    // MARK: - Tipografi (Dynamic Type uyumlu)
    // Metin: SF Pro. Sayilar: SF Rounded (Apple Fitness gibi).

    enum Typography {
        static let title = Font.title2.weight(.bold)
        static let title3 = Font.title3.weight(.semibold)
        static let headline = Font.headline
        static let body = Font.body
        static let callout = Font.subheadline
        static let caption = Font.caption
        static let footnote = Font.footnote
        /// Kucuk kategori etiketi (Apple Health'teki renkli kart basliklari gibi)
        static let label = Font.footnote.weight(.semibold)
        /// Buyuk harfli kucuk etiketler (SLEEP, READINESS ...)
        static let eyebrow = Font.caption2.weight(.semibold)
        /// Skor sayilari
        static let metric = Font.system(.title3, design: .rounded).weight(.bold)
        /// Buyuk deger (7h 42m gibi)
        static let value = Font.system(.title, design: .rounded).weight(.bold)
        static let valueSmall = Font.system(.title3, design: .rounded).weight(.semibold)
        /// apple.com tarzi buyuk baslik
        static let display = Font.system(.largeTitle).weight(.bold)
        /// Kadran uzerindeki buyuk rakamlar (Apple Watch Activity gibi)
        static let dial = Font.system(.title, design: .rounded).weight(.semibold)
        /// Kadran etiketi (MOVE, EXERCISE gibi buyuk harfli)
        static let dialLabel = Font.footnote.weight(.semibold)
    }

    // MARK: - Siyah kadran paneli (her iki temada da siyah)

    enum Panel {
        static let top = Color(hex: 0x15181D)
        static let bottom = Color(hex: 0x000000)
        static let text = Color.white
        static let secondary = Color(hex: 0x98989D)
        static let muted = Color(hex: 0x636366)
        static let track = Color.white.opacity(0.12)
        static let hairline = Color.white.opacity(0.08)
    }

    // MARK: - Metrik renkleri (gunduz/gece ayni, her metrik tek kimlik rengi)

    enum Metric {
        // Beyaz kartlar uzerinde (derin tonlar)
        static let sleep = Color(hex: 0x1A8CF0)      // su mavisi
        static let readiness = Color(hex: 0x1FB98A)  // deniz yesili
        static let strain = Color(hex: 0xF2734D)     // mercan
        static let heart = Color(hex: 0xF0506E)      // gul
        static let hrv = Color(hex: 0x2BB3D6)        // turkuaz
        static let quality = Color(hex: 0xF0A93A)    // kum / altin
        static let stressLow = Color(hex: 0x1FB98A)
        static let stressMid = Color(hex: 0xF0A93A)
        static let stressHigh = Color(hex: 0xEF4B45)
        static let streak = Color(hex: 0xFF8A3D)

        // Siyah kadran uzerinde parlayan gradyanlar (acik -> canli)
        static let sleepLight = Color(hex: 0x8FE3FF)
        static let sleepGlow = Color(hex: 0x2E9BFF)
        static let readinessLight = Color(hex: 0xA6F5D6)
        static let readinessGlow = Color(hex: 0x22D49B)
        static let strainLight = Color(hex: 0xFFC98A)
        static let strainGlow = Color(hex: 0xFF6E45)

        static func stress(_ score: Int) -> Color {
            switch score {
            case 0..<20: return stressLow
            case 20..<50: return stressMid
            default: return stressHigh
            }
        }
    }

    // MARK: - Animasyon

    enum Motion {
        static let snappy = Animation.snappy(duration: 0.3)
        static let bouncy = Animation.bouncy(duration: 0.4)
        static let smooth = Animation.smooth(duration: 0.45)
    }
}

// MARK: - Tema yuzeyleri (Apple "grouped" duzeni)

extension AppTheme {
    /// Ekran zemini: gunduz apple.com acik grisi, gece tam siyah
    var canvas: Color {
        switch self {
        case .day: return Color(hex: 0xF5F5F7)
        case .night: return .black
        }
    }

    /// Kart yuzeyi
    var surface: Color {
        switch self {
        case .day: return .white
        case .night: return Color(hex: 0x1C1C1E)
        }
    }

    /// Kart icindeki ikincil yuzey (secici, chip, bar arka plani)
    var surfaceSunken: Color {
        switch self {
        case .day: return Color(hex: 0xF0F2F5)
        case .night: return Color(hex: 0x2C2C2E)
        }
    }

    /// Ayirici cizgi
    var stroke: Color {
        switch self {
        case .day: return Color.black.opacity(0.08)
        case .night: return Color.white.opacity(0.1)
        }
    }

    /// Beyaz kartlarin cok hafif golgesi
    var cardShadow: Color {
        switch self {
        case .day: return Color.black.opacity(0.05)
        case .night: return .clear
        }
    }
}

// MARK: - Hex renk yardimcisi

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
