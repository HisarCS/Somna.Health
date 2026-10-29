//
//  TodayView.swift
//  SleepApp
//

import SwiftUI
import SwiftData
import UIKit
import AudioToolbox
import WidgetKit

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var themeManager: ThemeManager
    /// Today ekrani Apple Fitness gibi her zaman siyah: alt bilesenler bu temayi gorur
    @StateObject private var darkTheme = ThemeManager(fixed: .night)
    private var theme: AppTheme { .night }
    @Query(sort: \SleepEntry.date, order: .reverse) private var entries: [SleepEntry]
    @Query private var profiles: [UserProfile]
    @ObservedObject private var ble = SomnaBLEManager.shared

    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hasAppleWatch") private var hasAppleWatch = false
    @AppStorage("healthKitAuthorized") private var healthKitAuthorized = false
    @AppStorage("lastCheckInDate", store: UserDefaults(suiteName: "group.com.azizozdemir.somna2026")) private var lastCheckInDateString: String = ""
    @AppStorage("lastCheckInLevel", store: UserDefaults(suiteName: "group.com.azizozdemir.somna2026")) private var lastCheckInLevel: Int = 0

    @State private var bedTime: Date = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var wakeTime: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var quality: Int = 3
    @State private var hadCaffeine = false
    @State private var hadScreenBeforeBed = false
    @State private var didExercise = false
    @State private var hadAlcohol = false

    @State private var showSaveAnimation = false
    @State private var streakPop = false
    @State private var displayedStreak = 0
    @State private var showConfetti = false
    @State private var confettiIntensity: ConfettiIntensity = .subtle
    @State private var milestoneMessage: String? = nil

    @State private var healthKitScore: HealthKitManager.SleepScoreResult?
    @AppStorage("lastHealthKitCheckDate") private var lastHealthKitCheckDateString: String = ""
    @State private var pendingHRV: Double?
    @State private var pendingRHR: Double?
    @State private var pendingRespiratoryRate: Double?
    @State private var pendingBodyTempDelta: Double?
    @State private var pendingHeartRate: Double?
    @State private var lastHeartRateUpdate: Date?
    @State private var sleepStages: HealthKitManager.SleepStages?
    @State private var sleepSummary: HealthKitManager.SleepSummary?
    @State private var isSyncing = false
    @State private var currentHRV: Double?
    @State private var pendingActiveEnergy: Double?
    @State private var pendingExerciseMinutes: Double?
    @State private var pendingAvgHeartRate: Double?
    @State private var pendingStepCount: Double?
    @State private var todayStressHistory: [HealthKitManager.HourlyStressPoint] = []

    private let milestones = [3, 10, 30]

    private var isWatchMode: Bool {
        hasAppleWatch && healthKitAuthorized
    }

    private var todayEntry: SleepEntry? {
        entries.first { Calendar.current.isDateInToday($0.date) }
    }

    private var mostRecentPastEntry: SleepEntry? {
        entries.first { !Calendar.current.isDateInToday($0.date) }
    }

    private var isMorningCheckInWindow: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 6 && hour < 13
    }

    private var streak: Int {
        var count = 0
        var dayToCheck = Calendar.current.startOfDay(for: Date())

        if todayEntry == nil {
            dayToCheck = Calendar.current.date(byAdding: .day, value: -1, to: dayToCheck) ?? dayToCheck
        }

        while true {
            let hasEntry = entries.contains { Calendar.current.isDate($0.date, inSameDayAs: dayToCheck) }
            if hasEntry {
                count += 1
                dayToCheck = Calendar.current.date(byAdding: .day, value: -1, to: dayToCheck) ?? dayToCheck
            } else {
                break
            }
        }
        return count
    }

    private var streakIcon: String {
        if streak >= 3 { return "flame.fill" }
        return "moon.stars.fill"
    }

    private var targetSleepMinutes: Int {
        profiles.first?.targetSleepMinutes ?? 480
    }

    private var targetHoursText: String {
        let hours = targetSleepMinutes / 60
        let mins = targetSleepMinutes % 60
        return mins == 0 ? "\(hours)h" : "\(hours)h \(mins)m"
    }

    private var suggestedBedtime: String? {
        guard profiles.first != nil else { return nil }
        guard !entries.isEmpty else { return nil }

        let calendar = Calendar.current

        let recentEntries = entries.prefix(7)
        let wakeMinutesList = recentEntries.map { entry -> Int in
            let comps = calendar.dateComponents([.hour, .minute], from: entry.wakeTime)
            return (comps.hour ?? 7) * 60 + (comps.minute ?? 0)
        }
        let avgWakeMinutes = wakeMinutesList.reduce(0, +) / max(wakeMinutesList.count, 1)

        guard let wakeTime = calendar.date(bySettingHour: avgWakeMinutes / 60, minute: avgWakeMinutes % 60, second: 0, of: Date()) else { return nil }
        guard let bedtime = calendar.date(byAdding: .minute, value: -targetSleepMinutes, to: wakeTime) else { return nil }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: bedtime)
    }

    private var recoveryMessage: String? {
        guard let recent = entries.first(where: { $0.morningFeeling > 0 }) else { return nil }
        guard Calendar.current.isDateInToday(recent.date) || Calendar.current.isDateInYesterday(recent.date) else { return nil }
        guard recent.morningFeeling <= 2 else { return nil }

        if recent.didExercise {
            return "You logged low energy after exercising. Consider a lighter workout today and prioritize rest."
        } else {
            return "You logged low energy this morning. Take it easy today if you can — maybe skip anything too demanding."
        }
    }

    private var hasCheckedInToday: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return lastCheckInDateString == formatter.string(from: Date())
    }

    private var midDayTip: String? {
        guard hasCheckedInToday, lastCheckInLevel > 0 else { return nil }
        switch lastCheckInLevel {
        case 1, 2:
            return "Try a short walk, some water, or a brief rest — small resets help on low-energy days."
        case 3:
            return "A steady day. Maybe a short walk or some fresh air to keep your energy up."
        default:
            return "You're feeling good — a great day to tackle something you've been putting off."
        }
    }

    private var isNightTime: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour >= 18
    }

    private var coachingMessage: String {
        guard let result = healthKitScore else { return "" }
        switch result.score {
        case 80...100:
            return "Great night. Your duration and efficiency were both strong — keep this routine going."
        case 50..<80:
            return "A decent night, but there's room to improve. Try keeping a more consistent bedtime this week."
        default:
            return "A rough night. Consider taking it easy today and aiming for an earlier bedtime tonight."
        }
    }

    private var readinessResult: HealthKitManager.ReadinessResult? {
        guard isWatchMode else { return nil }
        let hrvHistory = entries.filter { $0.hrv > 0 }.prefix(30)
        let daysOfHistory = hrvHistory.count
        let recentHRVAverage: Double? = daysOfHistory > 0
            ? hrvHistory.reduce(0) { $0 + $1.hrv } / Double(daysOfHistory)
            : nil
        let rhrHistory = entries.filter { $0.restingHeartRate > 0 }.prefix(30)
        let recentRHRAverage: Double? = rhrHistory.count > 0
            ? rhrHistory.reduce(0) { $0 + $1.restingHeartRate } / Double(rhrHistory.count)
            : nil

        return HealthKitManager.shared.calculateReadinessScore(
            hrv: pendingHRV,
            restingHeartRate: pendingRHR,
            recentHRVAverage: recentHRVAverage,
            recentRHRAverage: recentRHRAverage,
            daysOfHistory: daysOfHistory
        )
    }

    private var stressResult: HealthKitManager.StressResult? {
        guard isWatchMode else { return nil }
        let hrvHistory = entries.filter { $0.hrv > 0 }.prefix(30)
        let daysOfHistory = hrvHistory.count
        let recentHRVAverage: Double? = daysOfHistory > 0
            ? hrvHistory.reduce(0) { $0 + $1.hrv } / Double(daysOfHistory)
            : nil

        return HealthKitManager.shared.calculateStressScore(
            hrv: currentHRV,
            heartRate: pendingHeartRate,
            restingHeartRate: pendingRHR,
            recentHRVAverage: recentHRVAverage,
            daysOfHistory: daysOfHistory
        )
    }

    private var strainResult: HealthKitManager.StrainResult {
        HealthKitManager.shared.calculateStrainScore(
            activeEnergy: pendingActiveEnergy,
            exerciseMinutes: pendingExerciseMinutes,
            averageHeartRate: pendingAvgHeartRate,
            restingHeartRate: pendingRHR
        )
    }

    private var lastUpdateText: String {
        guard let date = lastHeartRateUpdate else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Apple Fitness gibi tam siyah zemin; ustunde o anki gercek gokyuzu:
                // gece yildizlar + gercek ay evresi, gunduz hafif gunes isigi
                SkyBackground(theme: .night, style: .oled)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DS.Spacing.md) {
                        header

                        if isSyncing {
                            HStack(spacing: DS.Spacing.xs) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Syncing with Apple Health…")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(theme.secondaryTextColor)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.xxs)
                            .transition(.opacity)
                        }

                        Group {
                            if isWatchMode {
                                // Apple Watch modu: skorlar Wisp kadraninin icinde
                                WispHeroCard(
                                    mood: wispMood,
                                    isLive: isWispLive,
                                    streak: displayedStreak,
                                    streakPop: streakPop,
                                    milestoneMessage: milestoneMessage,
                                    hapticsEnabled: hapticsEnabled
                                ) {
                                    scoreBars
                                }
                            } else {
                                WispHeroCard(
                                    mood: wispMood,
                                    isLive: isWispLive,
                                    streak: displayedStreak,
                                    streakPop: streakPop,
                                    milestoneMessage: milestoneMessage,
                                    hapticsEnabled: hapticsEnabled
                                )
                            }
                        }

                        if isWatchMode {
                            sleepScoreCard
                            myDaySection
                        } else {
                            manualModeContent
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.xl)
                }

                if showConfetti {
                    ConfettiView(intensity: confettiIntensity)
                }
            }
            // Bu ekranin icindeki her sey siyah temayi gorur
            .environmentObject(darkTheme)
            .environment(\.colorScheme, .dark)
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(Color.black.opacity(0.9), for: .tabBar)
            .toolbarColorScheme(.dark, for: .tabBar)
        }
        .onAppear {
            themeManager.refresh()
            displayedStreak = streak
            if isWatchMode {
                loadHealthKitScoreIfNeeded()
            }
        }
    }

    // MARK: - Baslik (apple.com tarzi: tarih + buyuk "Today")

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                    .font(DS.Typography.footnote.weight(.semibold))
                    .tracking(0.4)
                    .foregroundStyle(DS.Panel.secondary)
                Text("Today")
                    .font(DS.Typography.display)
                    .foregroundStyle(DS.Panel.text)
            }
            Spacer()
            HStack(spacing: DS.Spacing.xs) {
                NavigationLink {
                    appScreen(HistoryView())
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.primaryColor)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
                .accessibilityLabel("History")

                NavigationLink {
                    appScreen(SettingsView())
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(DS.Panel.secondary)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
                .accessibilityLabel("Settings")
            }
            .padding(.bottom, 4)
        }
        .padding(.top, DS.Spacing.xs)
        .padding(.horizontal, DS.Spacing.xxs)
    }

    /// Today'den acilan ekranlar uygulamanin normal (gunduz/gece) temasina doner
    private func appScreen<V: View>(_ view: V) -> some View {
        view
            .environmentObject(themeManager)
            .environment(\.colorScheme, themeManager.theme == .day ? .light : .dark)
    }

    // MARK: - Wisp (avatar ruh hali)

    /// Somna bileklik bagli ve son kayit taze mi
    private var isWispLive: Bool {
        guard let latest = ble.latest else { return false }
        return ble.state == .connected || Date().timeIntervalSince(latest.date) < 90
    }

    private var wispMood: WispMood {
        if isWispLive, let mood = ble.latest?.mood, mood != .unknown {
            return mood
        }
        let hour = Calendar.current.component(.hour, from: Date())
        let checkIn = hasCheckedInToday ? lastCheckInLevel : (mostRecentPastEntry?.morningFeeling ?? 0)
        return WispMood.fromAppData(
            hour: hour,
            checkInLevel: checkIn,
            readiness: readinessResult?.score,
            stress: stressResult?.score
        )
    }

    // MARK: - Manual mode (v1.1 tam davranisi)

    @ViewBuilder
    private var manualModeContent: some View {
        if isMorningCheckInWindow {
            if let pastEntry = mostRecentPastEntry, pastEntry.morningFeeling == 0 {
                morningCheckInCard(for: pastEntry)
            }
        } else {
            midDayCheckInCard
        }

        if let message = recoveryMessage {
            recoveryMessageCard(message)
        }

        if let today = todayEntry {
            loggedTodayCard(today)
        } else {
            manualEntryForm
        }
    }

    private var manualEntryForm: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader(title: "How did you sleep?")

            if let suggestion = suggestedBedtime {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(DS.Metric.streak)
                        .frame(width: 32, height: 32)
                        .background(DS.Metric.streak.opacity(0.14), in: Circle())
                    Text("To hit your \(targetHoursText) goal, try going to bed by \(suggestion).")
                        .font(DS.Typography.caption)
                        .foregroundStyle(theme.secondaryTextColor)
                }
                .somnaCard(padding: DS.Spacing.sm)
            }

            VStack(spacing: 0) {
                DatePicker("Bedtime", selection: $bedTime, displayedComponents: .hourAndMinute)
                    .padding(.vertical, DS.Spacing.xs)
                Divider().overlay(theme.stroke)
                DatePicker("Wake time", selection: $wakeTime, displayedComponents: .hourAndMinute)
                    .padding(.vertical, DS.Spacing.xs)
            }
            .font(DS.Typography.body)
            .foregroundStyle(theme.textColor)
            .tint(theme.primaryColor)
            .somnaCard(padding: DS.Spacing.md)

            qualityAndHabitsForm

            Button("Save") { saveEntry() }
                .buttonStyle(SomnaPrimaryButtonStyle(color: theme.primaryColor))
                .padding(.top, DS.Spacing.xs)
        }
    }

    // MARK: - Skorlarin altindaki kartlar (koc + saglik/stres)

    @ViewBuilder
    private var sleepScoreCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            coachingSummaryBox
                .somnaCard(padding: DS.Spacing.md + 2)

            VStack(spacing: 0) {
                healthMonitorCard
                Divider().overlay(theme.stroke).padding(.leading, 44)
                stressMonitorCard
            }
            .somnaCard(padding: DS.Spacing.sm)

            if healthKitScore == nil && !isSyncing {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "applewatch")
                        .foregroundStyle(theme.primaryColor)
                    Text("Wear your Apple Watch tonight to see your sleep score here.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(theme.secondaryTextColor)
                }
                .somnaCard(padding: DS.Spacing.sm)
            }
        }
    }

    // MARK: - 3 yatay skor

    private var scoreBars: some View {
        VStack(spacing: DS.Spacing.lg) {
            if let result = healthKitScore {
                NavigationLink {
                    appScreen(SleepScoreDetailView(result: result, coachingMessage: coachingMessage, sleepStages: sleepStages, bedTime: sleepSummary?.bedTime, wakeTime: sleepSummary?.wakeTime))
                } label: {
                    ScoreBar(title: "Sleep", icon: "moon.zzz.fill", value: "\(result.score)", unit: "/100",
                             caption: SleepFormat.duration(result.timeAsleepMinutes),
                             progress: Double(result.score) / 100,
                             color: DS.Metric.sleepGlow, lightColor: DS.Metric.sleepLight)
                }
                .buttonStyle(.plain)
            } else {
                ScoreBar(title: "Sleep", icon: "moon.zzz.fill", value: nil, progress: 0,
                         color: DS.Metric.sleepGlow, lightColor: DS.Metric.sleepLight, showsChevron: false)
            }

            if let result = readinessResult {
                NavigationLink {
                    appScreen(ReadinessDetailView(result: result, coachingMessage: readinessMessage(for: result.score), respiratoryRate: pendingRespiratoryRate))
                } label: {
                    ScoreBar(title: "Readiness", icon: "bolt.heart.fill", value: "\(result.score)", unit: "/100",
                             progress: Double(result.score) / 100,
                             color: DS.Metric.readinessGlow, lightColor: DS.Metric.readinessLight)
                }
                .buttonStyle(.plain)
            } else {
                ScoreBar(title: "Readiness", icon: "bolt.heart.fill", value: nil, progress: 0,
                         color: DS.Metric.readinessGlow, lightColor: DS.Metric.readinessLight, showsChevron: false)
            }

            NavigationLink {
                appScreen(StrainDetailView(result: strainResult, stepCount: pendingStepCount))
            } label: {
                ScoreBar(title: "Strain", icon: "flame.fill", value: String(format: "%.1f", strainResult.score), unit: "/21",
                         progress: strainResult.score / 21.0,
                         color: DS.Metric.strainGlow, lightColor: DS.Metric.strainLight)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Koc mesaji

    private var coachingSummaryBox: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            CardLabel(title: "Coach", icon: "sparkles", color: theme.primaryColor)
            Text(overallCoachingMessage.isEmpty ? "Your coaching tip will appear after your first tracked night." : overallCoachingMessage)
                .font(DS.Typography.body)
                .foregroundStyle(theme.textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var overallCoachingMessage: String {
        guard let readiness = readinessResult else { return coachingMessage }
        if readiness.score >= 80 {
            return "Your recovery is strong today. A good day to take on a bit more than usual."
        } else if readiness.score >= 50 {
            return "Moderate recovery. Balance activity with rest today."
        } else {
            return "Recovery is low. Consider prioritizing rest and lighter activity today."
        }
    }

    // MARK: - Health / Stress satirlari

    @ViewBuilder
    private var healthMonitorCard: some View {
        let metrics: [Bool] = [
            (pendingHRV != nil),
            (pendingRHR != nil),
            (pendingRespiratoryRate != nil),
            (pendingHeartRate != nil),
            (pendingBodyTempDelta != nil),
            (healthKitScore != nil)
        ]
        let withinRange = metrics.filter { $0 }.count

        NavigationLink {
            appScreen(HealthMonitorDetailView(
                hrv: pendingHRV,
                restingHeartRate: pendingRHR,
                respiratoryRate: pendingRespiratoryRate,
                heartRate: pendingHeartRate,
                bodyTempDelta: pendingBodyTempDelta,
                timeAsleepMinutes: healthKitScore?.timeAsleepMinutes
            ))
        } label: {
            InfoRow(
                title: "Health monitor",
                icon: "heart.fill",
                tint: DS.Metric.heart,
                value: withinRange > 0 ? "Within range" : "No data",
                valueColor: withinRange > 0 ? DS.Metric.readiness : theme.mutedTextColor,
                detail: "\(withinRange) of 6 metrics"
            )
        }
        .buttonStyle(.plain)
    }

    private var stressMonitorCard: some View {
        let result = stressResult
        return NavigationLink {
            appScreen(StressTrendsView(result: stressResult ?? .init(score: 50, hrv: nil, isCalibrating: true), heartRate: pendingHeartRate, lastUpdate: lastHeartRateUpdate, todayHistory: todayStressHistory))
        } label: {
            InfoRow(
                title: "Stress",
                icon: "waveform.path.ecg",
                tint: DS.Metric.hrv,
                value: result.map { stressLabel(for: $0.score) } ?? "No data",
                valueColor: result.map { DS.Metric.stress($0.score) } ?? theme.mutedTextColor,
                detail: "Updated \(lastUpdateText)"
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - My Day (check-in + quality/habits)

    private var myDaySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader(title: "My day")

            midDayCheckInCard

            if let today = todayEntry {
                loggedTodayCard(today)
            } else {
                qualityAndHabitsForm

                Button("Save") { saveEntryFromWatch() }
                    .buttonStyle(SomnaPrimaryButtonStyle(color: theme.primaryColor))
                    .padding(.top, DS.Spacing.xs)
            }
        }
    }

    private var qualityAndHabitsForm: some View {
        Group {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Sleep quality")
                    .font(DS.Typography.callout.weight(.semibold))
                    .foregroundStyle(theme.headingColor)
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            quality = star
                            triggerHaptic(style: .light)
                        } label: {
                            Image(systemName: star <= quality ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundStyle(star <= quality ? DS.Metric.streak : theme.mutedTextColor)
                                .scaleEffect(star == quality ? 1.15 : 1)
                                .animation(DS.Motion.bouncy, value: quality)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(star) stars")
                    }
                }
            }
            .somnaCard()

            VStack(spacing: 0) {
                habitToggle("Had caffeine", habit: .caffeine, isOn: $hadCaffeine)
                Divider().overlay(theme.stroke).padding(.leading, 44)
                habitToggle("Screen time before bed", habit: .screen, isOn: $hadScreenBeforeBed)
                Divider().overlay(theme.stroke).padding(.leading, 44)
                habitToggle("Exercised today", habit: .exercise, isOn: $didExercise)
                Divider().overlay(theme.stroke).padding(.leading, 44)
                habitToggle("Had alcohol", habit: .alcohol, isOn: $hadAlcohol)
            }
            .somnaCard(padding: DS.Spacing.sm)
        }
    }

    private func habitToggle(_ title: String, habit: Habit, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: DS.Spacing.sm) {
                IconTile(icon: habit.icon, color: habit.color)
                Text(title)
                    .font(DS.Typography.body)
                    .foregroundStyle(theme.textColor)
            }
        }
        .tint(DS.Metric.readiness)
        .padding(.vertical, 6)
        .sensoryFeedback(.selection, trigger: isOn.wrappedValue)
    }

    private func loggedTodayCard(_ today: SleepEntry) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "checkmark")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(DS.Metric.readiness, in: Circle())
                .scaleEffect(showSaveAnimation ? 1.15 : 1.0)
                .animation(DS.Motion.bouncy, value: showSaveAnimation)

            VStack(alignment: .leading, spacing: 2) {
                Text("Sleep logged")
                    .font(DS.Typography.label)
                    .foregroundStyle(theme.secondaryTextColor)
                Text("\(today.durationInMinutes / 60)h \(today.durationInMinutes % 60)m")
                    .font(DS.Typography.title)
                    .monospacedDigit()
                    .foregroundStyle(theme.headingColor)
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= today.quality ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundStyle(star <= today.quality ? DS.Metric.streak : theme.mutedTextColor)
                    }
                }
            }

            Spacer(minLength: 0)

            Button("Edit") { editTodayEntry(today) }
                .buttonStyle(SomnaSecondaryButtonStyle(color: theme.primaryColor))
        }
        .somnaCard()
    }

    private func recoveryMessageCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "heart.fill")
                .font(.subheadline)
                .foregroundStyle(DS.Metric.heart)
                .frame(width: 32, height: 32)
                .background(DS.Metric.heart.opacity(0.14), in: Circle())
            Text(message)
                .font(DS.Typography.callout)
                .foregroundStyle(theme.textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .somnaCard()
    }

    private var midDayCheckInCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("How are you feeling right now?")
                .font(DS.Typography.callout.weight(.semibold))
                .foregroundStyle(theme.headingColor)

            MoodPicker(selected: hasCheckedInToday ? lastCheckInLevel : nil) { level in
                setMidDayCheckIn(level)
            }

            if let tip = midDayTip {
                Text(tip)
                    .font(DS.Typography.caption)
                    .foregroundStyle(theme.secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .somnaCard()
        .animation(DS.Motion.snappy, value: lastCheckInLevel)
    }

    // MARK: - Renk / etiket yardimcilari

    private func stressLabel(for score: Int) -> String {
        switch score {
        case 0..<20: return "Low"
        case 20..<50: return "Moderate"
        default: return "High"
        }
    }

    private func readinessMessage(for score: Int) -> String {
        switch score {
        case 80...100:
            return "You're well recovered. A great day to push a little harder if you want to."
        case 50..<80:
            return "Moderate readiness. Listen to your body today, especially with intense activity."
        default:
            return "Low readiness. Consider prioritizing rest and lighter activity today."
        }
    }

    private func loadHealthKitScoreIfNeeded() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        guard healthKitScore == nil || lastHealthKitCheckDateString != today else { return }
        lastHealthKitCheckDateString = today
        isSyncing = true

        HealthKitManager.shared.fetchLastNightSleep { samples in
            self.sleepStages = HealthKitManager.shared.calculateSleepStages(from: samples)
            self.sleepSummary = HealthKitManager.shared.summarizeSleep(from: samples)

            let hrvStart = self.sleepSummary?.bedTime ?? Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
            let hrvEnd = self.sleepSummary?.wakeTime ?? Date()

            HealthKitManager.shared.fetchHRVForDateRange(start: hrvStart, end: hrvEnd) { hrv in
                HealthKitManager.shared.fetchRestingHeartRate { rhr in
                    HealthKitManager.shared.fetchAverageRespiratoryRate { respiratoryRate in
                        HealthKitManager.shared.fetchWristTemperature { bodyTemp in
                            HealthKitManager.shared.fetchLatestHeartRate { heartRate, updateDate in
                                let recentEntries = entries.filter { $0.hrv > 0 }.prefix(30)
                                let daysOfHistory = recentEntries.count

                                let recentHRVAverage: Double? = daysOfHistory > 0
                                    ? recentEntries.reduce(0) { $0 + $1.hrv } / Double(daysOfHistory)
                                    : nil

                                let rhrEntries = entries.filter { $0.restingHeartRate > 0 }.prefix(30)
                                let recentRHRAverage: Double? = rhrEntries.count > 0
                                    ? rhrEntries.reduce(0) { $0 + $1.restingHeartRate } / Double(rhrEntries.count)
                                    : nil

                                self.pendingHRV = hrv
                                self.pendingRHR = rhr
                                self.pendingRespiratoryRate = respiratoryRate
                                self.pendingBodyTempDelta = bodyTemp
                                self.pendingHeartRate = heartRate
                                self.lastHeartRateUpdate = updateDate

                                HealthKitManager.shared.fetchCurrentHRV { currentHRVValue in
                                    self.currentHRV = currentHRVValue
                                }

                                HealthKitManager.shared.fetchTodayActiveEnergy { energy in
                                    self.pendingActiveEnergy = energy
                                }

                                HealthKitManager.shared.fetchTodayExerciseMinutes { minutes in
                                    self.pendingExerciseMinutes = minutes
                                }

                                HealthKitManager.shared.fetchTodayAverageHeartRate { avgHR in
                                    self.pendingAvgHeartRate = avgHR
                                }

                                HealthKitManager.shared.fetchTodayStepCount { steps in
                                    self.pendingStepCount = steps
                                }

                                let hrvHistoryForStress = entries.filter { $0.hrv > 0 }.prefix(30)
                                let daysForStress = hrvHistoryForStress.count
                                let hrvAvgForStress: Double? = daysForStress > 0
                                    ? hrvHistoryForStress.reduce(0) { $0 + $1.hrv } / Double(daysForStress)
                                    : nil

                                HealthKitManager.shared.fetchTodayStressHistory(
                                    recentHRVAverage: hrvAvgForStress,
                                    daysOfHistory: daysForStress
                                ) { points in
                                    self.todayStressHistory = points
                                }

                                self.healthKitScore = HealthKitManager.shared.calculateSleepScore(
                                    from: samples,
                                    hrv: hrv,
                                    restingHeartRate: rhr,
                                    recentHRVAverage: recentHRVAverage,
                                    recentRHRAverage: recentRHRAverage,
                                    daysOfHistory: daysOfHistory
                                )

                                withAnimation(.easeOut(duration: 0.3)) {
                                    self.isSyncing = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }

    @ViewBuilder
    private func morningCheckInCard(for entry: SleepEntry) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Morning check-in")
                    .font(DS.Typography.label)
                    .foregroundStyle(theme.primaryColor)
                Text("How are you feeling today?")
                    .font(DS.Typography.headline)
                    .foregroundStyle(theme.headingColor)
            }

            MoodPicker(selected: nil, emojiSize: 28) { level in
                setMorningFeeling(level, for: entry)
            }
        }
        .somnaCard()
    }

    private func setMorningFeeling(_ level: Int, for entry: SleepEntry) {
        entry.morningFeeling = level
        triggerHaptic(style: .light)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func setMidDayCheckIn(_ level: Int) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        lastCheckInDateString = formatter.string(from: Date())
        lastCheckInLevel = level
        triggerHaptic(style: .light)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Save / Edit

    private func saveEntry() {
        let baseStreak = streak

        let entry = SleepEntry(
            date: Date(),
            bedTime: bedTime,
            wakeTime: wakeTime,
            quality: quality,
            hadCaffeine: hadCaffeine,
            hadScreenBeforeBed: hadScreenBeforeBed,
            didExercise: didExercise,
            hadAlcohol: hadAlcohol
        )
        modelContext.insert(entry)
        finishSaving(baseStreak: baseStreak)
    }

    private func saveEntryFromWatch() {
        let baseStreak = streak

        let bedT: Date
        let wakeT: Date

        if let summary = sleepSummary, let result = healthKitScore {
            bedT = summary.bedTime
            wakeT = Calendar.current.date(byAdding: .minute, value: result.timeAsleepMinutes, to: summary.bedTime) ?? summary.wakeTime
        } else {
            bedT = bedTime
            wakeT = wakeTime
        }

        let entry = SleepEntry(
            date: Date(),
            bedTime: bedT,
            wakeTime: wakeT,
            quality: quality,
            hadCaffeine: hadCaffeine,
            hadScreenBeforeBed: hadScreenBeforeBed,
            didExercise: didExercise,
            hadAlcohol: hadAlcohol
        )
        entry.hrv = pendingHRV ?? 0
        entry.restingHeartRate = pendingRHR ?? 0
        entry.remMinutes = sleepStages?.remMinutes ?? 0
        entry.deepMinutes = sleepStages?.deepMinutes ?? 0
        entry.respiratoryRate = pendingRespiratoryRate ?? 0
        entry.bodyTempDelta = pendingBodyTempDelta ?? 0
        entry.sleepScore = healthKitScore?.score ?? 0
        entry.readinessScore = readinessResult?.score ?? 0
        entry.strainScore = strainResult.score
        entry.activeEnergy = pendingActiveEnergy ?? 0
        entry.exerciseMinutes = pendingExerciseMinutes ?? 0
        entry.avgHeartRate = pendingAvgHeartRate ?? 0
        entry.stepCount = pendingStepCount ?? 0
        modelContext.insert(entry)
        finishSaving(baseStreak: baseStreak)
    }

    private func finishSaving(baseStreak: Int) {
        WidgetCenter.shared.reloadAllTimelines()

        let newStreak = baseStreak + 1
        let isMilestone = milestones.contains(newStreak)

        triggerHaptic(style: .medium)
        if soundEnabled {
            AudioServicesPlaySystemSound(1322)
        }

        showSaveAnimation = true
        streakPop = true
        animateStreakCount(to: newStreak)

        confettiIntensity = isMilestone ? .celebration : .subtle
        showConfetti = true

        if isMilestone {
            milestoneMessage = "\(newStreak) days! You're building a habit 🔥"
            if hapticsEnabled {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            streakPop = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (isMilestone ? 2.2 : 1.0)) {
            showConfetti = false
        }

        if isMilestone {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation {
                    milestoneMessage = nil
                }
            }
        }
    }

    private func editTodayEntry(_ entry: SleepEntry) {
        let newDisplayed = max(0, displayedStreak - 1)

        bedTime = entry.bedTime
        wakeTime = entry.wakeTime
        quality = entry.quality
        hadCaffeine = entry.hadCaffeine
        hadScreenBeforeBed = entry.hadScreenBeforeBed
        didExercise = entry.didExercise
        hadAlcohol = entry.hadAlcohol
        modelContext.delete(entry)
        WidgetCenter.shared.reloadAllTimelines()

        displayedStreak = newDisplayed
    }

    private func animateStreakCount(to target: Int) {
        let start = displayedStreak
        guard target > start else {
            displayedStreak = target
            return
        }
        var current = start
        let stepDelay = 0.08
        for step in 1...(target - start) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * stepDelay) {
                current += 1
                displayedStreak = current
            }
        }
    }

    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

#Preview {
    TodayView()
        .environmentObject(ThemeManager())
        .modelContainer(for: [SleepEntry.self, UserProfile.self], inMemory: true)
}
