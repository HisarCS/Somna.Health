//
//  WidgetWisp.swift
//  SomnaWidget
//
//  Widget icin Wisp damlasi (uygulamadaki WispView'in statik kopyasi).
//  Widget'lar animasyon calistirmadigi icin sadece sekil + yuz + duygu rengi cizilir.
//  NOT: Bu dosya SomnaWidget hedefine eklenmelidir.
//

import SwiftUI

// MARK: - Widget ruh hali (eski ayicik gorsel adlarindan eslenir)

enum WidgetWispMood {
    case calm, proud, wokeUp, tired, sad, tense, readyToSleep, sleepy

    /// Provider'in sectigi eski "bear_*" adini Wisp ruh haline cevirir
    init(bearImageName: String) {
        switch bearImageName {
        case "bear_sleeping": self = .sleepy
        case "bear_wokeUp": self = .wokeUp
        case "bear_lowEnergy", "bear_tired": self = .tired
        case "bear_energetic": self = .proud
        case "bear_sad": self = .sad
        case "bear_angry": self = .tense
        case "bear_readyToSleep": self = .readyToSleep
        default: self = .calm
        }
    }

    /// Uygulamadaki WispMood renkleriyle ayni aile (mor yok)
    var color: Color {
        switch self {
        case .calm: return Color(red: 0.31, green: 0.70, blue: 0.91)          // berrak su mavisi
        case .wokeUp: return Color(red: 0.49, green: 0.78, blue: 0.95)        // buz mavisi
        case .proud: return Color(red: 0.95, green: 0.66, blue: 0.23)         // sicak amber
        case .tired: return Color(red: 0.85, green: 0.57, blue: 0.62)         // pudra gul
        case .sad: return Color(red: 0.61, green: 0.76, blue: 0.86)           // sisli mavi
        case .tense: return Color(red: 0.91, green: 0.38, blue: 0.35)         // sicak kirmizi
        case .readyToSleep: return Color(red: 0.27, green: 0.76, blue: 0.68)  // deniz kopugu
        case .sleepy: return Color(red: 0.23, green: 0.51, blue: 0.86)        // derin okyanus
        }
    }
}

// MARK: - Damla govdesi (WispBody ile ayni geometri)

struct WidgetWispBody: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height) / 1.42
        let square = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2 + side * 0.12,
                            width: side, height: side)
        let shape = UnevenRoundedRectangle(topLeadingRadius: 0,
                                           bottomLeadingRadius: side / 2,
                                           bottomTrailingRadius: side / 2,
                                           topTrailingRadius: side / 2)
        let center = CGPoint(x: square.midX, y: square.midY)
        let turn = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: .pi / 4)
            .translatedBy(x: -center.x, y: -center.y)
        return shape.path(in: square).applying(turn)
    }
}

// MARK: - Widget Wisp gorunumu

struct WidgetWispView: View {
    let mood: WidgetWispMood
    var size: CGFloat = 90

    private let face = Color(red: 0.03, green: 0.10, blue: 0.10)

    var body: some View {
        let s = size
        ZStack {
            // Arkadaki isik
            Circle()
                .fill(RadialGradient(colors: [mood.color.opacity(0.55), mood.color.opacity(0)],
                                     center: .center, startRadius: 2, endRadius: s * 0.75))
                .frame(width: s * 1.5, height: s * 1.5)

            WidgetWispBody()
                .fill(LinearGradient(colors: [.white, mood.color.opacity(0.9)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: mood.color.opacity(0.5), radius: s * 0.1)

            VStack(spacing: s * 0.06) {
                HStack(spacing: s * 0.16) { eye; eye }
                mouth
            }
            .offset(y: s * 0.12)

            extras
        }
        .frame(width: s, height: s)
    }

    @ViewBuilder private var eye: some View {
        let s = size
        switch mood {
        case .proud:
            WChevron()
                .stroke(face, style: StrokeStyle(lineWidth: s * 0.025, lineCap: .round, lineJoin: .round))
                .frame(width: s * 0.09, height: s * 0.05)
        case .sleepy, .readyToSleep, .tired:
            WArc()
                .stroke(face, style: StrokeStyle(lineWidth: s * 0.022, lineCap: .round))
                .frame(width: s * 0.09, height: s * 0.03)
        default:
            Ellipse().fill(face)
                .frame(width: s * 0.07, height: s * 0.10)
                .overlay(Circle().fill(.white).frame(width: s * 0.022).offset(x: s * 0.01, y: -s * 0.02))
        }
    }

    @ViewBuilder private var mouth: some View {
        let s = size
        switch mood {
        case .proud, .wokeUp:
            WHalfDisc().fill(face).frame(width: s * 0.12, height: s * 0.06)
        case .calm, .readyToSleep:
            WArc()
                .stroke(face, style: StrokeStyle(lineWidth: s * 0.022, lineCap: .round))
                .frame(width: s * 0.10, height: s * 0.035)
        case .sad, .tense:
            WArc()
                .stroke(face, style: StrokeStyle(lineWidth: s * 0.022, lineCap: .round))
                .frame(width: s * 0.09, height: s * 0.03)
                .rotationEffect(.degrees(180))
        case .tired:
            Ellipse().fill(face).frame(width: s * 0.06, height: s * 0.045)
        case .sleepy:
            Capsule().fill(face).frame(width: s * 0.07, height: s * 0.018)
        }
    }

    @ViewBuilder private var extras: some View {
        let s = size
        switch mood {
        case .proud:
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: s * (i == 0 ? 0.14 : 0.09)))
                    .foregroundStyle(mood.color)
                    .offset(x: [-0.46, 0.48, 0.42][i] * s, y: [-0.26, -0.3, 0.16][i] * s)
            }
        case .sleepy, .readyToSleep:
            Text("z z")
                .font(.system(size: s * 0.13, weight: .bold, design: .rounded))
                .foregroundStyle(mood.color)
                .offset(x: s * 0.46, y: -s * 0.3)
        case .sad, .tired:
            Image(systemName: "drop.fill")
                .font(.system(size: s * 0.09))
                .foregroundStyle(Color.cyan.opacity(0.85))
                .offset(x: s * 0.36, y: -s * 0.1)
        case .tense:
            Image(systemName: "exclamationmark")
                .font(.system(size: s * 0.14, weight: .heavy))
                .foregroundStyle(mood.color)
                .offset(x: s * 0.42, y: -s * 0.32)
        default:
            EmptyView()
        }
    }
}

// MARK: - Kucuk sekiller

private struct WChevron: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        return p
    }
}

private struct WArc: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY),
                       control: CGPoint(x: r.midX, y: r.maxY * 2 - r.minY))
        return p
    }
}

private struct WHalfDisc: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY),
                       control: CGPoint(x: r.midX, y: r.maxY * 2 - r.minY))
        p.closeSubpath()
        return p
    }
}
