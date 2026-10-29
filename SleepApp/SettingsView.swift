//
//  SettingsView.swift
//  SleepApp
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var themeManager: ThemeManager
    @Query private var profiles: [UserProfile]

    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("hasAppleWatch") private var hasAppleWatch = false
    @AppStorage("healthKitAuthorized") private var healthKitAuthorized = false

    @State private var age: Int = 18
    @State private var gender: String = ""
    @State private var targetHours: Double = 8.0

    private let genderOptions = ["Not specified", "Male", "Female", "Other"]

    /// Apple Ayarlar tarzi satir: renkli kare ikon + baslik
    private func rowLabel(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            IconTile(icon: icon, color: color, size: 30)
            Text(title)
                .foregroundStyle(themeManager.theme.textColor)
        }
    }

    // Today'deki disliden acilir (push), bu yuzden kendi NavigationStack'i yok.
    var body: some View {
            Form {
                // Uyku hedefi: siyah kadran
                Section {
                    goalPanel
                        .listRowInsets(EdgeInsets())
                }
                .listRowBackground(Color.clear)

                Section {
                    Stepper(value: $age, in: 10...100) {
                        HStack {
                            rowLabel("Age", icon: "person.fill", color: themeManager.theme.primaryColor)
                            Spacer()
                            Text("\(age)")
                                .monospacedDigit()
                                .foregroundStyle(themeManager.theme.secondaryTextColor)
                        }
                    }

                    Picker(selection: $gender) {
                        ForEach(genderOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    } label: {
                        rowLabel("Gender", icon: "figure.stand", color: DS.Metric.hrv)
                    }

                    Button {
                        saveProfile()
                    } label: {
                        Text("Save profile")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundStyle(themeManager.theme.primaryColor)
                } header: {
                    Text("Profile")
                }
                .listRowBackground(themeManager.theme.surface)

                Section {
                    Toggle(isOn: $hasAppleWatch) {
                        rowLabel("I wear an Apple Watch", icon: "applewatch", color: Color(hex: 0x1D1D1F))
                    }
                    .onChange(of: hasAppleWatch) { _, newValue in
                        handleWatchToggle(newValue)
                    }
                } header: {
                    Text("Sleep Tracking")
                } footer: {
                    Text(hasAppleWatch
                         ? (healthKitAuthorized
                            ? "Somna will automatically track your sleep duration and score from your Apple Watch."
                            : "Health access hasn't been granted yet. Toggle off and back on to try again.")
                         : "You'll log your sleep manually — bedtime, wake time, and quality.")
                }
                .listRowBackground(themeManager.theme.surface)

                Section {
                    Toggle(isOn: $soundEnabled) {
                        rowLabel("Sound effects", icon: "speaker.wave.2.fill", color: DS.Metric.heart)
                    }
                    Toggle(isOn: $hapticsEnabled) {
                        rowLabel("Haptic feedback", icon: "iphone.radiowaves.left.and.right", color: DS.Metric.strain)
                    }
                    Toggle(isOn: $notificationsEnabled) {
                        rowLabel("Daily reminders", icon: "bell.fill", color: DS.Metric.stressHigh)
                    }
                    .onChange(of: notificationsEnabled) { _, newValue in
                        handleNotificationToggle(newValue)
                    }
                } header: {
                    Text("Preferences")
                } footer: {
                    if notificationsEnabled {
                        Text("You'll get a reminder in the evening if you haven't logged your sleep, plus two quick check-ins during the day (1pm and 5:30pm).")
                    }
                }
                .listRowBackground(themeManager.theme.surface)

                Section {
                    HStack {
                        rowLabel(themeManager.theme == .day ? "Day theme" : "Night theme",
                                 icon: themeManager.theme.icon,
                                 color: themeManager.theme == .day ? DS.Metric.quality : DS.Metric.sleep)
                        Spacer()
                        Text("Auto")
                            .foregroundStyle(themeManager.theme.secondaryTextColor)
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Theme automatically switches based on the time of day.")
                }
                .listRowBackground(themeManager.theme.surface)

                Section {
                    NavigationLink {
                        AboutSleepView()
                    } label: {
                        rowLabel("About Sleep", icon: "book.fill", color: DS.Metric.readiness)
                    }
                } header: {
                    Text("Learn")
                }
                .listRowBackground(themeManager.theme.surface)

                Section {
                    HStack {
                        rowLabel("Version", icon: "info.circle.fill", color: Color(hex: 0x8E8E93))
                        Spacer()
                        Text("1.1.0")
                            .foregroundStyle(themeManager.theme.secondaryTextColor)
                    }
                }
                .listRowBackground(themeManager.theme.surface)
            }
            .tint(themeManager.theme.primaryColor)
            .scrollContentBackground(.hidden)
            .background(themeManager.theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Settings")
            .onAppear {
                themeManager.refresh()
                loadProfile()
            }
    }

    private func handleWatchToggle(_ isEnabled: Bool) {
        if isEnabled {
            HealthKitManager.shared.requestSleepAuthorization { granted, _ in
                healthKitAuthorized = granted
            }
        } else {
            healthKitAuthorized = false
        }
    }

    private func handleNotificationToggle(_ isEnabled: Bool) {
        if isEnabled {
            NotificationManager.shared.requestAuthorization { granted in
                if granted {
                    NotificationManager.shared.scheduleAllReminders()
                } else {
                    notificationsEnabled = false
                }
            }
        } else {
            NotificationManager.shared.cancelAllReminders()
        }
    }

    private func loadProfile() {
        if let existing = profiles.first {
            age = existing.age
            gender = existing.gender.isEmpty ? "Not specified" : existing.gender
            targetHours = Double(existing.targetSleepMinutes) / 60.0
        } else {
            gender = "Not specified"
        }
    }

    // MARK: - Uyku hedefi paneli (yatay kaydirici)

    private var goalPanel: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: 5) {
                Image(systemName: "target").font(.caption.weight(.bold))
                Text("SLEEP GOAL").font(DS.Typography.dialLabel).tracking(0.6)
            }
            .foregroundStyle(DS.Metric.sleepLight)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: targetHours.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", targetHours))
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(DS.Panel.text)
                Text("hours / night")
                    .font(DS.Typography.callout.weight(.semibold))
                    .foregroundStyle(DS.Panel.secondary)
            }
            .animation(DS.Motion.snappy, value: targetHours)

            Slider(value: $targetHours, in: 5...10, step: 0.5) {
                Text("Target sleep")
            } minimumValueLabel: {
                Text("5h").font(.caption2).foregroundStyle(DS.Panel.muted)
            } maximumValueLabel: {
                Text("10h").font(.caption2).foregroundStyle(DS.Panel.muted)
            }
            .tint(DS.Metric.sleepGlow)
            .sensoryFeedback(.selection, trigger: targetHours)

            Text("Tap “Save profile” below to keep your changes.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Panel.secondary)
        }
        .watchPanel(padding: DS.Spacing.lg - 2, glow: DS.Metric.sleepGlow.opacity(0.6))
    }

    private func saveProfile() {
        if let existing = profiles.first {
            existing.age = age
            existing.gender = gender
            existing.targetSleepMinutes = Int(targetHours * 60)
        } else {
            let newProfile = UserProfile(
                age: age,
                gender: gender,
                targetSleepMinutes: Int(targetHours * 60)
            )
            modelContext.insert(newProfile)
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environmentObject(ThemeManager())
        .modelContainer(for: [SleepEntry.self, UserProfile.self], inMemory: true)
}
