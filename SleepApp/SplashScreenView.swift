//
//  SplashScreenView.swift
//  SleepApp
//

import SwiftUI

struct SplashScreenView: View {
    let onFinished: () -> Void

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.88
    @State private var sloganOpacity: Double = 0
    @State private var sunGlow: Double = 0
    @State private var moonGlow: Double = 0
    @State private var starOpacities: [Double] = Array(repeating: 0, count: 14)
    @State private var rayOpacity: Double = 0

    private let starOffsets: [(CGFloat, CGFloat, CGFloat)] = [
        (30, -220, 3), (80, -160, 2), (55, -90, 3.5), (110, -40, 2.5),
        (40, 30, 3), (95, 100, 2), (60, 170, 3.5), (25, 240, 2.5),
        (130, -190, 2), (140, 60, 3), (70, -260, 2.5), (100, 200, 2),
        (45, -130, 2), (120, 140, 2.5)
    ]

    var body: some View {
        GeometryReader { geo in
            let fullWidth = geo.size.width
            let fullHeight = geo.size.height
            let half = fullWidth / 2

            ZStack {
                // GUNDUZ - sol yari
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.82, blue: 0.55),
                            Color(red: 1.0, green: 0.90, blue: 0.72),
                            Color(red: 1.0, green: 0.95, blue: 0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.95),
                                    Color(red: 1.0, green: 0.7, blue: 0.3).opacity(0.35),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 5,
                                endRadius: 190
                            )
                        )
                        .frame(width: 380, height: 380)
                        .position(x: half - 70, y: fullHeight / 2 - 60)
                        .opacity(sunGlow)

                    ForEach(0..<7, id: \.self) { i in
                        Capsule()
                            .fill(Color.white.opacity(0.28))
                            .frame(width: 2.5, height: 150)
                            .offset(y: -95)
                            .rotationEffect(.degrees(Double(i) * 26 - 78))
                            .position(x: half - 70, y: fullHeight / 2 - 60)
                            .opacity(rayOpacity)
                    }
                }
                .frame(width: half, height: fullHeight)
                .position(x: half / 2, y: fullHeight / 2)

                // GECE - sag yari
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.07, blue: 0.24),
                            Color(red: 0.07, green: 0.05, blue: 0.16),
                            Color(red: 0.04, green: 0.03, blue: 0.10)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.72, green: 0.62, blue: 1.0).opacity(0.75),
                                    Color(red: 0.45, green: 0.3, blue: 0.95).opacity(0.28),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 5,
                                endRadius: 180
                            )
                        )
                        .frame(width: 340, height: 340)
                        .position(x: 70, y: fullHeight / 2 - 60)
                        .opacity(moonGlow)

                    ForEach(0..<starOffsets.count, id: \.self) { i in
                        Circle()
                            .fill(Color.white)
                            .frame(width: starOffsets[i].2, height: starOffsets[i].2)
                            .position(
                                x: starOffsets[i].0,
                                y: fullHeight / 2 + starOffsets[i].1
                            )
                            .opacity(starOpacities[i])
                            .shadow(color: .white.opacity(0.8), radius: 3)
                    }
                }
                .frame(width: half, height: fullHeight)
                .position(x: half + half / 2, y: fullHeight / 2)

                // Ortadaki net ayrim cizgisi
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.35),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 40, height: fullHeight)
                    .blur(radius: 8)
                    .position(x: half, y: fullHeight / 2)

                // Logo + slogan
                VStack(spacing: 18) {
                    Text("Somna")
                        .font(.system(size: 62, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.99, green: 0.97, blue: 0.95))
                        .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 4)
                        .shadow(color: .white.opacity(0.5), radius: 30)
                        .opacity(logoOpacity)
                        .scaleEffect(logoScale)

                    Text("Every night has a story.")
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.99, green: 0.97, blue: 0.95).opacity(0.92))
                        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 2)
                        .opacity(sloganOpacity)
                }
                .position(x: fullWidth / 2, y: fullHeight / 2)
            }
            .frame(width: fullWidth, height: fullHeight)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 1.5)) {
                sunGlow = 1.0
                moonGlow = 1.0
            }
            withAnimation(.easeOut(duration: 1.8).delay(0.2)) {
                rayOpacity = 1.0
            }
            for i in starOpacities.indices {
                withAnimation(.easeIn(duration: 0.9).delay(Double.random(in: 0.1...1.3))) {
                    starOpacities[i] = Double.random(in: 0.55...1.0)
                }
            }
            withAnimation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.35)) {
                logoOpacity = 1.0
                logoScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.9).delay(0.85)) {
                sloganOpacity = 1.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                onFinished()
            }
        }
    }
}

#Preview {
    SplashScreenView(onFinished: {})
}
