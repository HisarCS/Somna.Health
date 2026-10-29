//
//  ConfettiView.swift
//  SleepApp
//

import SwiftUI

enum ConfettiIntensity {
    case subtle
    case celebration

    var particleCount: Int {
        switch self {
        case .subtle: return 12
        case .celebration: return 60
        }
    }

    var duration: Double {
        switch self {
        case .subtle: return 0.8
        case .celebration: return 1.8
        }
    }

    var colors: [Color] {
        switch self {
        case .subtle:
            return [.orange, .yellow]
        case .celebration:
            return [.orange, .yellow, .pink, .purple, .blue, .green]
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var rotation: Double
    var scale: CGFloat
    var color: Color
    var opacity: Double
}

struct ConfettiView: View {
    let intensity: ConfettiIntensity
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: 8, height: 8)
                        .scaleEffect(particle.scale)
                        .rotationEffect(.degrees(particle.rotation))
                        .position(x: particle.x, y: particle.y)
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                spawnParticles(in: geo.size)
            }
        }
        .allowsHitTesting(false)
    }

    private func spawnParticles(in size: CGSize) {
        var newParticles: [ConfettiParticle] = []
        for _ in 0..<intensity.particleCount {
            let startX = CGFloat.random(in: size.width * 0.2...size.width * 0.8)
            let startY = size.height * 0.4
            newParticles.append(
                ConfettiParticle(
                    x: startX,
                    y: startY,
                    rotation: Double.random(in: 0...360),
                    scale: CGFloat.random(in: 0.6...1.4),
                    color: intensity.colors.randomElement() ?? .orange,
                    opacity: 1.0
                )
            )
        }
        particles = newParticles

        for index in particles.indices {
            let endX = particles[index].x + CGFloat.random(in: -80...80)
            let endY = particles[index].y - CGFloat.random(in: 100...250)
            withAnimation(.easeOut(duration: intensity.duration)) {
                particles[index].x = endX
                particles[index].y = endY
                particles[index].opacity = 0
                particles[index].rotation += Double.random(in: 180...720)
            }
        }
    }
}
