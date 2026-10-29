//
//  WatchSetupView.swift
//  SleepApp
//

import SwiftUI

struct WatchSetupView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("hasAppleWatch") private var hasAppleWatch = false
    @AppStorage("healthKitAuthorized") private var healthKitAuthorized = false

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            themeManager.theme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(themeManager.theme.primaryColor.opacity(0.15))
                        .frame(width: 140, height: 140)
                    Image(systemName: "applewatch")
                        .font(.system(size: 56))
                        .foregroundStyle(themeManager.theme.primaryColor)
                }

                VStack(spacing: 12) {
                    Text("Do you wear an Apple Watch?")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.theme.headingColor)
                        .multilineTextAlignment(.center)

                    Text("If you do, Somna can automatically track your sleep duration and score — no manual entry needed. You can change this anytime in Settings.")
                        .font(.body)
                        .foregroundStyle(themeManager.theme.secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        connectWatch()
                    } label: {
                        Text("Yes, I wear an Apple Watch")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(themeManager.theme.primaryColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        hasAppleWatch = false
                        onComplete()
                    } label: {
                        Text("No, I'll log manually")
                            .font(.subheadline.bold())
                            .foregroundStyle(themeManager.theme.secondaryTextColor)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }

    private func connectWatch() {
        HealthKitManager.shared.requestSleepAuthorization { granted, _ in
            hasAppleWatch = true
            healthKitAuthorized = granted
            onComplete()
        }
    }
}

#Preview {
    WatchSetupView(onComplete: {})
        .environmentObject(ThemeManager())
}
