//
//  HistoryView.swift
//  SleepApp
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var themeManager: ThemeManager
    @Query(sort: \SleepEntry.date, order: .reverse) private var entries: [SleepEntry]

    @State private var editingEntry: SleepEntry? = nil

    var body: some View {
        ZStack {
            themeManager.theme.backgroundGradient
                .ignoresSafeArea()

            if entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(themeManager.theme.mutedTextColor)
                    Text("No entries yet")
                        .font(.headline)
                        .foregroundStyle(themeManager.theme.headingColor)
                    Text("Days you log will show up here.")
                        .font(.subheadline)
                        .foregroundStyle(themeManager.theme.secondaryTextColor)
                }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(entries) { entry in
                            Button {
                                editingEntry = entry
                            } label: {
                                historyRow(entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("History")
        .sheet(item: $editingEntry) { entry in
            EditEntrySheet(entry: entry)
                .environmentObject(themeManager)
        }
        .onAppear {
            themeManager.refresh()
        }
    }

    private func historyRow(_ entry: SleepEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.subheadline.bold())
                    .foregroundStyle(themeManager.theme.headingColor)
                Text("\(entry.durationInMinutes / 60)h \(entry.durationInMinutes % 60)m")
                    .font(.caption)
                    .foregroundStyle(themeManager.theme.secondaryTextColor)
            }

            Spacer()

            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= entry.quality ? "star.fill" : "star")
                        .font(.caption2)
                        .foregroundStyle(themeManager.theme.secondaryColor)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(themeManager.theme.mutedTextColor)
                .padding(.leading, 8)
        }
        .padding()
        .background(themeManager.theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EditEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    @Bindable var entry: SleepEntry

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.theme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(entry.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(.title3.bold())
                            .foregroundStyle(themeManager.theme.headingColor)

                        VStack(alignment: .leading, spacing: 12) {
                            DatePicker("Bedtime", selection: $entry.bedTime, displayedComponents: .hourAndMinute)
                                .foregroundStyle(themeManager.theme.textColor)
                            DatePicker("Wake time", selection: $entry.wakeTime, displayedComponents: .hourAndMinute)
                                .foregroundStyle(themeManager.theme.textColor)
                        }
                        .tint(themeManager.theme.primaryColor)
                        .padding()
                        .background(themeManager.theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sleep quality")
                                .font(.subheadline)
                                .foregroundStyle(themeManager.theme.secondaryTextColor)
                            HStack {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= entry.quality ? "star.fill" : "star")
                                        .foregroundStyle(themeManager.theme.secondaryColor)
                                        .font(.title2)
                                        .onTapGesture { entry.quality = star }
                                }
                            }
                        }
                        .padding()
                        .background(themeManager.theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(spacing: 0) {
                            Toggle("Had caffeine", isOn: $entry.hadCaffeine)
                                .foregroundStyle(themeManager.theme.textColor)
                            Divider()
                            Toggle("Screen time before bed", isOn: $entry.hadScreenBeforeBed)
                                .foregroundStyle(themeManager.theme.textColor)
                            Divider()
                            Toggle("Exercised today", isOn: $entry.didExercise)
                                .foregroundStyle(themeManager.theme.textColor)
                            Divider()
                            Toggle("Had alcohol", isOn: $entry.hadAlcohol)
                                .foregroundStyle(themeManager.theme.textColor)
                        }
                        .tint(themeManager.theme.primaryColor)
                        .padding()
                        .background(themeManager.theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button(role: .destructive) {
                            modelContext.delete(entry)
                            dismiss()
                        } label: {
                            Text("Delete entry")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.15))
                                .foregroundStyle(.red)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .environmentObject(ThemeManager())
            .modelContainer(for: [SleepEntry.self, UserProfile.self], inMemory: true)
    }
}
