//
//  StrainDetailView.swift
//  SleepApp
//

import SwiftUI
import SwiftData

struct StrainDetailView: View {
    @Query(sort: \SleepEntry.date, order: .forward) private var entries: [SleepEntry]
    let result: HealthKitManager.StrainResult
    let stepCount: Double?

    private var isNightTime: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour >= 18
    }

    private var backgroundImageName: String {
        isNightTime ? "stress_bg_night" : "stress_bg_day"
    }

    private var scoreColor: Color {
        switch result.score {
        case 0..<10: return Color(red: 0.4, green: 0.6, blue: 0.95)
        case 10..<16: return Color(red: 0.95, green: 0.7, blue: 0.25)
        default: return Color(red: 0.95, green: 0.45, blue: 0.45)
        }
    }

    private var statusLabel: String {
        switch result.score {
        case 0..<10: return "Light"
        case 10..<16: return "Moderate"
        default: return "High"
        }
    }

    private var coachingMessage: String {
        switch result.score {
        case 0..<10:
            return "A light day so far. Room for more activity if you're feeling up for it."
        case 10..<16:
            return "A solid, moderate day of exertion. Balanced for most recovery levels."
        default:
            return "A demanding day. Make sure you're refueling and prioritizing rest tonight."
        }
    }

    // MARK: - Trends renk paleti

    private var cardColor: Color {
        isNightTime ? Color(red: 0.28, green: 0.29, blue: 0.32) : Color(red: 0.35, green: 0.36, blue: 0.39)
    }
    private let mintColor = Color(red: 0.408, green: 0.827, blue: 0.62)
    private let orangeColor = Color(red: 0.95, green: 0.6, blue: 0.2)
    private let yellowColor = Color(red: 0.95, green: 0.78, blue: 0.25)

    // MARK: - Durum yardimcilari

    private enum Trend { case normal, belowNormal, noData }

    private func trend(current: Double?, history: [Double]) -> Trend {
        guard let current else { return .noData }
        guard let previous = history.dropLast().last else { return .normal }
        let threshold = abs(previous) * 0.2
        if current < previous - threshold { return .belowNormal }
        return .normal
    }

    // MARK: - Gecmis veri (sparkline icin)

    private var strainHistorySpark: [Double] {
            entries.filter { $0.strainScore > 0 }.suffix(7).map { $0.strainScore }
        }

        private var stepHistorySpark: [Double] {
            entries.filter { $0.stepCount > 0 }.suffix(7).map { $0.stepCount }
        }

        private var strainTrendHistory: [MetricDataPoint] {
            entries.filter { $0.strainScore > 0 }.map { MetricDataPoint(date: $0.date, value: $0.strainScore) }
        }

        private var stepTrendHistory: [MetricDataPoint] {
            entries.filter { $0.stepCount > 0 }.map { MetricDataPoint(date: $0.date, value: $0.stepCount) }
        }
    private var exerciseHistorySpark: [Double] {
            entries.filter { $0.exerciseMinutes > 0 }.suffix(7).map { $0.exerciseMinutes }
        }

        private var heartRateHistorySpark: [Double] {
            entries.filter { $0.avgHeartRate > 0 }.suffix(7).map { $0.avgHeartRate }
        }

        private var energyHistorySpark: [Double] {
            entries.filter { $0.activeEnergy > 0 }.suffix(7).map { $0.activeEnergy }
        }

        private var exerciseTrendHistory: [MetricDataPoint] {
            entries.filter { $0.exerciseMinutes > 0 }.map { MetricDataPoint(date: $0.date, value: $0.exerciseMinutes) }
        }

        private var heartRateTrendHistory: [MetricDataPoint] {
            entries.filter { $0.avgHeartRate > 0 }.map { MetricDataPoint(date: $0.date, value: $0.avgHeartRate) }
        }

        private var energyTrendHistory: [MetricDataPoint] {
            entries.filter { $0.activeEnergy > 0 }.map { MetricDataPoint(date: $0.date, value: $0.activeEnergy) }
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
                                                    .trim(from: 0, to: CGFloat(result.score) / 21.0)
                                                    .stroke(
                                                        AngularGradient(
                                                            colors: [
                                                                Color(red: 1.0, green: 0.83, blue: 0.15),
                                                                Color(red: 1.0, green: 0.62, blue: 0.18),
                                                                Color(red: 1.0, green: 0.42, blue: 0.21),
                                                                Color(red: 0.94, green: 0.27, blue: 0.24)
                                                            ],
                                                            center: .center,
                                                            startAngle: .degrees(0),
                                                            endAngle: .degrees(360)
                                                        ),
                                                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                                    )
                                                    .frame(width: 200, height: 200)
                                                    .rotationEffect(.degrees(-90))
                                                    .shadow(color: Color(red: 1.0, green: 0.42, blue: 0.21).opacity(0.5), radius: 8)
                                                    .animation(.easeOut(duration: 1.0), value: result.score)

                        VStack(spacing: 4) {
                            Text("STRAIN")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.5)
                                .foregroundStyle(.white.opacity(0.5))
                            Text(String(format: "%.1f", result.score))
                                .font(.system(size: 62, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                            Text(statusLabel)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(scoreColor)
                        }
                    }
                    .padding(.top, 20)

                    HStack(spacing: 12) {
                        statTile(icon: "flame.fill", label: "Active energy", value: result.activeEnergy.map { String(format: "%.0f kcal", $0) } ?? "—")
                        statTile(icon: "figure.run", label: "Exercise time", value: result.exerciseMinutes.map { String(format: "%.0f min", $0) } ?? "—")
                    }
                    .padding(.horizontal)

                    statTile(icon: "heart.fill", label: "Avg heart rate today", value: result.averageHeartRate.map { String(format: "%.0f bpm", $0) } ?? "—")
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
        .navigationTitle("Strain")
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
                    metrics: [TrendMetric(title: "Strain Score", unit: "", color: yellowColor, dataPoints: strainTrendHistory, decimalPlaces: 1)],
                    isNightTime: isNightTime
                )
            } label: {
                trendCard(
                    icon: "bolt.fill", label: "Strain Score",
                    value: String(format: "%.0f", result.score), unit: "%",
                    sparkline: strainHistorySpark, sparkColor: yellowColor,
                    trend: .normal
                )
            }

            NavigationLink {
                            MetricTrendView(
                                metrics: [TrendMetric(title: "Exercise Duration", unit: "min", color: orangeColor, dataPoints: exerciseTrendHistory, decimalPlaces: 0)],
                                isNightTime: isNightTime
                            )
                        } label: {
                            trendCard(
                                icon: "stopwatch.fill", label: "Exercise Duration",
                                value: result.exerciseMinutes.map { String(format: "%.0f", $0) } ?? "0", unit: "m",
                                sparkline: exerciseHistorySpark, sparkColor: orangeColor,
                                trend: .normal
                            )
                        }

                        NavigationLink {
                            MetricTrendView(
                                metrics: [TrendMetric(title: "Daytime HR", unit: "bpm", color: orangeColor, dataPoints: heartRateTrendHistory, decimalPlaces: 0)],
                                isNightTime: isNightTime
                            )
                        } label: {
                            trendCard(
                                icon: "heart.fill", label: "Daytime HR",
                                value: result.averageHeartRate.map { String(format: "%.0f", $0) } ?? "—", unit: "bpm",
                                sparkline: heartRateHistorySpark, sparkColor: orangeColor,
                                trend: .normal
                            )
                        }

                        NavigationLink {
                            MetricTrendView(
                                metrics: [TrendMetric(title: "Total Energy", unit: "kcal", color: orangeColor, dataPoints: energyTrendHistory, decimalPlaces: 0)],
                                isNightTime: isNightTime
                            )
                        } label: {
                            trendCard(
                                icon: "flame.fill", label: "Total Energy",
                                value: result.activeEnergy.map { String(format: "%.0f", $0) } ?? "0", unit: "kcal",
                                sparkline: energyHistorySpark, sparkColor: orangeColor,
                                trend: .normal
                            )
                        }

            let stepTrend = trend(current: stepCount, history: stepHistorySpark)
            NavigationLink {
                MetricTrendView(
                    metrics: [TrendMetric(title: "Step Count", unit: "", color: orangeColor, dataPoints: stepTrendHistory, decimalPlaces: 0)],
                    isNightTime: isNightTime
                )
            } label: {
                trendCard(
                    icon: "figure.walk", label: "Step Count",
                    value: stepCount.map { String(format: "%.0f", $0) } ?? "0", unit: nil,
                    sparkline: stepHistorySpark, sparkColor: orangeColor,
                    trend: stepTrend
                )
            }
        }
    }

    private func trendCard(icon: String, label: String, value: String, unit: String?, sparkline: [Double], sparkColor: Color, trend: Trend) -> some View {
        let statusColor = trend == .belowNormal ? orangeColor : mintColor
        let statusText = trend == .belowNormal ? "Below normal" : "Normal range"
        let statusIcon = trend == .belowNormal ? "arrow.down" : "checkmark"

        return HStack(alignment: .top, spacing: 12) {
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

                if trend != .noData {
                    HStack(spacing: 5) {
                        ZStack {
                            Circle().fill(statusColor.opacity(0.2)).frame(width: 16, height: 16)
                            Image(systemName: statusIcon)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(statusColor)
                        }
                        Text(statusText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(statusColor)
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 0) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
                Spacer()
                sparklineView(sparkline, sparkColor: sparkColor, pointColor: statusColor)
                    .frame(width: 92, height: 48)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 118)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func sparklineView(_ values: [Double], sparkColor: Color, pointColor: Color) -> some View {
        let points = values.isEmpty ? [0.2, 0.2, 0.25, 0.2, 0.8, 0.3, 0.15] : values
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
                    LinearGradient(colors: [sparkColor.opacity(0.4), sparkColor.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                )

                Path { path in
                    guard let first = normalized.first else { return }
                    path.move(to: first)
                    for pt in normalized.dropFirst() { path.addLine(to: pt) }
                }
                .stroke(sparkColor.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                if let last = normalized.last {
                    Circle()
                        .fill(cardColor)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(pointColor, lineWidth: 2))
                        .shadow(color: pointColor.opacity(0.7), radius: 5)
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
}

#Preview {
    NavigationStack {
        StrainDetailView(
            result: .init(score: 6.4, activeEnergy: 848, exerciseMinutes: 0, averageHeartRate: 61),
            stepCount: 162
        )
    }
}
