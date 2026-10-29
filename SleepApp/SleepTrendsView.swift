//
//  SleepTrendsView.swift
//  SleepApp
//

import SwiftUI
import SwiftData

struct SleepTrendsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Query(sort: \SleepEntry.date, order: .forward) private var entries: [SleepEntry]
    let scoreResult: HealthKitManager.SleepScoreResult
    let hrv: Double?
    let restingHeartRate: Double?
    let respiratoryRate: Double?
    let bodyTempDelta: Double?
    let sleepStages: HealthKitManager.SleepStages?
    let bedTime: Date?
    let wakeTime: Date?

    private var isNightTime: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour >= 18
    }

    private var skyBackground: LinearGradient {
        LinearGradient(
            colors: isNightTime
                ? [
                    Color(red: 0.05, green: 0.04, blue: 0.13),
                    Color(red: 0.11, green: 0.08, blue: 0.22),
                    Color(red: 0.16, green: 0.11, blue: 0.27)
                  ]
                : [
                    Color(red: 0.45, green: 0.68, blue: 0.93),
                    Color(red: 0.62, green: 0.81, blue: 0.97),
                    Color(red: 0.82, green: 0.9, blue: 0.98)
                  ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var hrvHistory: [MetricDataPoint] {
        entries.filter { $0.hrv > 0 }.map { MetricDataPoint(date: $0.date, value: $0.hrv) }
    }

    private var rhrHistory: [MetricDataPoint] {
        entries.filter { $0.restingHeartRate > 0 }.map { MetricDataPoint(date: $0.date, value: $0.restingHeartRate) }
    }

    private var remHistory: [MetricDataPoint] {
        entries.filter { $0.remMinutes > 0 }.map { MetricDataPoint(date: $0.date, value: Double($0.remMinutes)) }
    }

    private var deepHistory: [MetricDataPoint] {
        entries.filter { $0.deepMinutes > 0 }.map { MetricDataPoint(date: $0.date, value: Double($0.deepMinutes)) }
    }

    private var respiratoryHistory: [MetricDataPoint] {
        entries.filter { $0.respiratoryRate > 0 }.map { MetricDataPoint(date: $0.date, value: $0.respiratoryRate) }
    }

    private var bodyTempHistory: [MetricDataPoint] {
        entries.filter { $0.bodyTempDelta != 0 }.map { MetricDataPoint(date: $0.date, value: $0.bodyTempDelta) }
    }
    
    private var allMetrics: [TrendMetric] {
            [
                TrendMetric(title: "REM Sleep", unit: "min", color: Color(red: 0.6, green: 0.6, blue: 0.95), dataPoints: remHistory, decimalPlaces: 0),
                TrendMetric(title: "Deep Sleep", unit: "min", color: Color(red: 0.5, green: 0.55, blue: 0.9), dataPoints: deepHistory, decimalPlaces: 0),
                TrendMetric(title: "HRV", unit: "ms", color: Color(red: 0.65, green: 0.55, blue: 0.95), dataPoints: hrvHistory, decimalPlaces: 1),
                TrendMetric(title: "Resting HR", unit: "bpm", color: Color(red: 0.95, green: 0.5, blue: 0.55), dataPoints: rhrHistory, decimalPlaces: 1),
                TrendMetric(title: "Respiratory Rate", unit: "br/min", color: Color(red: 0.5, green: 0.8, blue: 0.85), dataPoints: respiratoryHistory, decimalPlaces: 1),
                TrendMetric(title: "Body Temperature", unit: "°C", color: Color(red: 0.95, green: 0.65, blue: 0.4), dataPoints: bodyTempHistory, decimalPlaces: 1)
            ]
        }

    var body: some View {
        ZStack {
            skyBackground
                .ignoresSafeArea()

            celestialLayer
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if scoreResult.isCalibrating {
                        HStack(spacing: 10) {
                            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.85))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Getting to know you")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                Text("A few more nights and these numbers will be tailored just to you.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    sleepScoreTrendCard

                    HStack(spacing: 12) {
                        metricCard(icon: "bed.double.fill", label: "Time in bed", value: formatMinutes(scoreResult.timeInBedMinutes))
                        metricCard(icon: "moon.zzz.fill", label: "Time asleep", value: formatMinutes(scoreResult.timeAsleepMinutes))
                    }

                    metricCard(icon: "chart.bar.fill", label: "Efficiency", value: "\(scoreResult.efficiency)%", fullWidth: true)

                    NavigationLink {
                                            MetricTrendView(metrics: allMetrics, initialIndex: 0, isNightTime: isNightTime)
                                        } label: {
                                            trendCard(
                                                icon: "moon.fill",
                                                iconColor: Color(red: 0.6, green: 0.6, blue: 0.95),
                                                title: "REM Sleep",
                                                value: sleepStages.map { formatMinutes($0.remMinutes) },
                                                unit: nil,
                                                status: sleepStages != nil ? .normal("Tracked") : .noData("Still snoozing on this one")
                                            )
                                        }

                                        NavigationLink {
                                            MetricTrendView(metrics: allMetrics, initialIndex: 1, isNightTime: isNightTime)
                                        } label: {
                                            trendCard(
                                                icon: "moon.zzz.fill",
                                                iconColor: Color(red: 0.5, green: 0.55, blue: 0.9),
                                                title: "Deep Sleep",
                                                value: sleepStages.map { formatMinutes($0.deepMinutes) },
                                                unit: nil,
                                                status: sleepStages != nil ? .normal("Tracked") : .noData("Coming soon")
                                            )
                                        }

                                        NavigationLink {
                                            MetricTrendView(metrics: allMetrics, initialIndex: 2, isNightTime: isNightTime)
                                        } label: {
                                            trendCard(
                                                icon: "waveform.path.ecg",
                                                iconColor: Color(red: 0.65, green: 0.55, blue: 0.95),
                                                title: "HRV",
                                                value: hrv.map { String(format: "%.0f", $0) },
                                                unit: "ms",
                                                status: hrv != nil ? .normal(scoreResult.isCalibrating ? "Learning your rhythm" : "Looking steady") : .noData("No reading yet")
                                            )
                                        }

                                        NavigationLink {
                                            MetricTrendView(metrics: allMetrics, initialIndex: 3, isNightTime: isNightTime)
                                        } label: {
                                            trendCard(
                                                icon: "heart.fill",
                                                iconColor: Color(red: 0.95, green: 0.5, blue: 0.55),
                                                title: "Resting Heart Rate",
                                                value: restingHeartRate.map { String(format: "%.0f", $0) },
                                                unit: "bpm",
                                                status: restingHeartRate != nil ? .normal(scoreResult.isCalibrating ? "Learning your rhythm" : "Nice and calm") : .noData("No reading yet")
                                            )
                                        }

                                        NavigationLink {
                                            MetricTrendView(metrics: allMetrics, initialIndex: 4, isNightTime: isNightTime)
                                        } label: {
                                            trendCard(
                                                icon: "lungs.fill",
                                                iconColor: Color(red: 0.5, green: 0.8, blue: 0.85),
                                                title: "Respiratory Rate",
                                                value: respiratoryRate.map { String(format: "%.1f", $0) },
                                                unit: "br/min",
                                                status: respiratoryRate != nil ? .normal("Steady breathing") : .noData("No reading yet")
                                            )
                                        }

                                        NavigationLink {
                                            MetricTrendView(metrics: allMetrics, initialIndex: 5, isNightTime: isNightTime)
                                        } label: {
                                            trendCard(
                                                icon: "thermometer.medium",
                                                iconColor: Color(red: 0.95, green: 0.65, blue: 0.4),
                                                title: "Body Temperature",
                                                value: bodyTempDelta.map { String(format: "%.1f", $0) },
                                                unit: "°C",
                                                status: bodyTempDelta != nil ? .normal("Within range") : .noData("Needs a newer Watch")
                                            )
                                        }

                    trendCard(
                        icon: "bed.double.fill",
                        iconColor: Color(red: 0.55, green: 0.65, blue: 0.9),
                        title: "Sleep Time",
                        value: bedTime.map { formatTime($0) },
                        unit: nil,
                        status: bedTime != nil ? .normal("Right on schedule") : .noData("No data")
                    )

                    trendCard(
                        icon: "sunrise.fill",
                        iconColor: Color(red: 0.98, green: 0.75, blue: 0.35),
                        title: "Wake Time",
                        value: wakeTime.map { formatTime($0) },
                        unit: nil,
                        status: wakeTime != nil ? .normal("Rise and shine") : .noData("No data")
                    )
                }
                .padding()
                .padding(.top, 8)
            }
        }
        .navigationTitle("Sleep Trends")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sleep Score karti (ozel, mini daire ile)

    private var sleepScoreTrendCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Sleep Score")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.6))
                }

                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text("\(scoreResult.score)")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("%")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }

                if scoreResult.isCalibrating {
                    HStack(spacing: 5) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.caption2)
                        Text("Calibrating")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white.opacity(0.5))
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(scoreCircleColor)
                        Text(statusLabel(for: scoreResult.score))
                            .font(.caption2.bold())
                            .foregroundStyle(scoreCircleColor)
                    }
                }
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 6)
                    .frame(width: 56, height: 56)

                Circle()
                    .trim(from: 0, to: CGFloat(scoreResult.score) / 100)
                    .stroke(scoreCircleColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(20)
        .frame(minHeight: 100)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var scoreCircleColor: Color {
        switch scoreResult.score {
        case 80...100: return Color(red: 0.55, green: 0.85, blue: 0.35)
        case 50..<80: return Color(red: 0.95, green: 0.7, blue: 0.25)
        default: return Color(red: 0.95, green: 0.45, blue: 0.45)
        }
    }

    private func statusLabel(for score: Int) -> String {
        switch score {
        case 80...100: return "Crushing it"
        case 50..<80: return "Pretty solid"
        default: return "A little rough"
        }
    }

    // MARK: - Genel trend karti

    private enum CardStatus {
        case normal(String)
        case noData(String)
    }

    private func trendCard(icon: String, iconColor: Color, title: String, value: String?, unit: String?, status: CardStatus?) -> some View {
        let isEmpty = value == nil

        return HStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(isEmpty ? .white.opacity(0.3) : iconColor)
                    Text(title)
                        .font(.caption.bold())
                        .foregroundStyle(isEmpty ? .white.opacity(0.35) : .white.opacity(0.6))
                }

                if let value {
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(value)
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        if let unit {
                            Text(unit)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                } else {
                    Text("No data")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                }

                switch status {
                case .normal(let label):
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(Color(red: 0.55, green: 0.85, blue: 0.35))
                        Text(label)
                            .font(.caption2.bold())
                            .foregroundStyle(Color(red: 0.55, green: 0.85, blue: 0.35))
                    }
                case .noData(let label):
                    HStack(spacing: 5) {
                        Image(systemName: "moon.zzz")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                case .none:
                    EmptyView()
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(isEmpty ? 0.2 : 0.4))
        }
        .padding(20)
        .frame(minHeight: 100)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var celestialLayer: some View {
        if isNightTime {
            nightSkyLayer
        } else {
            daySkyLayer
        }
    }

    private var nightSkyLayer: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<50, id: \.self) { i in
                    let seed = Double(i)
                    let sizeVariant = [0.8, 1.5, 1.0, 2.0, 0.6, 1.3, 2.4, 0.9][i % 8]
                    let opacityVariant = [0.95, 0.35, 0.6, 0.25, 0.8, 0.45, 0.9, 0.55][i % 8]
                    Circle()
                        .fill(Color.white)
                        .frame(width: sizeVariant, height: sizeVariant)
                        .opacity(opacityVariant)
                        .shadow(color: .white.opacity(opacityVariant * 0.6), radius: sizeVariant * 0.8)
                        .position(
                            x: geo.size.width * ((seed * 41).truncatingRemainder(dividingBy: 100) / 100),
                            y: geo.size.height * 0.5 * ((seed * 67).truncatingRemainder(dividingBy: 100) / 100)
                        )
                }

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 0.75, green: 0.78, blue: 0.95).opacity(0.25), Color.clear],
                                center: .center,
                                startRadius: 4,
                                endRadius: 55
                            )
                        )
                        .frame(width: 110, height: 110)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.98, green: 0.97, blue: 0.93),
                                    Color(red: 0.88, green: 0.87, blue: 0.85),
                                    Color(red: 0.72, green: 0.72, blue: 0.75)
                                ],
                                center: UnitPoint(x: 0.35, y: 0.3),
                                startRadius: 2,
                                endRadius: 22
                            )
                        )
                        .frame(width: 38, height: 38)

                    Circle().fill(Color.black.opacity(0.08)).frame(width: 8, height: 8).offset(x: -8, y: -6)
                    Circle().fill(Color.black.opacity(0.06)).frame(width: 5, height: 5).offset(x: 6, y: -10)
                    Circle().fill(Color.black.opacity(0.07)).frame(width: 6, height: 6).offset(x: 4, y: 8)
                    Circle().fill(Color.black.opacity(0.05)).frame(width: 4, height: 4).offset(x: -10, y: 6)

                    Circle()
                        .fill(Color(red: 0.06, green: 0.05, blue: 0.14))
                        .frame(width: 34, height: 34)
                        .offset(x: 11, y: -3)
                        .blur(radius: 0.5)
                }
                .position(x: geo.size.width * 0.85, y: geo.size.height * 0.1)
            }
        }
    }

    private var daySkyLayer: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.9),
                                Color(red: 1.0, green: 0.96, blue: 0.8).opacity(0.6),
                                Color(red: 1.0, green: 0.92, blue: 0.6).opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .position(x: geo.size.width * 0.85, y: geo.size.height * 0.07)

                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                    .blur(radius: 3)
                    .position(x: geo.size.width * 0.85, y: geo.size.height * 0.07)

                realisticCloud
                    .frame(width: 110, height: 32)
                    .position(x: geo.size.width * 0.2, y: geo.size.height * 0.14)
                    .opacity(0.6)

                realisticCloud
                    .frame(width: 75, height: 22)
                    .position(x: geo.size.width * 0.55, y: geo.size.height * 0.06)
                    .opacity(0.4)

                realisticCloud
                    .frame(width: 60, height: 18)
                    .position(x: geo.size.width * 0.06, y: geo.size.height * 0.28)
                    .opacity(0.3)
            }
        }
    }

    private var realisticCloud: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color.white.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Circle().fill(Color.white).frame(width: 32, height: 32).offset(x: -20, y: -6)
            Circle().fill(Color.white.opacity(0.9)).frame(width: 26, height: 26).offset(x: 16, y: -7)
            Circle().fill(Color.white.opacity(0.85)).frame(width: 20, height: 20).offset(x: -30, y: -2)
        }
        .blur(radius: 4)
    }

    private func metricCard(icon: String, label: String, value: String, fullWidth: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.85))
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
        SleepTrendsView(
            scoreResult: .init(score: 82, timeInBedMinutes: 471, timeAsleepMinutes: 443, efficiency: 94, isCalibrating: false),
            hrv: 54.4,
            restingHeartRate: 58,
            respiratoryRate: 14.2,
            bodyTempDelta: 0.2,
            sleepStages: .init(remMinutes: 95, deepMinutes: 62, coreMinutes: 240, awakeMinutes: 12),
            bedTime: Date(),
            wakeTime: Date()
        )
        .environmentObject(ThemeManager())
    }
}
