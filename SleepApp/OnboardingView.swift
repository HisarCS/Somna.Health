//
//  OnboardingView.swift
//  SleepApp
//

import SwiftUI

struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
}

struct OnboardingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var currentPage = 0
    @State private var showFinalAnimation = false
    @State private var showProfileSetup = false
    @State private var showWatchSetup = false
    @State private var showNotificationPermission = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "moon.stars.fill",
            title: "Sleep, understood.",
            subtitle: "A simple way to track your sleep, spot your patterns, and build a routine that actually works for you.",
            color: Color(red: 0.62, green: 0.4, blue: 1.0)
        ),
        OnboardingPage(
            icon: "checkmark.circle.fill",
            title: "One check-in a day",
            subtitle: "Log your bedtime, wake time, and quality in seconds. Build a streak and watch your consistency grow.",
            color: Color(red: 0.95, green: 0.55, blue: 0.35)
        ),
        OnboardingPage(
            icon: "chart.bar.fill",
            title: "See your patterns",
            subtitle: "Track your sleep duration and quality over 7 or 30 days — and tap any night for the full story.",
            color: Color(red: 0.3, green: 0.6, blue: 1.0)
        ),
        OnboardingPage(
            icon: "sparkles",
            title: "Discover what works",
            subtitle: "Get personal insights on how caffeine, screens, and exercise actually affect your sleep.",
            color: Color(red: 0.35, green: 0.8, blue: 0.55)
        )
    ]

    var body: some View {
        ZStack {
            themeManager.theme.backgroundGradient
                .ignoresSafeArea()

            if showNotificationPermission {
                NotificationPermissionView {
                    hasCompletedOnboarding = true
                }
                .transition(.opacity)
            } else if showWatchSetup {
                WatchSetupView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showNotificationPermission = true
                    }
                }
                .transition(.opacity)
            } else if showProfileSetup {
                ProfileSetupView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showWatchSetup = true
                    }
                }
                .transition(.opacity)
            } else if showFinalAnimation {
                finalWelcomeView
                    .transition(.opacity)
            } else {
                onboardingPagesView
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Sayfa akisi

    private var onboardingPagesView: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip") {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        showFinalAnimation = true
                    }
                }
                .font(.subheadline)
                .foregroundStyle(themeManager.theme.mutedTextColor)
                .padding()
            }

            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? themeManager.theme.primaryColor : themeManager.theme.mutedTextColor.opacity(0.3))
                        .frame(width: index == currentPage ? 20 : 8, height: 8)
                        .animation(.easeInOut, value: currentPage)
                }
            }
            .padding(.bottom, 24)

            HStack(spacing: 16) {
                if currentPage > 0 {
                    Button {
                        withAnimation { currentPage -= 1 }
                    } label: {
                        Text("Back")
                            .font(.subheadline.bold())
                            .foregroundStyle(themeManager.theme.textColor)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(themeManager.theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            showFinalAnimation = true
                        }
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Continue")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.theme.primaryColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.color.opacity(0.15))
                    .frame(width: 160, height: 160)
                Image(systemName: page.icon)
                    .font(.system(size: 64))
                    .foregroundStyle(page.color)
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.theme.headingColor)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(themeManager.theme.secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Final "welcome to your journey" ekrani

    private var finalWelcomeView: some View {
        FinalWelcomeView(themeManager: themeManager) {
            withAnimation(.easeInOut(duration: 0.5)) {
                showProfileSetup = true
            }
        }
    }
}

struct FinalWelcomeView: View {
    @ObservedObject var themeManager: ThemeManager
    let onComplete: () -> Void

    @State private var starOpacities: [Double] = Array(repeating: 0, count: 18)
    @State private var glowScale: CGFloat = 0.7
    @State private var glowOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0

    private let starPositions: [CGPoint] = (0..<18).map { _ in
        CGPoint(x: .random(in: 20...360), y: .random(in: 80...600))
    }

    var body: some View {
        ZStack {
            ForEach(0..<starPositions.count, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: CGFloat.random(in: 8...16)))
                    .foregroundStyle(themeManager.theme.secondaryColor)
                    .opacity(starOpacities[i])
                    .position(starPositions[i])
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [themeManager.theme.primaryColor.opacity(0.4), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .scaleEffect(glowScale)
                .opacity(glowOpacity)

            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(themeManager.theme.primaryColor)
                    .opacity(textOpacity)

                VStack(spacing: 8) {
                    Text("Welcome to")
                        .font(.title2)
                        .foregroundStyle(themeManager.theme.secondaryTextColor)
                    Text("your journey")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.theme.headingColor)
                }
                .opacity(textOpacity)

                Text("Every night you log brings you closer to understanding yourself.")
                    .font(.subheadline)
                    .foregroundStyle(themeManager.theme.secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(textOpacity)

                Spacer()

                Button {
                    onComplete()
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.theme.primaryColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                .opacity(buttonOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                glowScale = 1.0
                glowOpacity = 1.0
            }
            for i in starOpacities.indices {
                withAnimation(.easeIn(duration: 0.8).delay(Double.random(in: 0...1.2))) {
                    starOpacities[i] = Double.random(in: 0.3...0.8)
                }
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
                textOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(1.0)) {
                buttonOpacity = 1.0
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(ThemeManager())
}
