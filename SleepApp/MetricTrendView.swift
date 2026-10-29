//
//  MetricTrendView.swift
//  SleepApp
//

import SwiftUI
import Charts

struct MetricDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct TrendMetric: Identifiable {
    let id = UUID()
    let title: String
    let unit: String
    let color: Color
    let dataPoints: [MetricDataPoint]
    let decimalPlaces: Int
    var isTimeOfDay: Bool = false
}

struct MetricTrendView: View {
    let metrics: [TrendMetric]
    let initialIndex: Int
    let isNightTime: Bool
    let isHourly: Bool

    @State private var selectedIndex: Int
    @State private var selectedPoint: MetricDataPoint?

    init(metrics: [TrendMetric], initialIndex: Int = 0, isNightTime: Bool, isHourly: Bool = false) {
        self.metrics = metrics
        self.initialIndex = initialIndex
        self.isNightTime = isNightTime
        self.isHourly = isHourly
        self._selectedIndex = State(initialValue: initialIndex)
    }

    private var selectedMetric: TrendMetric {
        metrics[selectedIndex]
    }

    private var sortedPoints: [MetricDataPoint] {
        selectedMetric.dataPoints.sorted { $0.date < $1.date }
    }

    private var average: Double {
        guard !sortedPoints.isEmpty else { return 0 }
        return sortedPoints.reduce(0) { $0 + $1.value } / Double(sortedPoints.count)
    }

    private var latest: Double {
        sortedPoints.last?.value ?? 0
    }

    private var latestDate: Date {
        sortedPoints.last?.date ?? Date()
    }

    private var yAxisRange: ClosedRange<Double> {
        guard !sortedPoints.isEmpty else { return 0...100 }
        let values = sortedPoints.map { $0.value }
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 100
        let padding = max((maxVal - minVal) * 0.3, maxVal * 0.1, 2)
        return max(0, minVal - padding)...(maxVal + padding)
    }

    // MARK: - Renk paleti (gece/gunduz)

    private var backgroundColor: Color {
            isNightTime ? Color(red: 0.05, green: 0.04, blue: 0.13) : Color(red: 0.22, green: 0.4, blue: 0.6)
        }

        private var primaryTextColor: Color {
            .white
        }

        private var secondaryTextColor: Color {
            .white.opacity(0.65)
        }

        private var tertiaryTextColor: Color {
            .white.opacity(0.45)
        }

        private var tabInactiveBackground: Color {
            Color.black.opacity(isNightTime ? 0.2 : 0.12)
        }

        private var tabActiveBackground: Color {
            Color.black.opacity(isNightTime ? 0.35 : 0.22)
        }

        private var gridLineColor: Color {
            Color.white.opacity(0.15)
        }

    private var accentColor: Color {
        Color(red: 0.4, green: 0.85, blue: 0.6)
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                tabSelector
                    .padding(.top, 20)

                chartArea
                    .padding(.top, 24)
                    .padding(.horizontal, 20)

                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                                            Text(formattedValue(latest))
                                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                                .foregroundStyle(primaryTextColor)
                                            if !selectedMetric.isTimeOfDay {
                                                Text(selectedMetric.unit)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundStyle(secondaryTextColor)
                                            }
                                        }
                    Text(formattedDate(latestDate))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(secondaryTextColor)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(sortedPoints.isEmpty ? "No data" : "Normal range")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(sortedPoints.isEmpty ? tertiaryTextColor : accentColor)
                    if !sortedPoints.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.and.down")
                                .font(.system(size: 9))
                            Text("\(formattedValue(yAxisRange.lowerBound + (yAxisRange.upperBound - yAxisRange.lowerBound) * 0.35)) – \(formattedValue(yAxisRange.lowerBound + (yAxisRange.upperBound - yAxisRange.lowerBound) * 0.65)) \(selectedMetric.unit)")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(tertiaryTextColor)
                    }
                }
            }
        }
    }

    // MARK: - Kaydirilabilir sekme secici

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(metrics.indices, id: \.self) { index in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedIndex = index
                        }
                    } label: {
                        Text(metrics[index].title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selectedIndex == index ? primaryTextColor : secondaryTextColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedIndex == index ? tabActiveBackground : tabInactiveBackground)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Grafik alani

    @ViewBuilder
    private var chartArea: some View {
        if sortedPoints.isEmpty {
            emptyState
        } else {
            Chart {
                ForEach(sortedPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(selectedMetric.title, point.value)
                    )
                    .foregroundStyle(accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value(selectedMetric.title, point.value)
                    )
                    .foregroundStyle(accentColor)
                    .symbolSize(sortedPoints.count == 1 ? 160 : 40)
                }

                if let selected = selectedPoint {
                    RuleMark(x: .value("Date", selected.date))
                        .foregroundStyle(.white.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                    PointMark(
                        x: .value("Date", selected.date),
                        y: .value(selectedMetric.title, selected.value)
                    )
                    .foregroundStyle(accentColor)
                    .symbolSize(100)
                }
            }
            .chartYScale(domain: yAxisRange)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: min(sortedPoints.count, 5))) { value in
                    AxisGridLine()
                        .foregroundStyle(gridLineColor)
                    AxisValueLabel(format: isHourly ? .dateTime.hour() : .dateTime.month(.abbreviated).day())
                        .foregroundStyle(secondaryTextColor)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                        .foregroundStyle(gridLineColor)
                    AxisValueLabel()
                        .foregroundStyle(tertiaryTextColor)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
            }
            .frame(height: 220)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(Color.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let location = value.location
                                    if let date: Date = proxy.value(atX: location.x) {
                                        selectedPoint = sortedPoints.min(by: {
                                            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
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
                    Text(formattedDate(selected.date))
                        .font(.caption.bold())
                    Spacer()
                    Text("\(formattedValue(selected.value)) \(selectedMetric.unit)")
                        .font(.caption.bold())
                        .foregroundStyle(accentColor)
                }
                .foregroundStyle(primaryTextColor)
                .padding(.top, 6)
            }

            if sortedPoints.count < 4 {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                    Text("Your trend line grows richer with every night logged.")
                        .font(.system(size: 12))
                }
                .foregroundStyle(secondaryTextColor)
                .padding(.top, 12)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundStyle(tertiaryTextColor)
            Text("No trend data yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(primaryTextColor)
            Text("This will fill in as you log more nights with your Apple Watch.")
                .font(.system(size: 13))
                .foregroundStyle(secondaryTextColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }

    // MARK: - Formatlama

    private func formattedValue(_ value: Double) -> String {
            if selectedMetric.isTimeOfDay {
                let totalMinutes = Int(value)
                let hours = totalMinutes / 60
                let minutes = totalMinutes % 60
                return String(format: "%02d:%02d", hours, minutes)
            }
            return String(format: "%.\(selectedMetric.decimalPlaces)f", value)
        }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = isHourly ? "h:mm a" : "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        MetricTrendView(
            metrics: [
                TrendMetric(title: "Respiratory Rate", unit: "br/min", color: .cyan, dataPoints: [.init(date: Date(), value: 13.8)], decimalPlaces: 1),
                TrendMetric(title: "Resting HR", unit: "bpm", color: .pink, dataPoints: [
                    .init(date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, value: 58),
                    .init(date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, value: 52),
                    .init(date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, value: 55),
                    .init(date: Date(), value: 54.3)
                ], decimalPlaces: 1),
                TrendMetric(title: "Resting HRV", unit: "ms", color: .purple, dataPoints: [.init(date: Date(), value: 69.0)], decimalPlaces: 1)
            ],
            initialIndex: 1,
            isNightTime: false
        )
    }
}
