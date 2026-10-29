//
//  ProfileView.swift
//  SleepApp
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var themeManager: ThemeManager
    @Query private var profiles: [UserProfile]

    @State private var age: Int = 18
    @State private var gender: String = ""
    @State private var targetHours: Double = 8.0

    private let genderOptions = ["Not specified", "Male", "Female", "Other"]

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.theme.backgroundGradient
                    .ignoresSafeArea()

                Form {
                    Section {
                        Stepper("Age: \(age)", value: $age, in: 10...100)
                            .foregroundStyle(themeManager.theme.textColor)

                        Picker("Gender", selection: $gender) {
                            ForEach(genderOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .foregroundStyle(themeManager.theme.textColor)
                    } header: {
                        Text("About you")
                            .foregroundStyle(themeManager.theme.secondaryTextColor)
                    }
                    .listRowBackground(themeManager.theme.cardBackground)

                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Target sleep: \(String(format: "%.1f", targetHours))h")
                                .foregroundStyle(themeManager.theme.textColor)
                            Slider(value: $targetHours, in: 5...10, step: 0.5)
                                .tint(themeManager.theme.primaryColor)
                        }
                    } header: {
                        Text("Sleep goal")
                            .foregroundStyle(themeManager.theme.secondaryTextColor)
                    }
                    .listRowBackground(themeManager.theme.cardBackground)

                    Section {
                        Button("Save") {
                            saveProfile()
                        }
                        .foregroundStyle(themeManager.theme.primaryColor)
                        .fontWeight(.semibold)
                    }
                    .listRowBackground(themeManager.theme.cardBackground)
                }
                .scrollContentBackground(.hidden)
            }
     
            .navigationTitle("Profile")
            
            .toolbarColorScheme(themeManager.theme.icon == "moon.stars.fill" ? .dark : .light, for: .navigationBar)
            
            
            .onAppear {
                themeManager.refresh()
                loadProfile()
            }
        }
    }

    private func loadProfile() {
        if let existing = profiles.first {
            age = existing.age
            gender = existing.gender.isEmpty ? "Not specified" : existing.gender
            targetHours = Double(existing.targetSleepMinutes) / 60.0
        } else {
            gender = "Not specified"
        }
    }

    private func saveProfile() {
        if let existing = profiles.first {
            existing.age = age
            existing.gender = gender
            existing.targetSleepMinutes = Int(targetHours * 60)
        } else {
            let newProfile = UserProfile(
                age: age,
                gender: gender,
                targetSleepMinutes: Int(targetHours * 60)
            )
            modelContext.insert(newProfile)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(ThemeManager())
        .modelContainer(for: [SleepEntry.self, UserProfile.self], inMemory: true)
}
