//
//  StressTrendsView.swift
//  SleepApp
//

import SwiftUI
import SwiftData
import Charts

struct StressTrendsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Query(sort: \SleepEntry.date, order: .forward) private var entries: [SleepEntry]
    let result: HealthKitManager.StressResult
    let heartRate: Double?
    let lastUpdate: Date?
    let todayHistory: [HealthKitManager.HourlyStressPoint]

    @State private var selectedPoint: HealthKitManager.HourlyStressPoint?

    private var isNightTime: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour >= 18
    }

    private var backgroundImageName: String {
        isNightTime ? "stress_bg_night" : "stress_bg_day"
    }

    private var color: Color {
            switch displayedScore {
            case 0..<20: return Color(red: 0.55, green: 0.85, blue: 0.35)
            case 20..<50: return Color(red: 0.95, green: 0.7, blue: 0.25)
            default: return Color(red: 0.95, green: 0.45, blue: 0.45)
            }
        }

    private var statusLabel: String {
            switch displayedScore {
            case 0..<20: return "Low"
            case 20..<50: return "Moderate"
            default: return "High"
            }
        }

    private var lastUpdateText: String {
        guard let date = lastUpdate else { return "No data" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var hrvHistory: [MetricDataPoint] {
        entries.filter { $0.hrv > 0 }.map { MetricDataPoint(date: $0.date, value: $0.hrv) }
    }
    private var displayedScore: Int {
            todayHistory.last?.score ?? result.score
        }

    private var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var endOfToday: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) ?? Date()
    }

    private var fixedHourMarks: [Date] {
        let calendar = Calendar.current
        return [0, 6, 12, 18].compactMap { hour in
            calendar.date(bySettingHour: hour, minute: 0, second: 0, of: startOfToday)
        }
    }

    private func interpolatedPoint(at date: Date) -> HealthKitManager.HourlyStressPoint? {
        guard !todayHistory.isEmpty else { return nil }

        if let exact = todayHistory.first(where: { abs($0.time.timeIntervalSince(date)) < 60 }) {
            return exact
        }

        guard let before = todayHistory.last(where: { $0.time <= date }),
              let after = todayHistory.first(where: { $0.time > date }) else {
            return todayHistory.min(by: { abs($0.time.timeIntervalSince(date)) < abs($1.time.timeIntervalSince(date)) })
        }

        let totalInterval = after.time.timeIntervalSince(before.time)
        guard totalInterval > 0 else { return before }

        let progress = date.timeIntervalSince(before.time) / totalInterval
        let interpolatedScore = Int(Double(before.score) + (Double(after.score - before.score) * progress))

        return HealthKitManager.HourlyStressPoint(time: date, score: interpolatedScore)
    }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                Image(backgroundImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if result.isCalibrating {
                        HStack(spacing: 10) {
                            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.85))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Getting to know you")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                Text("A few more nights and stress readings will be tailored to you.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    scoreCircle

                    HStack(spacing: 12) {
                        metricCard(icon: "waveform.path.ecg", label: "HRV", value: result.hrv.map { String(format: "%.0f ms", $0) } ?? "No data")
                        metricCard(icon: "heart.fill", label: "Heart Rate", value: heartRate.map { String(format: "%.0f bpm", $0) } ?? "No data")
                    }

                    todaysStressCard

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(color)
                            Text("What this means")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                        Text(explanation)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding()
                .padding(.top, 8)
            }
        }
        .navigationTitle("Stress Trends")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Skor dairesi

    private var scoreCircle: some View {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 10)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: CGFloat(displayedScore) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0), value: displayedScore)

                VStack(spacing: 4) {
                    Text("STRESS")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("\(displayedScore)")
                        .font(.system(size: 48, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                    Text(result.isCalibrating ? "Calibrating" : statusLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(result.isCalibrating ? .white.opacity(0.6) : color)
                }
            }
            .padding(.top, 8)
        }
    // MARK: - Today's Stress line graph

    @ViewBuilder
    private var todaysStressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's stress")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.7))

            if todayHistory.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Your stress graph fills in as the day goes on.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 20)
            } else {
                Chart {
                    ForEach(todayHistory, id: \.time) { point in
                        LineMark(
                            x: .value("Time", point.time),
                            y: .value("Stress", point.score)
                        )
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Time", point.time),
                            y: .value("Stress", point.score)
                        )
                        .foregroundStyle(
                            LinearGradient(colors: [color.opacity(0.3), color.opacity(0)], startPoint: .top, endPoint: .bottom)
                        )
                        .interpolationMethod(.catmullRom)
                    }

                    if let selected = selectedPoint {
                        RuleMark(x: .value("Time", selected.time))
                            .foregroundStyle(.white.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                        PointMark(
                            x: .value("Time", selected.time),
                            y: .value("Stress", selected.score)
                        )
                        .foregroundStyle(color)
                        .symbolSize(100)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXScale(domain: startOfToday...endOfToday)
                .chartXAxis {
                    AxisMarks(values: fixedHourMarks) { value in
                        AxisGridLine().foregroundStyle(.white.opacity(0.1))
                        AxisValueLabel(format: .dateTime.hour())
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.system(size: 10))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine().foregroundStyle(.white.opacity(0.1))
                        AxisValueLabel()
                            .foregroundStyle(.white.opacity(0.4))
                            .font(.system(size: 10))
                    }
                }
                .frame(height: 160)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(Color.clear).contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let location = value.location
                                        if let date: Date = proxy.value(atX: location.x) {
                                            selectedPoint = interpolatedPoint(at: date)
                                        }
                                    }
                                    .onEnded { _ in
                                        selectedPoint = nil
                                    }
                            )
                    }
                }

                if let selected = selectedPoint {
                    HStack {
                        Text(selected.time, format: .dateTime.hour().minute())
                            .font(.caption.bold())
                        Spacer()
                        Text("\(selected.score)")
                            .font(.caption.bold())
                            .foregroundStyle(color)
                    }
                    .foregroundStyle(.white)
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var explanation: String {
        switch result.score {
        case 0..<20:
            return "Your nervous system looks relaxed. HRV and heart rate both point to good recovery."
        case 20..<50:
            return "A fairly typical state. Nothing stands out as concerning right now."
        default:
            return "Your body may be under more strain than usual. Rest, hydration, and slow breathing can help."
        }
    }

    private func metricCard(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text("Updated \(lastUpdateText)")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    NavigationStack {
        StressTrendsView(
            result: .init(score: 35, hrv: 62, isCalibrating: false),
            heartRate: 78,
            lastUpdate: Date(),
            todayHistory: [
                .init(time: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!, score: 20),
                .init(time: Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date())!, score: 35),
                .init(time: Calendar.current.date(bySettingHour: 16, minute: 0, second: 0, of: Date())!, score: 42)
            ]
        )
        .environmentObject(ThemeManager())
    }
}
