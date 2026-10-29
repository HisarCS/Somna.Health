//
//  SleepAppApp.swift
//  SleepApp
//

import SwiftUI
import SwiftData

@main
struct SleepAppApp: App {
    @StateObject private var themeManager = ThemeManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @State private var showSplash = true
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SleepEntry.self,
            UserProfile.self,
        ])

        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.azizozdemir.somna2026") else {
            fatalError("App Group container bulunamadi")
        }
        let storeURL = groupURL.appendingPathComponent("SomnaData.sqlite")

        let modelConfiguration = ModelConfiguration(
                            schema: schema,
                            url: storeURL,
                            cloudKitDatabase: .automatic
                        )

                do {
                    return try ModelContainer(for: schema, configurations: [modelConfiguration])
                } catch {
                    fatalError("ModelContainer oluşturulamadı: \(error)")
                }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SplashScreenView {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                } else if hasCompletedOnboarding {
                    TabView {
                        TodayView()
                            .tabItem {
                                Label("Today", systemImage: themeManager.theme.icon)
                            }
                        TrendView()
                            .tabItem {
                                Label("Trend", systemImage: "chart.bar.fill")
                            }
                        InsightsView()
                            .tabItem {
                                Label("Insights", systemImage: "sparkles")
                            }
                        SomnaDeviceView()
                            .tabItem {
                                Label("Wisp", systemImage: "drop.fill")
                            }
                    }
                    .transition(.opacity)
                    .onAppear {
                        updateWeeklySummaryIfNeeded()
                        // Somna wrist device: reconnect at launch if it was paired before
                        // (first pairing happens with the Connect button in the Wisp tab)
                        if SomnaBLEManager.shared.isPaired {
                            SomnaBLEManager.shared.start()
                        }
                    }
                } else {
                    OnboardingView()
                        .transition(.opacity)
                }
            }
            .environmentObject(themeManager)
            // Sistem bilesenleri (tab bar, saat secici, listeler) gunduz/gece temasiyla ayni gorunsun
            .preferredColorScheme(themeManager.theme == .day ? .light : .dark)
            .tint(themeManager.theme.primaryColor)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, phase in
            // app on screen -> Somna sends every record at once (live mode)
            SomnaBLEManager.shared.setLive(phase == .active)
        }
    }

    private func updateWeeklySummaryIfNeeded() {
        guard notificationsEnabled else { return }

        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<SleepEntry>(sortBy: [SortDescriptor(\.date, order: .forward)])
        guard let allEntries = try? context.fetch(descriptor) else { return }

        let calendar = Calendar.current
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let twoWeeksAgoStart = calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()

        let lastWeekEntries = allEntries.filter { $0.date >= lastWeekStart }
        let priorWeekEntries = allEntries.filter { $0.date >= twoWeeksAgoStart && $0.date < lastWeekStart }

        guard !lastWeekEntries.isEmpty else { return }

        let lastWeekAvg = lastWeekEntries.reduce(0) { $0 + $1.durationInMinutes } / lastWeekEntries.count

        var percentChange: Int? = nil
        if !priorWeekEntries.isEmpty {
            let priorAvg = priorWeekEntries.reduce(0) { $0 + $1.durationInMinutes } / priorWeekEntries.count
            if priorAvg > 0 {
                let diff = Double(lastWeekAvg - priorAvg)
                percentChange = Int((diff / Double(priorAvg)) * 100)
            }
        }

        NotificationManager.shared.scheduleWeeklySummary(averageMinutes: lastWeekAvg, percentChange: percentChange)
    }
}
