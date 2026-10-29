//
//  ReadinessTrendsView.swift
//  SleepApp
//

import SwiftUI
import SwiftData

struct ReadinessTrendsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Query(sort: \SleepEntry.date, order: .forward) private var entries: [SleepEntry]
    let result: HealthKitManager.ReadinessResult

    private var isNightTime: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour >= 18
    }

    private var backgroundImageName: String {
        isNightTime ? "readiness_bg_night" : "readiness_bg_day"
    }

    private var color: Color {
        switch result.score {
        case 80...100: return Color(red: 0.55, green: 0.85, blue: 0.35)
        case 50..<80: return Color(red: 0.95, green: 0.7, blue: 0.25)
        default: return Color(red: 0.95, green: 0.45, blue: 0.45)
        }
    }

    private var hrvHistory: [MetricDataPoint] {
        entries.filter { $0.hrv > 0 }.map { MetricDataPoint(date: $0.date, value: $0.hrv) }
    }

    private var rhrHistory: [MetricDataPoint] {
        entries.filter { $0.restingHeartRate > 0 }.map { MetricDataPoint(date: $0.date, value: $0.restingHeartRate) }
    }

    private var allMetrics: [TrendMetric] {
        [
            TrendMetric(title: "HRV", unit: "ms", color: .purple, dataPoints: hrvHistory, decimalPlaces: 1),
            TrendMetric(title: "Resting HR", unit: "bpm", color: .pink, dataPoints: rhrHistory, decimalPlaces: 1)
        ]
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
                                Text("A few more nights and readiness will be tailored to you.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    NavigationLink {
                        MetricTrendView(metrics: allMetrics, initialIndex: 0, isNightTime: isNightTime)
                    } label: {
                        metricCard(icon: "waveform.path.ecg", label: "HRV", value: result.hrv.map { String(format: "%.0f ms", $0) } ?? "No data")
                    }

                    NavigationLink {
                        MetricTrendView(metrics: allMetrics, initialIndex: 1, isNightTime: isNightTime)
                    } label: {
                        metricCard(icon: "heart.fill", label: "Resting Heart Rate", value: result.restingHeartRate.map { String(format: "%.0f bpm", $0) } ?? "No data")
                    }

                    trendCard(icon: "moon.stars.fill", title: "REM Sleep", status: .noData("Coming soon"))
                    trendCard(icon: "figure.walk", title: "Recent Activity", status: .noData("Coming soon"))
                }
                .padding()
                .padding(.top, 8)
            }
        }
        .navigationTitle("Readiness Trends")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metricCard(icon: String, label: String, value: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Text(value)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private enum CardStatus {
        case noData(String)
    }

    private func trendCard(icon: String, title: String, status: CardStatus) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.3))
                    Text(title)
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.35))
                }
                Text("No data")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))

                switch status {
                case .noData(let label):
                    HStack(spacing: 5) {
                        Image(systemName: "moon.zzz")
                            .font(.caption2)
                        Text(label)
                            .font(.caption2)
                    }
                    .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(20)
        .frame(minHeight: 90)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    NavigationStack {
        ReadinessTrendsView(result: .init(score: 82, hrv: 54.4, restingHeartRate: 58, isCalibrating: false))
            .environmentObject(ThemeManager())
    }
}
