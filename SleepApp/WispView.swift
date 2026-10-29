//
//  WispView.swift
//  SleepApp
//
//  Wisp, the same avatar as on the Somna device's OLED, drawn in SwiftUI.
//  The device decides the mood (rule-based) and sends it in every record,
//  so the app and the wrist always show the same face.
//
//  v2: Wisp blinks, its extras move (twinkling sparkles, floating z's, a
//  sweat drop that falls, drifting motes when calm), and in BREATHE it
//  really breathes: 4 s in, 6 s out, so you can follow it. One clock
//  (TimelineView) drives all motion, so a mood change never leaves a
//  half-finished animation behind. Colour comes from WispMood.color
//  (WispHeroCard.swift); the glow and floor shadow stay in the containers.
//

import SwiftUI

// MARK: - Breathing guide (shared with WispHeroCard / SomnaDeviceView)

extension WispMood {
    /// Breathing guide used by BREATHE: 4 s in, 6 s out.
    static let breatheIn: Double = 4
    static let breatheOut: Double = 6

    /// 0...1 lung fill and whether we are breathing in, for time t (s).
    static func breath(at t: Double) -> (fill: Double, inhaling: Bool) {
        let cycle = breatheIn + breatheOut
        let p = t.truncatingRemainder(dividingBy: cycle)
        func ease(_ x: Double) -> Double { 0.5 - 0.5 * cos(Double.pi * x) }
        if p < breatheIn { return (ease(p / breatheIn), true) }
        return (1 - ease((p - breatheIn) / breatheOut), false)
    }
}

// MARK: - Body shape

/// Flame / drop body: a square with three round corners, turned 45 degrees,
/// so the sharp corner becomes the tip on top.
struct WispBody: Shape {
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

// MARK: - Wisp

struct WispView: View {
    let mood: WispMood
    var size: CGFloat = 180
    /// Mood colour: callers pass `mood.color`
    var color: Color = Color(hex: 0x4FB3E8)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let face = Color(red: 0.05, green: 0.08, blue: 0.14)

    private var tint: Color { color }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            scene(at: reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Wisp: \(mood.title)")
    }

    // MARK: One frame

    private func scene(at t: Double) -> some View {
        let lift = CGFloat(sin(2 * Double.pi * t / bobPeriod)) * bobAmount
        let breath = WispMood.breath(at: t)
        let breathScale: CGFloat = mood == .breathe ? 1 + 0.12 * CGFloat(breath.fill) : 1

        return ZStack {
            if mood == .breathe {
                breathingRing(fill: breath.fill)
            }

            ZStack {
                bodyShape
                faceView(t: t)
                    .offset(y: size * 0.12)
                extras(t: t)
            }
            .frame(width: size, height: size)
            .scaleEffect(breathScale)
            .offset(y: -lift)
        }
    }

    // MARK: Body

    private var bodyShape: some View {
        ZStack {
            WispBody()
                .fill(LinearGradient(colors: [Color.white, tint.opacity(0.85), tint],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: tint.opacity(0.5), radius: size * 0.1)
            // soft highlight, like light on glass
            Ellipse()
                .fill(Color.white.opacity(0.55))
                .frame(width: size * 0.16, height: size * 0.09)
                .rotationEffect(.degrees(-35))
                .blur(radius: size * 0.012)
                .offset(x: -size * 0.15, y: size * 0.02)
            WispBody()
                .stroke(Color.white.opacity(0.45), lineWidth: max(1, size * 0.008))
        }
    }

    private var bobAmount: CGFloat {
        switch mood {
        case .active, .proud: return size * 0.045
        case .tense: return size * 0.012
        case .breathe: return size * 0.01
        default: return size * 0.025
        }
    }

    private var bobPeriod: Double {
        switch mood {
        case .active, .proud: return 0.7
        case .tense: return 0.3
        case .sleepy: return 5.0
        case .breathe: return WispMood.breatheIn + WispMood.breatheOut
        default: return 3.2
        }
    }

    // MARK: Face

    private func isBlinking(_ t: Double) -> Bool {
        switch mood {
        case .search, .listen, .calm, .tense, .unknown:
            return t.truncatingRemainder(dividingBy: 3.7) < 0.13
        default:
            return false
        }
    }

    private func faceView(t: Double) -> some View {
        let s = size
        let closed = isBlinking(t)
        return ZStack {
            VStack(spacing: s * 0.06) {
                HStack(spacing: s * 0.16) {
                    eye(closed: closed)
                    eye(closed: closed)
                }
                mouth
            }
            if showsCheeks {
                HStack(spacing: s * 0.30) {
                    cheek
                    cheek
                }
                .offset(y: s * 0.05)
            }
        }
    }

    private var showsCheeks: Bool {
        mood == .proud || mood == .active || mood == .calm
    }

    private var cheek: some View {
        Ellipse()
            .fill(Color(red: 1.0, green: 0.45, blue: 0.55).opacity(0.35))
            .frame(width: size * 0.07, height: size * 0.04)
            .blur(radius: size * 0.006)
    }

    @ViewBuilder private func eye(closed: Bool) -> some View {
        let s = size
        switch mood {
        case .active, .proud:                       // ^ ^
            Chevron(up: true)
                .stroke(face, style: StrokeStyle(lineWidth: s * 0.025, lineCap: .round, lineJoin: .round))
                .frame(width: s * 0.09, height: s * 0.05)
        case .tired:                                // > <
            Chevron(up: false)
                .stroke(face, style: StrokeStyle(lineWidth: s * 0.025, lineCap: .round, lineJoin: .round))
                .frame(width: s * 0.08, height: s * 0.06)
                .rotationEffect(.degrees(90))
        case .sleepy, .breathe:                     // closed, curved lids
            Arc(down: true)
                .stroke(face, style: StrokeStyle(lineWidth: s * 0.022, lineCap: .round))
                .frame(width: s * 0.09, height: s * 0.03)
        default:
            if closed {
                Capsule().fill(face)
                    .frame(width: s * 0.08, height: s * 0.018)
            } else {
                Ellipse().fill(face)
                    .frame(width: s * (mood == .tense ? 0.09 : 0.07),
                           height: s * (mood == .tense ? 0.13 : 0.10))
                    .overlay(
                        Circle().fill(Color.white)
                            .frame(width: s * 0.024)
                            .offset(x: s * 0.011, y: -s * 0.02)
                    )
            }
        }
    }

    @ViewBuilder private var mouth: some View {
        let s = size
        switch mood {
        case .active, .proud:
            HalfDisc().fill(face).frame(width: s * 0.12, height: s * 0.06)
        case .calm:
            Arc(down: true)
                .stroke(face, style: StrokeStyle(lineWidth: s * 0.022, lineCap: .round))
                .frame(width: s * 0.10, height: s * 0.035)
        case .tired:
            Ellipse().fill(face).frame(width: s * 0.06, height: s * 0.045)
        case .tense:
            Wave()
                .stroke(face, style: StrokeStyle(lineWidth: s * 0.02, lineCap: .round, lineJoin: .round))
                .frame(width: s * 0.11, height: s * 0.025)
        case .listen, .breathe:
            Circle().stroke(face, lineWidth: s * 0.018).frame(width: s * 0.04)
        default:
            Capsule().fill(face).frame(width: s * 0.07, height: s * 0.018)
        }
    }

    // MARK: Extras around the body

    @ViewBuilder private func extras(t: Double) -> some View {
        switch mood {
        case .proud:  sparkles(t: t)
        case .sleepy: sleepyZs(t: t)
        case .tense, .tired: sweat(t: t)
        case .search: question(t: t)
        case .calm, .listen: motes(t: t)
        default: EmptyView()
        }
    }

    private func sparkles(t: Double) -> some View {
        let s = size
        let xs: [CGFloat] = [-0.48, 0.5, -0.42, 0.46]
        let ys: [CGFloat] = [-0.25, -0.32, 0.18, 0.12]
        return ForEach(0..<4, id: \.self) { i in
            Image(systemName: "sparkle")
                .font(.system(size: s * (i % 2 == 0 ? 0.12 : 0.08)))
                .foregroundStyle(tint)
                .opacity(0.6 + 0.4 * sin(2 * Double.pi * (t / 1.2 + Double(i) * 0.25)))
                .offset(x: xs[i] * s, y: ys[i] * s)
        }
    }

    private func sleepyZs(t: Double) -> some View {
        let s = size
        return ForEach(0..<3, id: \.self) { i in
            let p = CGFloat((t / 4.5 + Double(i) / 3).truncatingRemainder(dividingBy: 1))
            Text("z")
                .font(.system(size: s * (0.08 + 0.06 * p), weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .opacity(Double(sin(CGFloat.pi * p)))
                .offset(x: s * (0.32 + 0.18 * p), y: -s * (0.12 + 0.35 * p))
        }
    }

    private func sweat(t: Double) -> some View {
        let s = size
        let drip = CGFloat((t / 2.4).truncatingRemainder(dividingBy: 1))
        return Image(systemName: "drop.fill")
            .font(.system(size: s * 0.09))
            .foregroundStyle(Color.cyan.opacity(Double(0.8 * (1 - drip))))
            .offset(x: s * 0.38, y: -s * 0.12 + s * 0.1 * drip)
    }

    private func question(t: Double) -> some View {
        let s = size
        return Text("?")
            .font(.system(size: s * 0.16, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .rotationEffect(.degrees(10 * sin(2 * Double.pi * t / 2)))
            .offset(x: s * 0.42, y: -s * 0.35)
    }

    /// A few small lights drifting up, slowly.
    private func motes(t: Double) -> some View {
        let s = size
        let xs: [CGFloat] = [-0.45, 0.42, -0.3, 0.5, -0.52]
        return ForEach(0..<5, id: \.self) { i in
            let p = CGFloat((t / (6 + Double(i)) + Double(i) * 0.37).truncatingRemainder(dividingBy: 1))
            Circle()
                .fill(tint.opacity(0.7))
                .frame(width: s * (i % 2 == 0 ? 0.02 : 0.03))
                .opacity(Double(sin(CGFloat.pi * p)))
                .offset(x: s * xs[i], y: s * (0.35 - 0.8 * p))
        }
    }

    private func breathingRing(fill: Double) -> some View {
        let d = size * (0.95 + 0.4 * CGFloat(fill))
        return Circle()
            .stroke(tint.opacity(0.5), lineWidth: max(1.5, size * 0.012))
            .frame(width: d, height: d)
            .opacity(0.4 + 0.6 * fill)
            .offset(y: size * 0.06)
    }
}

// MARK: - Small shapes

private struct Chevron: Shape {           // ^ when up
    let up: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: up ? r.maxY : r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: up ? r.minY : r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: up ? r.maxY : r.minY))
        return p
    }
}

private struct Arc: Shape {               // smile / closed lid when down
    let down: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: down ? r.minY : r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: down ? r.minY : r.maxY),
                       control: CGPoint(x: r.midX, y: down ? r.maxY * 2 - r.minY : r.minY * 2 - r.maxY))
        return p
    }
}

private struct HalfDisc: Shape {          // open laugh
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

private struct Wave: Shape {              // wavy mouth
    func path(in r: CGRect) -> Path {
        var p = Path()
        let n = 4
        let w = r.width / CGFloat(n)
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        for i in 0..<n {
            p.addQuadCurve(to: CGPoint(x: r.minX + w * CGFloat(i + 1), y: r.midY),
                           control: CGPoint(x: r.minX + w * (CGFloat(i) + 0.5),
                                            y: i % 2 == 0 ? r.minY : r.maxY))
        }
        return p
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 24) {
            ForEach(WispMood.allCases.filter { $0 != .unknown }, id: \.self) { m in
                VStack(spacing: 8) {
                    WispView(mood: m, size: 100, color: m.color)
                    Text(m.title).font(.caption).foregroundStyle(.white)
                }
            }
        }
        .padding()
    }
    .background(Color.black)
}
