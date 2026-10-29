//
//  AboutSleepView.swift
//  SleepApp
//

import SwiftUI

struct QuickFact {
    let icon: String
    let text: String
}

struct SleepArticle {
    let icon: String
    let title: String
    let subtitle: String
    let body: String
    let color: Color
    let quickFacts: [QuickFact]
}

struct AboutSleepView: View {
    @EnvironmentObject var themeManager: ThemeManager

    private var articles: [SleepArticle] {
        [
            SleepArticle(
                icon: "moon.zzz.fill",
                title: "The stages of sleep",
                subtitle: "Understand your sleep cycle",
                body: "A typical night cycles through light sleep, deep sleep, and REM sleep roughly every 90 minutes. Deep sleep restores the body; REM sleep supports memory and mood. Most people go through 4-6 full cycles per night.",
                color: Color(red: 0.55, green: 0.4, blue: 1.0),
                quickFacts: [
                    QuickFact(icon: "repeat", text: "~90 min per cycle"),
                    QuickFact(icon: "bolt.fill", text: "REM boosts memory"),
                    QuickFact(icon: "heart.fill", text: "Deep sleep restores body")
                ]
            ),
            SleepArticle(
                icon: "clock.fill",
                title: "How much sleep do you need?",
                subtitle: "It depends on your age",
                body: "Most adults need 7–9 hours per night. Teenagers generally need more, around 8–10 hours, as sleep needs decrease gradually with age. Older adults may function well on slightly less.",
                color: Color(red: 0.3, green: 0.6, blue: 1.0),
                quickFacts: [
                    QuickFact(icon: "person.fill", text: "Adults: 7-9h"),
                    QuickFact(icon: "figure.child", text: "Teens: 8-10h"),
                    QuickFact(icon: "person.fill.turn.down", text: "Older adults: less")
                ]
            ),
            SleepArticle(
                icon: "arrow.triangle.2.circlepath",
                title: "Why consistency matters",
                subtitle: "Same time, every day",
                body: "Going to bed and waking up at the same time every day — even on weekends — helps regulate your body's internal clock and can improve sleep quality over time.",
                color: Color(red: 0.95, green: 0.55, blue: 0.35),
                quickFacts: [
                    QuickFact(icon: "calendar", text: "Even on weekends"),
                    QuickFact(icon: "gauge.with.dots.needle.50percent", text: "Regulates body clock")
                ]
            ),
            SleepArticle(
                icon: "iphone.slash",
                title: "Screens before bed",
                subtitle: "The blue light effect",
                body: "Blue light from phones and screens can delay the release of melatonin, the hormone that signals your body it's time to sleep. Reducing screen time before bed may help you fall asleep faster.",
                color: Color(red: 1.0, green: 0.4, blue: 0.55),
                quickFacts: [
                    QuickFact(icon: "sun.max.fill", text: "Blue light delays melatonin"),
                    QuickFact(icon: "timer", text: "Try 1h screen-free before bed")
                ]
            ),
            SleepArticle(
                icon: "cup.and.saucer.fill",
                title: "Caffeine's long tail",
                subtitle: "It lingers longer than you think",
                body: "Caffeine can stay in your system for 6 hours or more. Even afternoon coffee can affect how easily you fall asleep at night.",
                color: Color(red: 0.75, green: 0.5, blue: 0.3),
                quickFacts: [
                    QuickFact(icon: "hourglass", text: "Half-life: ~5-6h"),
                    QuickFact(icon: "cup.and.saucer", text: "Afternoon coffee counts")
                ]
            ),
            SleepArticle(
                icon: "figure.run",
                title: "Exercise and sleep",
                subtitle: "Movement helps you rest",
                body: "Regular physical activity is linked to falling asleep faster and experiencing deeper sleep — though exercising too close to bedtime can have the opposite effect for some people.",
                color: Color(red: 0.35, green: 0.8, blue: 0.55),
                quickFacts: [
                    QuickFact(icon: "checkmark.circle.fill", text: "Falls asleep faster"),
                    QuickFact(icon: "exclamationmark.triangle.fill", text: "Avoid right before bed")
                ]
            ),
            SleepArticle(
                icon: "thermometer.low",
                title: "Room temperature",
                subtitle: "Cooler is usually better",
                body: "A slightly cool room, around 18-20°C (65-68°F), tends to support better sleep than a warm one. Your body naturally drops in temperature as you fall asleep, and a cool environment supports that process.",
                color: Color(red: 0.3, green: 0.75, blue: 0.85),
                quickFacts: [
                    QuickFact(icon: "thermometer.snowflake", text: "18-20°C ideal"),
                    QuickFact(icon: "arrow.down", text: "Body temp drops naturally")
                ]
            ),
            SleepArticle(
                icon: "fork.knife",
                title: "Late meals and sleep",
                subtitle: "Timing your last meal",
                body: "Eating a large meal close to bedtime can make it harder to fall asleep, as digestion keeps your body active. Finishing dinner a few hours before bed may support smoother sleep onset.",
                color: Color(red: 0.85, green: 0.6, blue: 0.25),
                quickFacts: [
                    QuickFact(icon: "clock.arrow.circlepath", text: "2-3h before bed ideal"),
                    QuickFact(icon: "flame.fill", text: "Digestion stays active")
                ]
            ),
            SleepArticle(
                icon: "sun.horizon.fill",
                title: "Morning light matters too",
                subtitle: "Not just what happens at night",
                body: "Getting natural light exposure soon after waking helps anchor your circadian rhythm, making it easier to feel alert during the day and sleepy at the right time at night.",
                color: Color(red: 1.0, green: 0.65, blue: 0.3),
                quickFacts: [
                    QuickFact(icon: "sunrise.fill", text: "Get light early"),
                    QuickFact(icon: "waveform.path", text: "Anchors circadian rhythm")
                ]
            )
        ]
    }

    var body: some View {
        ZStack {
            themeManager.theme.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Discover")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.theme.headingColor)
                        .padding(.top, 8)

                    Text("General information to help you understand sleep. This isn't medical advice — talk to a professional for personal concerns.")
                        .font(.caption)
                        .foregroundStyle(themeManager.theme.mutedTextColor)

                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                        ForEach(articles, id: \.title) { article in
                            NavigationLink {
                                ArticleDetailView(article: article)
                            } label: {
                                articleCard(article)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("About Sleep")
    }

    private func articleCard(_ article: SleepArticle) -> some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [article.color.opacity(0.85), article.color.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: article.icon)
                .font(.system(size: 90))
                .foregroundStyle(.white.opacity(0.15))
                .rotationEffect(.degrees(-12))
                .offset(x: 90, y: -10)

            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: article.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                Text(article.subtitle.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.85))
                Text(article.title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    ForEach(article.quickFacts.prefix(2), id: \.text) { fact in
                        HStack(spacing: 3) {
                            Image(systemName: fact.icon)
                                .font(.caption2)
                            Text(fact.text)
                                .font(.caption2.bold())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                    }
                }
                .foregroundStyle(.white)
                .padding(.top, 2)
            }
            .padding(20)
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: article.color.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}

struct ArticleDetailView: View {
    let article: SleepArticle
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack {
            themeManager.theme.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [article.color.opacity(0.85), article.color.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        Image(systemName: article.icon)
                            .font(.system(size: 120))
                            .foregroundStyle(.white.opacity(0.15))
                            .rotationEffect(.degrees(-12))
                            .offset(x: 100, y: -10)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(article.subtitle.uppercased())
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.85))
                            Text(article.title)
                                .font(.title.bold())
                                .foregroundStyle(.white)
                        }
                        .padding(24)
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    // Quick facts rozetleri
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(article.quickFacts, id: \.text) { fact in
                            HStack(spacing: 10) {
                                Image(systemName: fact.icon)
                                    .font(.subheadline)
                                    .foregroundStyle(article.color)
                                    .frame(width: 24)
                                Text(fact.text)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(themeManager.theme.textColor)
                            }
                        }
                    }
                    .padding()
                    .background(themeManager.theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text(article.body)
                        .font(.body)
                        .foregroundStyle(themeManager.theme.textColor)
                        .lineSpacing(6)
                        .padding(.horizontal, 4)
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AboutSleepView()
            .environmentObject(ThemeManager())
    }
}
