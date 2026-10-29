//
//  HealthMonitorDetailView.swift
//  SleepApp
//

import SwiftUI
import SwiftData

struct HealthMonitorDetailView: View {
    @Query(sort: \SleepEntry.date, order: .forward) private var entries: [SleepEntry]

    let hrv: Double?
    let restingHeartRate: Double?
    let respiratoryRate: Double?
    let heartRate: Double?
    let bodyTempDelta: Double?
    let timeAsleepMinutes: Int?

    private var isNightTime: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour >= 18
    }

    // MARK: - Gecmis veri (gunluk trendler icin)

    private var hrvHistory: [MetricDataPoint] {
        entries.filter { $0.hrv > 0 }.map { MetricDataPoint(date: $0.date, value: $0.hrv) }
    }

    private var rhrHistory: [MetricDataPoint] {
        entries.filter { $0.restingHeartRate > 0 }.map { MetricDataPoint(date: $0.date, value: $0.restingHeartRate) }
    }

    private var respiratoryHistory: [MetricDataPoint] {
        entries.filter { $0.respiratoryRate > 0 }.map { MetricDataPoint(date: $0.date, value: $0.respiratoryRate) }
    }

    private var tempHistory: [MetricDataPoint] {
        entries.filter { $0.bodyTempDelta != 0 }.map { MetricDataPoint(date: $0.date, value: $0.bodyTempDelta) }
    }

    private var sleepHistory: [MetricDataPoint] {
        entries.map { MetricDataPoint(date: $0.date, value: Double($0.durationInMinutes)) }
    }

    // MARK: - Onceki degerle karsilastirma (Higher/Lower/Normal)

    private enum Trend {
        case higher, lower, normal, noData
    }

    private func trend(current: Double?, history: [MetricDataPoint]) -> Trend {
        guard let current else { return .noData }
        guard let previous = history.dropLast().last?.value else { return .normal }
        let diff = current - previous
        let threshold = abs(previous) * 0.05
        if diff > threshold { return .higher }
        if diff < -threshold { return .lower }
        return .normal
    }

    private func trendLabel(_ trend: Trend) -> String {
        switch trend {
        case .higher: return "Higher"
        case .lower: return "Lower"
        case .normal: return "Normal"
        case .noData: return ""
        }
    }

    private func trendColor(_ trend: Trend) -> Color {
        switch trend {
        case .higher, .lower: return Color(red: 0.95, green: 0.7, blue: 0.25)
        case .normal: return Color(red: 0.55, green: 0.85, blue: 0.35)
        case .noData: return .white.opacity(0.3)
        }
    }

    private func trendIcon(_ trend: Trend) -> String {
        switch trend {
        case .higher: return "arrow.up"
        case .lower: return "arrow.down"
        case .normal: return "checkmark"
        case .noData: return ""
        }
    }

    // MARK: - Range indicator pozisyonu (0 = alt, 1 = ust)

    private func rangePosition(current: Double?, history: [MetricDataPoint]) -> CGFloat {
        guard let current else { return 0.5 }
        let values = (history.map { $0.value } + [current])
        guard let minVal = values.min(), let maxVal = values.max(), maxVal > minVal else { return 0.5 }
        return CGFloat((current - minVal) / (maxVal - minVal))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                            colors: isNightTime
                                ? [Color(red: 0.05, green: 0.04, blue: 0.13), Color(red: 0.11, green: 0.08, blue: 0.22)]
                                : [Color(red: 0.3, green: 0.5, blue: 0.75), Color(red: 0.42, green: 0.6, blue: 0.82)],
                            startPoint: .top,
                            endPoint: .bottom
                        )            .ignoresSafeArea()

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {

                    NavigationLink {
                        MetricTrendView(
                            metrics: [TrendMetric(title: "Respiratory Rate", unit: "rpm", color: .cyan, dataPoints: respiratoryHistory, decimalPlaces: 1)],
                            isNightTime: isNightTime
                        )
                    } label: {
                        metricCard(
                            icon: "lungs.fill", label: "RR",
                            value: respiratoryRate.map { String(format: "%.1f", $0) },
                            unit: "rpm",
                            trend: trend(current: respiratoryRate, history: respiratoryHistory),
                            rangePos: rangePosition(current: respiratoryRate, history: respiratoryHistory)
                        )
                    }

                    NavigationLink {
                        MetricTrendView(
                            metrics: [TrendMetric(title: "Resting Heart Rate", unit: "bpm", color: .pink, dataPoints: rhrHistory, decimalPlaces: 1)],
                            isNightTime: isNightTime
                        )
                    } label: {
                        metricCard(
                            icon: "heart.fill", label: "RHR",
                            value: restingHeartRate.map { String(format: "%.1f", $0) },
                            unit: "bpm",
                            trend: trend(current: restingHeartRate, history: rhrHistory),
                            rangePos: rangePosition(current: restingHeartRate, history: rhrHistory)
                        )
                    }

                    NavigationLink {
                        MetricTrendView(
                            metrics: [TrendMetric(title: "HRV", unit: "ms", color: .purple, dataPoints: hrvHistory, decimalPlaces: 1)],
                            isNightTime: isNightTime
                        )
                    } label: {
                        metricCard(
                            icon: "waveform.path.ecg", label: "HRV",
                            value: hrv.map { String(format: "%.1f", $0) },
                            unit: "ms",
                            trend: trend(current: hrv, history: hrvHistory),
                            rangePos: rangePosition(current: hrv, history: hrvHistory)
                        )
                    }

                    NavigationLink {
                        HourlyHeartRateTrendView(isNightTime: isNightTime)
                    } label: {
                        metricCard(
                            icon: "heart.text.square.fill", label: "HR",
                            value: heartRate.map { String(format: "%.0f", $0) },
                            unit: "bpm",
                            trend: .normal,
                            rangePos: 0.5
                        )
                    }

                    NavigationLink {
                        MetricTrendView(
                            metrics: [TrendMetric(title: "Body Temperature", unit: "°C", color: .orange, dataPoints: tempHistory, decimalPlaces: 1)],
                            isNightTime: isNightTime
                        )
                    } label: {
                        metricCard(
                            icon: "thermometer.medium", label: "Temp",
                            value: bodyTempDelta.map { String(format: "%.1f", $0) },
                            unit: "°C",
                            trend: trend(current: bodyTempDelta, history: tempHistory),
                            rangePos: rangePosition(current: bodyTempDelta, history: tempHistory)
                        )
                    }

                    NavigationLink {
                        MetricTrendView(
                            metrics: [TrendMetric(title: "Sleep", unit: "min", color: .indigo, dataPoints: sleepHistory, decimalPlaces: 0)],
                            isNightTime: isNightTime
                        )
                    } label: {
                        metricCard(
                            icon: "bed.double.fill", label: "Sleep",
                            value: timeAsleepMinutes.map { formatMinutes($0) },
                            unit: nil,
                            trend: timeAsleepMinutes != nil ? .normal : .noData,
                            rangePos: 0.5
                        )
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Health Monitor")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metricCard(icon: String, label: String, value: String?, unit: String?, trend: Trend, rangePos: CGFloat) -> some View {
            let hasData = value != nil
            let color = trendColor(trend)

            return HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(hasData ? 0.5 : 0.3))
                        Text(label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(hasData ? 0.5 : 0.3))
                    }

                    if let value {
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text(value)
                                .font(.system(size: 27, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                            if let unit {
                                Text(unit)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                    } else {
                        Text("No data")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    if hasData {
                        HStack(spacing: 5) {
                            Image(systemName: trendIcon(trend))
                                .font(.system(size: 11, weight: .bold))
                            Text(trendLabel(trend))
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(color)
                    }
                }

                Spacer(minLength: 0)

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 10, height: 84)

                    if hasData {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle().stroke(color, lineWidth: 2.5)
                            )
                            .offset(y: -(rangePos * 74 + 5))
                    }
                }
            }
            .padding(18)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 130)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .opacity(hasData ? 1.0 : 0.6)
                
        }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }
}

#Preview {
    NavigationStack {
        HealthMonitorDetailView(
            hrv: 54.4,
            restingHeartRate: 58,
            respiratoryRate: 14.5,
            heartRate: 72,
            bodyTempDelta: 0.2,
            timeAsleepMinutes: 488
        )
    }
}
