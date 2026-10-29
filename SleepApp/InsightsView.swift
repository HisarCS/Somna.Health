//
//  InsightsView.swift
//  SleepApp
//

import SwiftUI
import SwiftData

struct InsightsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Query(sort: \SleepEntry.date, order: .forward) private var entries: [SleepEntry]
    @Query private var profiles: [UserProfile]

    private let minimumEntriesPerGroup = 3

    private var targetSleepMinutes: Int {
        profiles.first?.targetSleepMinutes ?? 480
    }

    private var recentAverageMinutes: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = entries.filter { $0.date >= cutoff }
        guard !recent.isEmpty else { return 0 }
        return recent.reduce(0) { $0 + $1.durationInMinutes } / recent.count
    }

    private var longestStreak: Int {
        guard !entries.isEmpty else { return 0 }
        let sortedDays = Set(entries.map { Calendar.current.startOfDay(for: $0.date) }).sorted()

        var longest = 1
        var current = 1
        for i in 1..<sortedDays.count {
            let diff = Calendar.current.dateComponents([.day], from: sortedDays[i-1], to: sortedDays[i]).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return sortedDays.isEmpty ? 0 : longest
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.theme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        NavigationLink {
                            WeeklyReportView(entries: entries)
                        } label: {
                            weeklyReportCard()
                        }
                        .buttonStyle(.plain)

                        if !entries.isEmpty {
                            HStack(spacing: 12) {
                                statCard(
                                    icon: "flame.fill",
                                    iconColor: .orange,
                                    title: "Longest streak",
                                    value: "\(longestStreak)",
                                    unit: longestStreak == 1 ? "day" : "days"
                                )
                                statCard(
                                    icon: "target",
                                    iconColor: themeManager.theme.primaryColor,
                                    title: "Sleep goal",
                                    value: formatDuration(targetSleepMinutes),
                                    unit: "target"
                                )
                            }

                            goalProgressCard()
                        }

                        if entries.count < 5 {
                            VStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 40))
                                    .foregroundStyle(themeManager.theme.mutedTextColor)
                                Text("Not enough data yet")
                                    .font(.headline)
                                    .foregroundStyle(themeManager.theme.headingColor)
                                Text("Log at least 5 days of sleep to start seeing personal insights.")
                                    .font(.subheadline)
                                    .foregroundStyle(themeManager.theme.secondaryTextColor)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                            .padding(.horizontal)
                        } else {
                            insightCard(
                                habitName: "Caffeine",
                                icon: "cup.and.saucer.fill",
                                color: themeManager.theme.primaryColor,
                                withHabit: { $0.hadCaffeine },
                                metric: { Double($0.durationInMinutes) }
                            )

                            insightCard(
                                habitName: "Screen time before bed",
                                icon: "iphone",
                                color: themeManager.theme.primaryColor,
                                withHabit: { $0.hadScreenBeforeBed },
                                metric: { Double($0.durationInMinutes) }
                            )

                            insightCard(
                                habitName: "Exercise",
                                icon: "figure.run",
                                color: themeManager.theme.primaryColor,
                                withHabit: { $0.didExercise },
                                metric: { Double($0.durationInMinutes) }
                            )

                            insightCard(
                                habitName: "Alcohol",
                                icon: "wineglass.fill",
                                color: themeManager.theme.primaryColor,
                                withHabit: { $0.hadAlcohol },
                                metric: { Double($0.durationInMinutes) }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Insights")
        }
        .onAppear {
            themeManager.refresh()
        }
    }

    private func weeklyReportCard() -> some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [themeManager.theme.primaryColor.opacity(0.85), themeManager.theme.secondaryColor.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 80))
                .foregroundStyle(.white.opacity(0.15))
                .rotationEffect(.degrees(-10))
                .offset(x: 90, y: -10)

            VStack(alignment: .leading, spacing: 4) {
                Text("SEE YOUR")
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.85))
                Text("Weekly Report")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                HStack(spacing: 4) {
                    Text("View report")
                        .font(.caption.bold())
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 4)
            }
            .padding(20)
        }
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: themeManager.theme.accentGlow, radius: 12, x: 0, y: 6)
    }

    private func statCard(icon: String, iconColor: Color, title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(themeManager.theme.textColor)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(themeManager.theme.secondaryTextColor)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(themeManager.theme.mutedTextColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(themeManager.theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func goalProgressCard() -> some View {
        let diff = recentAverageMinutes - targetSleepMinutes
        let isAbove = diff >= 0
        let absDiff = abs(diff)
        let hours = absDiff / 60
        let mins = absDiff % 60
        let diffText = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"

        let progress = targetSleepMinutes > 0
            ? min(Double(recentAverageMinutes) / Double(targetSleepMinutes), 1.5)
            : 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(themeManager.theme.primaryColor)
                Text("Goal progress")
                    .font(.subheadline.bold())
                    .foregroundStyle(themeManager.theme.headingColor)
            }

            if recentAverageMinutes == 0 {
                Text("Log some nights to see how you're tracking against your goal.")
                    .font(.subheadline)
                    .foregroundStyle(themeManager.theme.secondaryTextColor)
            } else {
                Text(isAbove
                    ? "You're averaging \(diffText) above your \(formatDuration(targetSleepMinutes)) goal over the last 7 days."
                    : "You're averaging \(diffText) below your \(formatDuration(targetSleepMinutes)) goal over the last 7 days.")
                    .font(.subheadline)
                    .foregroundStyle(themeManager.theme.textColor)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(themeManager.theme.mutedTextColor.opacity(0.2))
                            .frame(height: 8)
                        Capsule()
                            .fill(isAbove ? Color.green : themeManager.theme.primaryColor)
                            .frame(width: geo.size.width * min(progress, 1.0), height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func insightCard(
        habitName: String,
        icon: String,
        color: Color,
        withHabit: (SleepEntry) -> Bool,
        metric: (SleepEntry) -> Double
    ) -> some View {
        let withEntries = entries.filter { withHabit($0) }
        let withoutEntries = entries.filter { !withHabit($0) }

        if withEntries.count >= minimumEntriesPerGroup && withoutEntries.count >= minimumEntriesPerGroup {
            let avgWith = withEntries.map(metric).reduce(0, +) / Double(withEntries.count)
            let avgWithout = withoutEntries.map(metric).reduce(0, +) / Double(withoutEntries.count)
            let diffMinutes = Int(avgWith - avgWithout)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(habitName)
                        .font(.subheadline.bold())
                        .foregroundStyle(themeManager.theme.headingColor)
                }

                if diffMinutes == 0 {
                    Text("No noticeable difference in your sleep duration.")
                        .font(.subheadline)
                        .foregroundStyle(themeManager.theme.secondaryTextColor)
                } else {
                    let direction = diffMinutes > 0 ? "more" : "less"
                    let absMinutes = abs(diffMinutes)
                    let hours = absMinutes / 60
                    let mins = absMinutes % 60
                    let durationText = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"

                    Text("On days with \(habitName.lowercased()), you slept \(durationText) \(direction) on average.")
                        .font(.subheadline)
                        .foregroundStyle(themeManager.theme.textColor)

                    if let actionMessage = actionMessage(for: habitName, diffMinutes: diffMinutes) {
                        HStack(spacing: 8) {
                            Image(systemName: diffMinutes < 0 || habitName != "Exercise" ? "arrow.right.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(diffMinutes > 0 && habitName == "Exercise" ? .green : color)
                            Text(actionMessage)
                                .font(.caption.bold())
                                .foregroundStyle(diffMinutes > 0 && habitName == "Exercise" ? .green : color)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(themeManager.theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color.opacity(0.5))
                    Text(habitName)
                        .font(.subheadline.bold())
                        .foregroundStyle(themeManager.theme.secondaryTextColor)
                }
                Text("Keep logging to unlock this insight.")
                    .font(.subheadline)
                    .foregroundStyle(themeManager.theme.mutedTextColor)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(themeManager.theme.cardBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    /// Habit'e ve etkinin yonune (diffMinutes) gore aksiyon mesaji dondurur.
    /// Sadece Exercise icin olumlu (positive) senaryo var - digerleri (kafein, alkol, ekran)
    /// icin bilimsel olarak "olumlu" bir mesaj vermiyoruz, sadece olumsuzsa oneri gosteriyoruz.
    private func actionMessage(for habitName: String, diffMinutes: Int) -> String? {
        switch habitName {
        case "Caffeine":
            return diffMinutes < 0 ? "Try skipping caffeine today and see the difference." : nil
        case "Screen time before bed":
            return diffMinutes < 0 ? "Try putting your phone away an hour before bed tonight." : nil
        case "Alcohol":
            return diffMinutes < 0 ? "Try an alcohol-free night and compare tomorrow." : nil
        case "Exercise":
            if diffMinutes < 0 {
                return "Try exercising earlier in the day — closer to bedtime may affect your sleep."
            } else if diffMinutes > 0 {
                return "Keep it up — exercise seems to be helping your sleep."
            } else {
                return nil
            }
        default:
            return nil
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }
}

#Preview {
    InsightsView()
        .environmentObject(ThemeManager())
        .modelContainer(for: [SleepEntry.self, UserProfile.self], inMemory: true)
}
