//
//  TrendView.swift
//  SleepApp
//

import SwiftUI
import SwiftData
import Charts

enum TrendRange: String, CaseIterable {
    case week = "7 Days"
    case month = "30 Days"

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        }
    }
}

struct TrendView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Query(sort: \SleepEntry.date, order: .forward) private var entries: [SleepEntry]

    @State private var selectedRange: TrendRange = .week
    @State private var selectedEntry: SleepEntry? = nil

    private var filteredEntries: [SleepEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedRange.days, to: Date()) ?? Date()
        let filtered = entries.filter { $0.date >= cutoff }

        var latestPerDay: [Date: SleepEntry] = [:]
        for entry in filtered {
            let dayKey = Calendar.current.startOfDay(for: entry.date)
            if let existing = latestPerDay[dayKey] {
                if entry.date > existing.date {
                    latestPerDay[dayKey] = entry
                }
            } else {
                latestPerDay[dayKey] = entry
            }
        }
        return latestPerDay.values.sorted { $0.date < $1.date }
    }

    private var averageDurationMinutes: Int {
        guard !filteredEntries.isEmpty else { return 0 }
        let total = filteredEntries.reduce(0) { $0 + $1.durationInMinutes }
        return total / filteredEntries.count
    }

    private var averageQuality: Double {
        guard !filteredEntries.isEmpty else { return 0 }
        let total = filteredEntries.reduce(0) { $0 + $1.quality }
        return Double(total) / Double(filteredEntries.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.theme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Picker("Range", selection: $selectedRange) {
                            ForEach(TrendRange.allCases, id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedRange) {
                            selectedEntry = nil
                        }

                        if entries.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "chart.bar")
                                    .font(.system(size: 40))
                                    .foregroundStyle(themeManager.theme.mutedTextColor)
                                Text("No data yet")
                                    .font(.headline)
                                    .foregroundStyle(themeManager.theme.headingColor)
                                Text("Log your sleep on the Today tab to see trends here.")
                                    .font(.subheadline)
                                    .foregroundStyle(themeManager.theme.secondaryTextColor)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            HStack(spacing: 12) {
                                summaryCard(
                                    title: "Avg Sleep",
                                    value: formatDuration(averageDurationMinutes)
                                )
                                summaryCard(
                                    title: "Avg Quality",
                                    value: String(format: "%.1f / 5", averageQuality)
                                )
                            }

                            if let entry = selectedEntry {
                                dayDetailCard(entry)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Sleep Duration — \(selectedRange.rawValue)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(themeManager.theme.headingColor)
                                Text("Tap a bar to see that day's details")
                                    .font(.caption2)
                                    .foregroundStyle(themeManager.theme.mutedTextColor)

                                Chart(filteredEntries) { entry in
                                    BarMark(
                                        x: .value("Date", entry.date, unit: .day),
                                        y: .value("Hours", Double(entry.durationInMinutes) / 60.0)
                                    )
                                    .foregroundStyle(
                                        selectedEntry?.id == entry.id
                                            ? themeManager.theme.primaryColor
                                            : themeManager.theme.primaryColor.opacity(0.6)
                                    )
                                }
                                .frame(height: 200)
                                .chartXAxis {
                                    AxisMarks { _ in
                                        AxisValueLabel()
                                            .foregroundStyle(themeManager.theme.secondaryTextColor)
                                        AxisGridLine()
                                            .foregroundStyle(themeManager.theme.mutedTextColor.opacity(0.3))
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks { _ in
                                        AxisValueLabel()
                                            .foregroundStyle(themeManager.theme.secondaryTextColor)
                                        AxisGridLine()
                                            .foregroundStyle(themeManager.theme.mutedTextColor.opacity(0.3))
                                    }
                                }
                                .chartOverlay { proxy in
                                    GeometryReader { geo in
                                        Rectangle()
                                            .fill(Color.clear)
                                            .contentShape(Rectangle())
                                            .gesture(
                                                DragGesture(minimumDistance: 0)
                                                    .onChanged { value in
                                                        handleTap(at: value.location, proxy: proxy, geo: geo)
                                                    }
                                            )
                                    }
                                }
                            }
                            .padding()
                            .background(themeManager.theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Sleep Quality — \(selectedRange.rawValue)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(themeManager.theme.headingColor)
                                Chart(filteredEntries) { entry in
                                    LineMark(
                                        x: .value("Date", entry.date, unit: .day),
                                        y: .value("Quality", entry.quality)
                                    )
                                    .foregroundStyle(themeManager.theme.secondaryColor)
                                    .symbol(.circle)
                                }
                                .chartYScale(domain: 0...5)
                                .frame(height: 200)
                                .chartXAxis {
                                    AxisMarks { _ in
                                        AxisValueLabel()
                                            .foregroundStyle(themeManager.theme.secondaryTextColor)
                                        AxisGridLine()
                                            .foregroundStyle(themeManager.theme.mutedTextColor.opacity(0.3))
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks { _ in
                                        AxisValueLabel()
                                            .foregroundStyle(themeManager.theme.secondaryTextColor)
                                        AxisGridLine()
                                            .foregroundStyle(themeManager.theme.mutedTextColor.opacity(0.3))
                                    }
                                }
                            }
                            .padding()
                            .background(themeManager.theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Trend")
        }
        .onAppear {
            themeManager.refresh()
        }
    }

    private func handleTap(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        let plotFrame = proxy.plotFrame.map { geo[$0] } ?? .zero
        let xPosition = location.x - plotFrame.origin.x

        guard let date: Date = proxy.value(atX: xPosition) else { return }

        let closest = filteredEntries.min { a, b in
            abs(a.date.timeIntervalSince(date)) < abs(b.date.timeIntervalSince(date))
        }

        if let closest, let selected = selectedEntry, selected.id == closest.id {
            withAnimation { selectedEntry = nil }
        } else {
            withAnimation { selectedEntry = closest }
        }
    }

    private func dayDetailCard(_ entry: SleepEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entry.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.subheadline.bold())
                    .foregroundStyle(themeManager.theme.headingColor)
                Spacer()
                Button {
                    withAnimation { selectedEntry = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(themeManager.theme.mutedTextColor)
                }
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Duration")
                        .font(.caption2)
                        .foregroundStyle(themeManager.theme.secondaryTextColor)
                    Text("\(entry.durationInMinutes / 60)h \(entry.durationInMinutes % 60)m")
                        .font(.subheadline.bold())
                        .foregroundStyle(themeManager.theme.textColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quality")
                        .font(.caption2)
                        .foregroundStyle(themeManager.theme.secondaryTextColor)
                    Text("\(entry.quality)/5")
                        .font(.subheadline.bold())
                        .foregroundStyle(themeManager.theme.textColor)
                }
            }

            HStack(spacing: 8) {
                habitBadge(icon: "cup.and.saucer.fill", active: entry.hadCaffeine, label: "Caffeine")
                habitBadge(icon: "iphone", active: entry.hadScreenBeforeBed, label: "Screen")
                habitBadge(icon: "figure.run", active: entry.didExercise, label: "Exercise")
                habitBadge(icon: "wineglass.fill", active: entry.hadAlcohol, label: "Alcohol")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.theme.primaryColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .transition(.scale.combined(with: .opacity))
    }

    private func habitBadge(icon: String, active: Bool, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(label)
        }
        .font(.caption2.bold())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(active ? themeManager.theme.primaryColor.opacity(0.3) : themeManager.theme.mutedTextColor.opacity(0.15))
        .foregroundStyle(active ? themeManager.theme.primaryColor : themeManager.theme.mutedTextColor)
        .clipShape(Capsule())
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(themeManager.theme.textColor)
            Text(title)
                .font(.caption)
                .foregroundStyle(themeManager.theme.secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(themeManager.theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }
}

#Preview {
    TrendView()
        .environmentObject(ThemeManager())
        .modelContainer(for: [SleepEntry.self, UserProfile.self], inMemory: true)
}
