//
//  WeeklyReportView.swift
//  SleepApp
//

import SwiftUI
import SwiftData
import Charts

struct WeeklyReportView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let entries: [SleepEntry]

    private var thisWeekEntries: [SleepEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return entries.filter { $0.date >= cutoff }
    }

    private var lastWeekEntries: [SleepEntry] {
        let start = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let end = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return entries.filter { $0.date >= start && $0.date < end }
    }

    private var thisWeekAvgMinutes: Int {
        guard !thisWeekEntries.isEmpty else { return 0 }
        return thisWeekEntries.reduce(0) { $0 + $1.durationInMinutes } / thisWeekEntries.count
    }

    private var lastWeekAvgMinutes: Int {
        guard !lastWeekEntries.isEmpty else { return 0 }
        return lastWeekEntries.reduce(0) { $0 + $1.durationInMinutes } / lastWeekEntries.count
    }

    private var percentChange: Int? {
        guard lastWeekAvgMinutes > 0 else { return nil }
        let diff = Double(thisWeekAvgMinutes - lastWeekAvgMinutes)
        return Int((diff / Double(lastWeekAvgMinutes)) * 100)
    }

    private var bestNight: SleepEntry? {
        thisWeekEntries.max { $0.quality < $1.quality }
    }

    private var worstNight: SleepEntry? {
        thisWeekEntries.min { $0.quality < $1.quality }
    }

    private var mostConsistentHabit: (name: String, percentage: Int)? {
        guard !thisWeekEntries.isEmpty else { return nil }
        let exerciseCount = thisWeekEntries.filter { $0.didExercise }.count
        let noCaffeineCount = thisWeekEntries.filter { !$0.hadCaffeine }.count
        let noScreenCount = thisWeekEntries.filter { !$0.hadScreenBeforeBed }.count

        let total = thisWeekEntries.count
        let options = [
            ("exercised", exerciseCount),
            ("avoided caffeine", noCaffeineCount),
            ("stayed off screens before bed", noScreenCount)
        ]
        guard let top = options.max(by: { $0.1 < $1.1 }), top.1 > 0 else { return nil }
        return (top.0, Int((Double(top.1) / Double(total)) * 100))
    }

    private var weeklyFocusMessage: String? {
        guard thisWeekEntries.count >= 3 else { return nil }

        let habits: [(name: String, icon: String, hasHabit: (SleepEntry) -> Bool)] = [
            ("caffeine", "cup.and.saucer.fill", { $0.hadCaffeine }),
            ("screen time before bed", "iphone", { $0.hadScreenBeforeBed }),
            ("alcohol", "wineglass.fill", { $0.hadAlcohol })
        ]

        var worstDiff = 0
        var worstHabitName: String? = nil

        for habit in habits {
            let withHabit = thisWeekEntries.filter(habit.hasHabit)
            let withoutHabit = thisWeekEntries.filter { !habit.hasHabit($0) }
            guard !withHabit.isEmpty, !withoutHabit.isEmpty else { continue }

            let avgWith = withHabit.reduce(0) { $0 + $1.durationInMinutes } / withHabit.count
            let avgWithout = withoutHabit.reduce(0) { $0 + $1.durationInMinutes } / withoutHabit.count
            let diff = avgWith - avgWithout

            if diff < worstDiff {
                worstDiff = diff
                worstHabitName = habit.name
            }
        }

        if let habitName = worstHabitName, worstDiff < -10 {
            return "This week, \(habitName) seemed to cost you the most sleep. Try one \(habitName)-free night next week and see what changes."
        }

        // Negatif bir sey bulunamadiysa, en iyi gecenin ortak noktasini vurgula
        if let best = bestNight, best.didExercise {
            return "Your best night this week included exercise. Try fitting in movement a few more days next week."
        }

        return nil
    }

    var body: some View {
        ZStack {
            themeManager.theme.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if thisWeekEntries.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 40))
                                .foregroundStyle(themeManager.theme.mutedTextColor)
                            Text("No data this week yet")
                                .font(.headline)
                                .foregroundStyle(themeManager.theme.headingColor)
                            Text("Log your sleep to see your weekly report.")
                                .font(.subheadline)
                                .foregroundStyle(themeManager.theme.secondaryTextColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                    } else {
                        // Hero baslik
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Week in Sleep")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(themeManager.theme.headingColor)
                            Text(dateRangeText())
                                .font(.subheadline)
                                .foregroundStyle(themeManager.theme.secondaryTextColor)
                        }

                        // Ana ortalama karti
                        VStack(spacing: 8) {
                            Text(formatDuration(thisWeekAvgMinutes))
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(themeManager.theme.textColor)
                            Text("average sleep per night")
                                .font(.subheadline)
                                .foregroundStyle(themeManager.theme.secondaryTextColor)

                            if let change = percentChange {
                                HStack(spacing: 4) {
                                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    Text("\(abs(change))% \(change >= 0 ? "more" : "less") than last week")
                                }
                                .font(.caption.bold())
                                .foregroundStyle(change >= 0 ? .green : .orange)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background((change >= 0 ? Color.green : Color.orange).opacity(0.15))
                                .clipShape(Capsule())
                                .padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                        .background(themeManager.theme.primaryColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: themeManager.theme.accentGlow, radius: 16, x: 0, y: 6)

                        // Mini grafik
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nightly breakdown")
                                .font(.subheadline.bold())
                                .foregroundStyle(themeManager.theme.headingColor)
                            Chart(thisWeekEntries) { entry in
                                BarMark(
                                    x: .value("Date", entry.date, unit: .day),
                                    y: .value("Hours", Double(entry.durationInMinutes) / 60.0)
                                )
                                .foregroundStyle(themeManager.theme.primaryColor)
                                .cornerRadius(4)
                            }
                            .frame(height: 140)
                        }
                        .padding()
                        .background(themeManager.theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Best / Worst night
                        HStack(spacing: 12) {
                            if let best = bestNight {
                                nightCard(
                                    title: "Best night",
                                    icon: "star.fill",
                                    color: .green,
                                    entry: best
                                )
                            }
                            if let worst = worstNight {
                                nightCard(
                                    title: "Toughest night",
                                    icon: "cloud.rain.fill",
                                    color: .orange,
                                    entry: worst
                                )
                            }
                        }

                        // Habit highlight
                        if let habit = mostConsistentHabit {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.title2)
                                    .foregroundStyle(themeManager.theme.primaryColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Consistency win")
                                        .font(.caption.bold())
                                        .foregroundStyle(themeManager.theme.secondaryTextColor)
                                    Text("You \(habit.name) on \(habit.percentage)% of nights this week.")
                                        .font(.subheadline)
                                        .foregroundStyle(themeManager.theme.textColor)
                                }
                            }
                            .padding()
                            .background(themeManager.theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        if let focus = weeklyFocusMessage {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.forward.circle.fill")
                                        .foregroundStyle(themeManager.theme.primaryColor)
                                    Text("This week's focus")
                                        .font(.caption.bold())
                                        .foregroundStyle(themeManager.theme.secondaryTextColor)
                                }
                                Text(focus)
                                    .font(.subheadline)
                                    .foregroundStyle(themeManager.theme.textColor)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(themeManager.theme.primaryColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        Text("Nights logged: \(thisWeekEntries.count) / 7")
                            .font(.caption)
                            .foregroundStyle(themeManager.theme.mutedTextColor)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Weekly Report")
    }

    private func nightCard(title: String, icon: String, color: Color, entry: SleepEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(themeManager.theme.secondaryTextColor)
            }
            Text(entry.date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.subheadline.bold())
                .foregroundStyle(themeManager.theme.headingColor)
            Text("\(entry.durationInMinutes / 60)h \(entry.durationInMinutes % 60)m · \(entry.quality)/5")
                .font(.caption)
                .foregroundStyle(themeManager.theme.textColor)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func dateRangeText() -> String {
        let start = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) – \(formatter.string(from: Date()))"
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }
}

#Preview {
    NavigationStack {
        WeeklyReportView(entries: [])
            .environmentObject(ThemeManager())
    }
}
