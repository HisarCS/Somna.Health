//
//  SomnaWidget.swift
//  SomnaWidget
//

import WidgetKit
import SwiftUI
import SwiftData

struct SomnaEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let bearImageName: String
    let caption: String
    let isDaytime: Bool
    let sunMoonProgress: Double
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SomnaEntry {
        SomnaEntry(date: Date(), streak: 0, bearImageName: "bear_energetic", caption: "Let's go!", isDaytime: true, sunMoonProgress: 0.5)
    }

    func getSnapshot(in context: Context, completion: @escaping (SomnaEntry) -> ()) {
        completion(makeEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SomnaEntry>) -> ()) {
        var entries: [SomnaEntry] = []
        let currentDate = Date()

        for hourOffset in 0..<6 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate) ?? currentDate
            entries.append(makeEntry(for: entryDate))
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }

    private func makeEntry(for date: Date) -> SomnaEntry {
        let hour = Calendar.current.component(.hour, from: date)
        let minute = Calendar.current.component(.minute, from: date)
        let isDaytime = hour >= 6 && hour < 20

        let progress: Double
        if isDaytime {
            let totalMinutes = Double((hour - 6) * 60 + minute)
            progress = totalMinutes / (14 * 60)
        } else {
            let nightHour = hour >= 20 ? hour - 20 : hour + 4
            let totalMinutes = Double(nightHour * 60 + minute)
            progress = totalMinutes / (10 * 60)
        }

        let (streak, hasLoggedToday, morningFeeling, midDayLevel) = fetchData()
        let bearImageName = determineBearImage(hour: hour, hasLoggedToday: hasLoggedToday, morningFeeling: morningFeeling, midDayLevel: midDayLevel)
        let caption = randomCaption(for: bearImageName)
        return SomnaEntry(date: date, streak: streak, bearImageName: bearImageName, caption: caption, isDaytime: isDaytime, sunMoonProgress: progress)
    }

    private func determineBearImage(hour: Int, hasLoggedToday: Bool, morningFeeling: Int, midDayLevel: Int) -> String {
        switch hour {
        case 22, 23, 0, 1, 2, 3, 4, 5:
            return "bear_sleeping"
        case 6, 7, 8:
            return "bear_wokeUp"
        case 9, 10, 11, 12:
            return bearForCheckIn(level: morningFeeling)
        case 13, 14, 15, 16:
            return bearForCheckIn(level: midDayLevel)
        case 17, 18, 19, 20:
            if midDayLevel == 0 {
                return "bear_sad"
            }
            return bearForCheckIn(level: midDayLevel)
        case 21:
            if midDayLevel == 0 {
                return "bear_angry"
            }
            return "bear_readyToSleep"
        default:
            return "bear_notr"
        }
    }

    private func bearForCheckIn(level: Int) -> String {
        switch level {
        case 1: return "bear_lowEnergy"
        case 2: return "bear_tired"
        case 3: return "bear_notr"
        case 4, 5: return "bear_energetic"
        default: return "bear_notr"
        }
    }

    private func randomCaption(for bearImageName: String) -> String {
        let captions: [String: [String]] = [
            "bear_sleeping": ["Zzz... don't wake me.", "Living my best life right now.", "This is the good part."],
            "bear_wokeUp": ["Coffee first. Questions later.", "I have awoken.", "Send help. And caffeine."],
            "bear_lowEnergy": ["I am but a shell of myself.", "Running on 2% battery.", "Everything hurts."],
            "bear_tired": ["Could use a nap. Or ten.", "Functioning, technically.", "Ask me later."],
            "bear_notr": ["It's a day. Things are happening.", "Steady as she goes.", "Neither here nor there."],
            "bear_energetic": ["Unstoppable today!", "Let's go! ⚡️", "Best sleep, best day."],
            "bear_sad": ["You forgot about me...", "We haven't talked today 🥺", "I miss our check-ins."],
            "bear_angry": ["Your streak is on thin ice.", "We need to talk. NOW.", "So has your streak."],
            "bear_readyToSleep": ["Time to wind down.", "Almost bedtime, friend.", "Getting cozy soon."]
        ]
        return captions[bearImageName]?.randomElement() ?? "..."
    }

    private func fetchData() -> (streak: Int, hasLoggedToday: Bool, morningFeeling: Int, midDayLevel: Int) {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.azizozdemir.somna2026") else {
            return (0, false, 0, 0)
        }
        let storeURL = groupURL.appendingPathComponent("SomnaData.sqlite")

        var streak = 0
        var hasLoggedToday = false
        var morningFeeling = 0

        do {
            let schema = Schema([SleepEntry.self, UserProfile.self])
            let config = ModelConfiguration(schema: schema, url: storeURL)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<SleepEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            let entries = try context.fetch(descriptor)
            hasLoggedToday = entries.contains { Calendar.current.isDateInToday($0.date) }
            streak = calculateStreak(from: entries)
            morningFeeling = entries.first(where: { $0.morningFeeling > 0 })?.morningFeeling ?? 0
        } catch {
            // varsayilanlarla devam
        }

        let midDayLevel = readMidDayCheckInLevel()
        return (streak, hasLoggedToday, morningFeeling, midDayLevel)
    }

    private func readMidDayCheckInLevel() -> Int {
        let defaults = UserDefaults(suiteName: "group.com.azizozdemir.somna2026") ?? UserDefaults.standard
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        let lastCheckInDate = defaults.string(forKey: "lastCheckInDate") ?? ""
        guard lastCheckInDate == todayString else { return 0 }
        return defaults.integer(forKey: "lastCheckInLevel")
    }

    private func calculateStreak(from entries: [SleepEntry]) -> Int {
        guard !entries.isEmpty else { return 0 }
        let calendar = Calendar.current
        let todayEntry = entries.first { calendar.isDateInToday($0.date) }
        var count = 0
        var dayToCheck = calendar.startOfDay(for: Date())
        if todayEntry == nil {
            dayToCheck = calendar.date(byAdding: .day, value: -1, to: dayToCheck) ?? dayToCheck
        }
        while true {
            let hasEntry = entries.contains { calendar.isDate($0.date, inSameDayAs: dayToCheck) }
            if hasEntry {
                count += 1
                dayToCheck = calendar.date(byAdding: .day, value: -1, to: dayToCheck) ?? dayToCheck
            } else {
                break
            }
        }
        return count
    }
}

// MARK: - Gokyuzu: uygulamadaki Today ekrani gibi siyah
// Gece yildizlar + bu gecenin gercek ay evresi, gunduz saate gore kayan hafif gunes isigi.

private enum WidgetSky {
    /// 0 yeni ay, 0.5 dolunay. Yaklasik 1 gun hassasiyet.
    static func moonPhase(_ date: Date) -> Double {
        let knownNewMoon = Date(timeIntervalSince1970: 947_182_440)   // 6 Ocak 2000, 18:14 UTC
        let p = (date.timeIntervalSince(knownNewMoon) / 86_400 / 29.530588853).truncatingRemainder(dividingBy: 1)
        return p < 0 ? p + 1 : p
    }

    static let stars: [(x: CGFloat, y: CGFloat, r: CGFloat, a: Double)] = [
        (0.08, 0.10, 1.6, 0.9), (0.22, 0.05, 1.2, 0.6), (0.35, 0.16, 1.4, 0.7), (0.48, 0.07, 1.0, 0.5),
        (0.62, 0.13, 1.5, 0.8), (0.70, 0.04, 1.0, 0.5), (0.88, 0.18, 1.2, 0.6), (0.15, 0.27, 1.0, 0.4),
        (0.42, 0.30, 1.1, 0.45), (0.55, 0.24, 0.9, 0.4), (0.95, 0.30, 1.0, 0.45), (0.28, 0.38, 0.9, 0.35),
        (0.05, 0.45, 1.0, 0.35), (0.78, 0.40, 0.9, 0.3), (0.66, 0.33, 1.3, 0.5), (0.92, 0.08, 1.4, 0.7),
    ]
}

struct WidgetSkyBackground: View {
    let entry: SomnaEntry

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                if entry.isDaytime {
                    // gunes isigi: sabah solda, aksam sagda (sunMoonProgress 0...1)
                    let p = entry.sunMoonProgress
                    let low = 1 - sin(Double.pi * p)
                    let warm = Color(red: 1.0, green: 0.96 - 0.14 * low, blue: 0.88 - 0.30 * low)
                    RadialGradient(colors: [warm.opacity(0.24), warm.opacity(0)],
                                   center: UnitPoint(x: -0.1 + 1.2 * p, y: 0.0),
                                   startRadius: 0, endRadius: max(geo.size.width, geo.size.height) * 0.8)
                } else {
                    ForEach(0..<WidgetSky.stars.count, id: \.self) { i in
                        let s = WidgetSky.stars[i]
                        Circle()
                            .fill(Color.white.opacity(s.a))
                            .frame(width: s.r * 2, height: s.r * 2)
                            .position(x: geo.size.width * s.x, y: geo.size.height * s.y)
                    }
                }
            }
        }
    }
}

/// Gece: bu gecenin gercek ay evresi. Gunduz: gunes yok (isik zeminde).
struct SunMoonView: View {
    let entry: SomnaEntry
    var iconSize: CGFloat = 20
    var glowSize: CGFloat = 36

    var body: some View {
        if !entry.isDaytime {
            let radius = iconSize * 0.35
            let phase = WidgetSky.moonPhase(entry.date)
            let lit = (1 - cos(2 * Double.pi * phase)) / 2
            let cream = Color(red: 0.96, green: 0.93, blue: 0.84)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [cream.opacity(0.3 * lit), cream.opacity(0)],
                                         center: .center, startRadius: radius, endRadius: glowSize * 0.6))
                    .frame(width: glowSize * 1.2, height: glowSize * 1.2)
                Circle().fill(Color.white.opacity(0.07)).frame(width: radius * 2, height: radius * 2)
                WidgetMoonLit(phase: phase).fill(cream).frame(width: radius * 2, height: radius * 2)
            }
        }
    }
}

/// Ayin aydinlik kismi (kuzey yarim kure: buyurken sag, kuculurken sol)
private struct WidgetMoonLit: Shape {
    let phase: Double

    func path(in rect: CGRect) -> Path {
        let r = Double(min(rect.width, rect.height) / 2)
        let cx = Double(rect.midX), cy = Double(rect.midY)
        let side: Double = phase < 0.5 ? 1 : -1
        let c = cos(2 * Double.pi * phase)
        let n = 32
        var p = Path()
        for i in 0...n {
            let t = Double.pi * Double(i) / Double(n)
            let pt = CGPoint(x: cx + side * sin(t) * r, y: cy - cos(t) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        for i in 0...n {
            let t = Double.pi * (1 - Double(i) / Double(n))
            p.addLine(to: CGPoint(x: cx + side * c * sin(t) * r, y: cy - cos(t) * r))
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Ana yonlendirici

struct SomnaWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumBearWidgetView(entry: entry)
        default:
            SmallBearWidgetView(entry: entry)
        }
    }
}

// MARK: - Small boyut

struct SmallBearWidgetView: View {
    let entry: Provider.Entry

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SunMoonView(entry: entry)
                    .position(
                        x: geo.size.width * (0.2 + entry.sunMoonProgress * 0.65),
                        y: geo.size.height * (0.22 - sin(entry.sunMoonProgress * .pi) * 0.12)
                    )

                // Avatar: Wisp damlasi (duyguya gore renk)
                WidgetWispView(mood: WidgetWispMood(bearImageName: entry.bearImageName),
                               size: geo.size.width * 0.58)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.66)

                VStack(spacing: -4) {
                    HStack {
                        streakBadge
                            .padding(.leading, -10)
                        Spacer()
                    }
                    HStack {
                        Spacer()
                        captionText
                            .padding(.trailing, -25)
                            .padding(.top, -10)
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.top, -6)
            }
        }
        .containerBackground(for: .widget) {
            WidgetSkyBackground(entry: entry)
        }
    }

    private var streakBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
            Text("\(entry.streak)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.1))
        .clipShape(Capsule())
    }

    private var captionText: some View {
        Text(entry.caption)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 12)
            .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Medium boyut

struct MediumBearWidgetView: View {
    let entry: Provider.Entry

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SunMoonView(entry: entry, iconSize: 22, glowSize: 40)
                    .position(
                        x: geo.size.width * (0.55 + entry.sunMoonProgress * 0.4),
                        y: geo.size.height * (0.25 - sin(entry.sunMoonProgress * .pi) * 0.15)
                    )

                // Avatar: Wisp damlasi (duyguya gore renk)
                WidgetWispView(mood: WidgetWispMood(bearImageName: entry.bearImageName),
                               size: geo.size.height * 0.68)
                    .position(x: geo.size.height * 0.5, y: geo.size.height * 0.55)

                HStack {
                    Spacer()
                        .frame(width: geo.size.height * 0.9)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.orange)
                            Text("\(entry.streak)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())

                        Text(entry.caption)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

                        Spacer()
                    }
                    .padding(.top, 12)

                    Spacer()
                }
            }
        }
        .containerBackground(for: .widget) {
            WidgetSkyBackground(entry: entry)
        }
    }
}

struct SomnaWidget: Widget {
    let kind: String = "SomnaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SomnaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Somna")
        .description("See your sleep streak and your bear's mood.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    SomnaWidget()
} timeline: {
    SomnaEntry(date: .now, streak: 12, bearImageName: "bear_energetic", caption: "Let's go! ⚡️", isDaytime: true, sunMoonProgress: 0.5)
    SomnaEntry(date: .now, streak: 0, bearImageName: "bear_sleeping", caption: "Zzz.", isDaytime: false, sunMoonProgress: 0.3)
}

#Preview(as: .systemMedium) {
    SomnaWidget()
} timeline: {
    SomnaEntry(date: .now, streak: 12, bearImageName: "bear_energetic", caption: "Let's go! ⚡️", isDaytime: true, sunMoonProgress: 0.5)
}
