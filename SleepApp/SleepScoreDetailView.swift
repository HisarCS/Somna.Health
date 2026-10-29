//
//  SleepScoreDetailView.swift
//  SleepApp
//

import SwiftUI
import SwiftData

struct SleepScoreDetailView: View {
    @Query(sort: \SleepEntry.date, order: .forward) private var entries: [SleepEntry]
    let result: HealthKitManager.SleepScoreResult
    let coachingMessage: String
    let sleepStages: HealthKitManager.SleepStages?
    let bedTime: Date?
    let wakeTime: Date?

    private var isNightTime: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour >= 18
    }

    private var scoreColor: Color {
        switch result.score {
        case 80...100: return Color(red: 0.55, green: 0.85, blue: 0.35)
        case 50..<80: return Color(red: 0.95, green: 0.7, blue: 0.25)
        default: return Color(red: 0.95, green: 0.45, blue: 0.45)
        }
    }

    private var statusLabel: String {
        switch result.score {
        case 80...100: return "Good"
        case 50..<80: return "Fair"
        default: return "Poor"
        }
    }

    private var backgroundImageName: String {
        isNightTime ? "sleep_bg_night" : "sleep_bg_day"
    }

    // MARK: - Trends renk paleti

    private var cardColor: Color {
            isNightTime ? Color(red: 0.28, green: 0.29, blue: 0.32) : Color(red: 0.35, green: 0.36, blue: 0.39)
        }
    private let mintColor = Color(red: 0.408, green: 0.827, blue: 0.62)
    private let sparkBlue = Color(red: 0.5, green: 0.55, blue: 0.98)
    private let sparkPurple = Color(red: 0.7, green: 0.5, blue: 0.98)

    // MARK: - Gecmis veri

    private var scoreHistorySpark: [Double] {
            entries.filter { $0.sleepScore > 0 }.suffix(7).map { Double($0.sleepScore) }
        }

    private var timeAsleepHistorySpark: [Double] {
        entries.suffix(7).map { Double($0.durationInMinutes) }
    }

    private var remHistorySpark: [Double] {
        entries.filter { $0.remMinutes > 0 }.suffix(7).map { Double($0.remMinutes) }
    }

    private var deepHistorySpark: [Double] {
        entries.filter { $0.deepMinutes > 0 }.suffix(7).map { Double($0.deepMinutes) }
    }

    private var scoreTrendHistory: [MetricDataPoint] {
            entries.filter { $0.sleepScore > 0 }.map { MetricDataPoint(date: $0.date, value: Double($0.sleepScore)) }
        }

    private var timeAsleepTrendHistory: [MetricDataPoint] {
        entries.map { MetricDataPoint(date: $0.date, value: Double($0.durationInMinutes)) }
    }

    private var remTrendHistory: [MetricDataPoint] {
        entries.filter { $0.remMinutes > 0 }.map { MetricDataPoint(date: $0.date, value: Double($0.remMinutes)) }
    }

    private var deepTrendHistory: [MetricDataPoint] {
        entries.filter { $0.deepMinutes > 0 }.map { MetricDataPoint(date: $0.date, value: Double($0.deepMinutes)) }
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
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 10)
                            .frame(width: 200, height: 200)

                        Circle()
                                                    .trim(from: 0, to: CGFloat(result.score) / 100)
                                                    .stroke(
                                                        AngularGradient(
                                                            colors: [
                                                                Color(red: 0.72, green: 0.8, blue: 0.97),
                                                                Color(red: 0.57, green: 0.71, blue: 0.96),
                                                                Color(red: 0.47, green: 0.52, blue: 0.93),
                                                                Color(red: 0.36, green: 0.29, blue: 0.81),
                                                                Color(red: 0.31, green: 0.22, blue: 0.77)
                                                            ],
                                                            center: .center,
                                                            startAngle: .degrees(0),
                                                            endAngle: .degrees(360)
                                                        ),
                                                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                                    )
                                                    .frame(width: 200, height: 200)
                                                    .rotationEffect(.degrees(-90))
                                                    .shadow(color: Color(red: 0.36, green: 0.29, blue: 0.81).opacity(0.5), radius: 8)
                                                    .animation(.easeOut(duration: 1.0), value: result.score)

                        VStack(spacing: 4) {
                            Text("SLEEP SCORE")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.5)
                                .foregroundStyle(.white.opacity(0.5))
                            Text("\(result.score)")
                                .font(.system(size: 62, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                            Text(result.isCalibrating ? "Calibrating" : statusLabel)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(result.isCalibrating ? .white.opacity(0.6) : scoreColor)
                        }
                    }
                    .padding(.top, 20)

                    if result.isCalibrating {
                        HStack(spacing: 8) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                            Text("Learning your baseline — personalized scores start in a few days.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.horizontal)
                    }

                    HStack(spacing: 12) {
                        statTile(icon: "bed.double.fill", label: "Time in bed", value: formatMinutes(result.timeInBedMinutes))
                        statTile(icon: "moon.zzz.fill", label: "Time asleep", value: formatMinutes(result.timeAsleepMinutes))
                    }
                    .padding(.horizontal)

                    statTile(icon: "chart.bar.fill", label: "Efficiency", value: "\(result.efficiency)%")
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(scoreColor)
                            Text("Coaching")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                        Text(coachingMessage)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                    trendsSection
                        .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Trends bolumu

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trends")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 8)

            NavigationLink {
                MetricTrendView(
                    metrics: [TrendMetric(title: "Sleep Score", unit: "%", color: sparkPurple, dataPoints: scoreTrendHistory, decimalPlaces: 0)],
                    isNightTime: isNightTime
                )
            } label: {
                trendCard(
                    icon: "zzz", label: "Sleep Score",
                    value: "\(result.score)", unit: "%",
                    sparkline: scoreHistorySpark,
                    sparkColorA: sparkPurple, sparkColorB: sparkBlue
                )
            }

            NavigationLink {
                MetricTrendView(
                    metrics: [TrendMetric(title: "Time Asleep", unit: "min", color: sparkBlue, dataPoints: timeAsleepTrendHistory, decimalPlaces: 0)],
                    isNightTime: isNightTime
                )
            } label: {
                trendCard(
                    icon: "clock.fill", label: "Time Asleep",
                    value: formatMinutes(result.timeAsleepMinutes), unit: nil,
                    sparkline: timeAsleepHistorySpark,
                    sparkColorA: sparkBlue, sparkColorB: sparkPurple
                )
            }

            NavigationLink {
                MetricTrendView(
                    metrics: [TrendMetric(title: "REM Sleep", unit: "min", color: sparkPurple, dataPoints: remTrendHistory, decimalPlaces: 0)],
                    isNightTime: isNightTime
                )
            } label: {
                trendCard(
                    icon: "moon.fill", label: "REM Sleep",
                    value: sleepStages.map { formatMinutes($0.remMinutes) } ?? "No data", unit: nil,
                    sparkline: remHistorySpark,
                    sparkColorA: sparkBlue, sparkColorB: sparkPurple
                )
            }

            NavigationLink {
                MetricTrendView(
                    metrics: [TrendMetric(title: "Deep Sleep", unit: "min", color: sparkBlue, dataPoints: deepTrendHistory, decimalPlaces: 0)],
                    isNightTime: isNightTime
                )
            } label: {
                trendCard(
                    icon: "moon.zzz.fill", label: "Deep Sleep",
                    value: sleepStages.map { formatMinutes($0.deepMinutes) } ?? "No data", unit: nil,
                    sparkline: deepHistorySpark,
                    sparkColorA: sparkBlue, sparkColorB: sparkPurple
                )
            }

            trendCard(
                icon: "bed.double.fill", label: "Sleep Time",
                value: bedTime.map { formatTime($0) } ?? "No data", unit: nil,
                sparkline: [],
                sparkColorA: sparkBlue, sparkColorB: sparkPurple
            )

            trendCard(
                icon: "sunrise.fill", label: "Wake Time",
                value: wakeTime.map { formatTime($0) } ?? "No data", unit: nil,
                sparkline: [],
                sparkColorA: sparkPurple, sparkColorB: sparkBlue
            )
        }
    }

    private func trendCard(icon: String, label: String, value: String, unit: String?, sparkline: [Double], sparkColorA: Color, sparkColorB: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.45))
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }

                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if let unit {
                        Text(unit)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                HStack(spacing: 5) {
                    ZStack {
                        Circle().fill(mintColor.opacity(0.2)).frame(width: 16, height: 16)
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(mintColor)
                    }
                    Text("Normal range")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(mintColor)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 0) {
                if !sparkline.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                }
                Spacer()
                sparklineView(sparkline, colorA: sparkColorA, colorB: sparkColorB)
                    .frame(width: 92, height: 48)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 118)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func sparklineView(_ values: [Double], colorA: Color, colorB: Color) -> some View {
        let points = values.isEmpty ? [0.4, 0.5, 0.45, 0.6, 0.55, 0.7, 0.65] : values
        let minVal = points.min() ?? 0
        let maxVal = points.max() ?? 1
        let range = max(maxVal - minVal, 0.001)

        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let stepX = w / CGFloat(max(points.count - 1, 1))

            let normalized = points.enumerated().map { i, v -> CGPoint in
                let x = CGFloat(i) * stepX
                let y = h - CGFloat((v - minVal) / range) * h
                return CGPoint(x: x, y: y)
            }

            ZStack {
                Path { path in
                    guard let first = normalized.first else { return }
                    path.move(to: CGPoint(x: first.x, y: h))
                    path.addLine(to: first)
                    for pt in normalized.dropFirst() { path.addLine(to: pt) }
                    path.addLine(to: CGPoint(x: normalized.last?.x ?? w, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(colors: [colorA.opacity(0.45), colorB.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                )

                Path { path in
                    guard let first = normalized.first else { return }
                    path.move(to: first)
                    for pt in normalized.dropFirst() { path.addLine(to: pt) }
                }
                .stroke(colorA.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                if let last = normalized.last {
                    Circle()
                        .fill(cardColor)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(colorB, lineWidth: 2))
                        .shadow(color: colorB.opacity(0.7), radius: 5)
                        .position(last)
                }
            }
        }
    }

    private func statTile(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        SleepScoreDetailView(
            result: .init(score: 88, timeInBedMinutes: 488, timeAsleepMinutes: 488, efficiency: 94, isCalibrating: false),
            coachingMessage: "Great night. Your duration and efficiency were both strong.",
            sleepStages: .init(remMinutes: 141, deepMinutes: 59, coreMinutes: 240, awakeMinutes: 12),
            bedTime: Date(),
            wakeTime: Date()
        )
    }
}
