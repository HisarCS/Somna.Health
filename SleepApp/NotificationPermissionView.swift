//
//  NotificationPermissionView.swift
//  SleepApp
//

import SwiftUI

struct NotificationPermissionView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false

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
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(themeManager.theme.primaryColor)
                }

                VStack(spacing: 12) {
                    Text("Stay on track")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.theme.headingColor)

                    Text("Get a gentle reminder in the evening if you forget to log your sleep, plus quick check-ins during the day to see how you're feeling.")
                        .font(.body)
                        .foregroundStyle(themeManager.theme.secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        enableNotifications()
                    } label: {
                        Text("Enable Reminders")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(themeManager.theme.primaryColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        onComplete()
                    } label: {
                        Text("Not Now")
                            .font(.subheadline.bold())
                            .foregroundStyle(themeManager.theme.secondaryTextColor)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }

    private func enableNotifications() {
        NotificationManager.shared.requestAuthorization { granted in
            notificationsEnabled = granted
            if granted {
                NotificationManager.shared.scheduleAllReminders()
            }
            onComplete()
        }
    }
}

#Preview {
    NotificationPermissionView(onComplete: {})
        .environmentObject(ThemeManager())
}
