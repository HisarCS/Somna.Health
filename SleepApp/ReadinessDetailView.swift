//
//  ReadinessDetailView.swift
//  SleepApp
//

import SwiftUI
import SwiftData

struct ReadinessDetailView: View {
    @Query(sort: \SleepEntry.date, order: .forward) private var entries: [SleepEntry]
    let result: HealthKitManager.ReadinessResult
    let coachingMessage: String
    let respiratoryRate: Double?

    private var isNightTime: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour >= 18
    }

    private var scoreColor: Color {
        Color(red: 0.4, green: 0.8, blue: 0.55)
    }

    private var statusLabel: String {
        switch result.score {
        case 80...100: return "Good"
        case 50..<80: return "Fair"
        default: return "Poor"
        }
    }

    private var backgroundImageName: String {
        isNightTime ? "readiness_bg_night" : "readiness_bg_day"
    }

    // MARK: - Trends renk paleti

    private var cardColor: Color {
        isNightTime ? Color(red: 0.28, green: 0.29, blue: 0.32) : Color(red: 0.35, green: 0.36, blue: 0.39)
    }
    private let orangeColor = Color(red: 0.95, green: 0.6, blue: 0.25)
    private let mintColor = Color(red: 0.408, green: 0.827, blue: 0.62)
    private let sparkGreen = Color(red: 0.5, green: 0.85, blue: 0.6)

    // MARK: - Durum yardimcilari (onceki kayitla karsilastirma)

    private enum Trend { case higher, lower, normal, noData }

    private func trend(current: Double?, history: [Double]) -> Trend {
        guard let current else { return .noData }
        guard let previous = history.dropLast().last else { return .normal }
        let threshold = abs(previous) * 0.05
        let diff = current - previous
        if diff > threshold { return .higher }
        if diff < -threshold { return .lower }
        return .normal
    }

    private func statusLabel(_ trend: Trend, lowerIsBetter: Bool = false) -> String {
        switch trend {
        case .higher: return lowerIsBetter ? "Above normal" : "Above normal"
        case .lower: return lowerIsBetter ? "Below normal" : "Below normal"
        case .normal: return "Normal range"
        case .noData: return "No data"
        }
    }

    private func statusColor(_ trend: Trend) -> Color {
        switch trend {
        case .higher, .lower: return orangeColor
        case .normal: return mintColor
        case .noData: return .white.opacity(0.3)
        }
    }

    private func statusIcon(_ trend: Trend) -> String {
        switch trend {
        case .higher: return "arrow.up"
        case .lower: return "arrow.down"
        case .normal: return "checkmark"
        case .noData: return ""
        }
    }

    // MARK: - Gecmis veri

    private var scoreHistorySpark: [Double] {
            entries.filter { $0.readinessScore > 0 }.suffix(7).map { Double($0.readinessScore) }
        }

    private var hrvHistorySpark: [Double] {
        entries.filter { $0.hrv > 0 }.suffix(7).map { $0.hrv }
    }

    private var rhrHistorySpark: [Double] {
        entries.filter { $0.restingHeartRate > 0 }.suffix(7).map { $0.restingHeartRate }
    }

    private var scoreTrendHistory: [MetricDataPoint] {
            entries.filter { $0.readinessScore > 0 }.map { MetricDataPoint(date: $0.date, value: Double($0.readinessScore)) }
        }

    private var hrvTrendHistory: [MetricDataPoint] {
        entries.filter { $0.hrv > 0 }.map { MetricDataPoint(date: $0.date, value: $0.hrv) }
    }

    private var rhrTrendHistory: [MetricDataPoint] {
        entries.filter { $0.restingHeartRate > 0 }.map { MetricDataPoint(date: $0.date, value: $0.restingHeartRate) }
    }

    private var respiratoryTrendHistory: [MetricDataPoint] {
        entries.filter { $0.respiratoryRate > 0 }.map { MetricDataPoint(date: $0.date, value: $0.respiratoryRate) }
    }

    private var respiratoryHistorySpark: [Double] {
        entries.filter { $0.respiratoryRate > 0 }.suffix(7).map { $0.respiratoryRate }
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
                                                                Color(red: 0.95, green: 0.98, blue: 0.2),
                                                                Color(red: 0.85, green: 0.95, blue: 0.18),
                                                                Color(red: 0.46, green: 0.84, blue: 0.17)
                                                            ],
                                                            center: .center,
                                                            startAngle: .degrees(0),
                                                            endAngle: .degrees(360)
                                                        ),
                                                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                                    )
                                                    .frame(width: 200, height: 200)
                                                    .rotationEffect(.degrees(-90))
                                                    .shadow(color: Color(red: 0.71, green: 0.84, blue: 0.29).opacity(0.5), radius: 8)
                                                    .animation(.easeOut(duration: 1.0), value: result.score)

                        VStack(spacing: 4) {
                            Text("READINESS")
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
                        statTile(icon: "waveform.path.ecg", label: "HRV", value: result.hrv.map { String(format: "%.0f ms", $0) } ?? "—")
                        statTile(icon: "heart.fill", label: "Resting HR", value: result.restingHeartRate.map { String(format: "%.0f bpm", $0) } ?? "—")
                    }
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
        .navigationTitle("Readiness")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Trends bolumu

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trends")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 8)

            let scoreTrend = trend(current: Double(result.score), history: scoreHistorySpark)
            NavigationLink {
                MetricTrendView(
                    metrics: [TrendMetric(title: "Recovery Score", unit: "%", color: sparkGreen, dataPoints: scoreTrendHistory, decimalPlaces: 0)],
                    isNightTime: isNightTime
                )
            } label: {
                trendCard(
                    icon: "leaf.fill", label: "Recovery Score",
                    value: "\(result.score)", unit: "%",
                    sparkline: scoreHistorySpark,
                    statusTrend: scoreTrend
                )
            }

            let hrvTrend = trend(current: result.hrv, history: hrvHistorySpark)
            NavigationLink {
                MetricTrendView(
                    metrics: [TrendMetric(title: "Resting HRV", unit: "ms", color: sparkGreen, dataPoints: hrvTrendHistory, decimalPlaces: 1)],
                    isNightTime: isNightTime
                )
            } label: {
                trendCard(
                    icon: "waveform.path.ecg", label: "Resting HRV",
                    value: result.hrv.map { String(format: "%.1f", $0) } ?? "No data", unit: "ms",
                    sparkline: hrvHistorySpark,
                    statusTrend: hrvTrend
                )
            }

            let rhrTrend = trend(current: result.restingHeartRate, history: rhrHistorySpark)
            NavigationLink {
                MetricTrendView(
                    metrics: [TrendMetric(title: "Resting HR", unit: "bpm", color: sparkGreen, dataPoints: rhrTrendHistory, decimalPlaces: 1)],
                    isNightTime: isNightTime
                )
            } label: {
                trendCard(
                    icon: "heart.fill", label: "Resting HR",
                    value: result.restingHeartRate.map { String(format: "%.1f", $0) } ?? "No data", unit: "bpm",
                    sparkline: rhrHistorySpark,
                    statusTrend: rhrTrend
                )
            }

            let respTrend = trend(current: respiratoryRate, history: respiratoryHistorySpark)
            NavigationLink {
                MetricTrendView(
                    metrics: [TrendMetric(title: "Respiratory Rate", unit: "rpm", color: sparkGreen, dataPoints: respiratoryTrendHistory, decimalPlaces: 1)],
                    isNightTime: isNightTime
                )
            } label: {
                trendCard(
                    icon: "lungs.fill", label: "Respiratory Rate",
                    value: respiratoryRate.map { String(format: "%.1f", $0) } ?? "No data", unit: "rpm",
                    sparkline: respiratoryHistorySpark,
                    statusTrend: respTrend
                )
            }
        }
    }

    private func trendCard(icon: String, label: String, value: String, unit: String?, sparkline: [Double], statusTrend: Trend) -> some View {
        let sColor = statusColor(statusTrend)

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

                if statusTrend != .noData {
                    HStack(spacing: 5) {
                        ZStack {
                            Circle().fill(sColor.opacity(0.2)).frame(width: 16, height: 16)
                            Image(systemName: statusIcon(statusTrend))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(sColor)
                        }
                        Text(statusLabel(statusTrend))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(sColor)
                    }
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
                sparklineView(sparkline, pointColor: sColor)
                    .frame(width: 92, height: 48)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 118)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func sparklineView(_ values: [Double], pointColor: Color) -> some View {
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
                    LinearGradient(colors: [sparkGreen.opacity(0.45), sparkGreen.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                )

                Path { path in
                    guard let first = normalized.first else { return }
                    path.move(to: first)
                    for pt in normalized.dropFirst() { path.addLine(to: pt) }
                }
                .stroke(sparkGreen.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

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
        ReadinessDetailView(
            result: .init(score: 82, hrv: 54.4, restingHeartRate: 58, isCalibrating: false),
            coachingMessage: "You're well recovered. A great day to push a little harder if you want to.",
            respiratoryRate: 14.5
        )
    }
}
