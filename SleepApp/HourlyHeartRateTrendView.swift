//
//  HourlyHeartRateTrendView.swift
//  SleepApp
//

import SwiftUI
import Charts

struct HourlyHeartRateTrendView: View {
    let isNightTime: Bool

    @State private var history: [HealthKitManager.HourlyStressPoint] = []
    @State private var selectedPoint: HealthKitManager.HourlyStressPoint?
    @State private var isLoading = true

    private var average: Double {
        guard !history.isEmpty else { return 0 }
        return Double(history.reduce(0) { $0 + $1.score }) / Double(history.count)
    }

    private var latest: Int {
        history.last?.score ?? 0
    }

    private var color: Color { .pink }

    private var backgroundColor: Color {
            isNightTime ? Color(red: 0.05, green: 0.04, blue: 0.13) : Color(red: 0.22, green: 0.4, blue: 0.6)
        }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    if history.isEmpty {
                        emptyState
                    } else {
                        summaryHeader
                        chartCard
                    }
                }
                .padding()
                .padding(.top, 8)
            }
        }
        .navigationTitle("Heart Rate")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            HealthKitManager.shared.fetchTodayHeartRateHistory { points in
                self.history = points
                self.isLoading = false
            }
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LATEST")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(.white.opacity(0.5))
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text("\(latest)")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("bpm")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                Text("AVERAGE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(.white.opacity(0.5))
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(String(format: "%.0f", average))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("bpm")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's heart rate")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.7))

            Chart {
                ForEach(history, id: \.time) { point in
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Heart Rate", point.score)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Time", point.time),
                        y: .value("Heart Rate", point.score)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [color.opacity(0.3), color.opacity(0)], startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.catmullRom)
                }

                RuleMark(y: .value("Average", average))
                    .foregroundStyle(color.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .annotation(position: .top, alignment: .center) {
                        Text("Avg. \(String(format: "%.0f", average)) bpm")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(color)
                            .clipShape(Capsule())
                    }

                if let selected = selectedPoint {
                    RuleMark(x: .value("Time", selected.time))
                        .foregroundStyle(.white.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                    PointMark(
                        x: .value("Time", selected.time),
                        y: .value("Heart Rate", selected.score)
                    )
                    .foregroundStyle(color)
                    .symbolSize(100)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
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
            .frame(height: 200)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(Color.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let location = value.location
                                    if let date: Date = proxy.value(atX: location.x) {
                                        selectedPoint = history.min(by: {
                                            abs($0.time.timeIntervalSince(date)) < abs($1.time.timeIntervalSince(date))
                                        })
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
                    Text("\(selected.score) bpm")
                        .font(.caption.bold())
                        .foregroundStyle(color)
                }
                .foregroundStyle(.white)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.4))
            Text(isLoading ? "Loading…" : "No heart rate data yet")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }
}

#Preview {
    NavigationStack {
        HourlyHeartRateTrendView(isNightTime: true)
    }
}
