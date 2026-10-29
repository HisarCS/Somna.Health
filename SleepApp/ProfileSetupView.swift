//
//  ProfileSetupView.swift
//  SleepApp
//

import SwiftUI
import SwiftData

struct ProfileSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var themeManager: ThemeManager

    let onComplete: () -> Void

    @State private var age: Int = 18
    @State private var gender: String = "Not specified"
    @State private var targetHours: Double = 8.0

    private let genderOptions = ["Not specified", "Male", "Female", "Other"]

    var body: some View {
        ZStack {
            themeManager.theme.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Let's set you up")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.theme.headingColor)
                        Text("This helps us tailor suggestions to you. You can always change this later in Settings.")
                            .font(.subheadline)
                            .foregroundStyle(themeManager.theme.secondaryTextColor)
                    }
                    .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 16) {
                        Stepper("Age: \(age)", value: $age, in: 10...100)
                            .foregroundStyle(themeManager.theme.textColor)

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Gender")
                                .font(.subheadline)
                                .foregroundStyle(themeManager.theme.secondaryTextColor)
                            Picker("Gender", selection: $gender) {
                                ForEach(genderOptions, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding()
                    .background(themeManager.theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sleep goal: \(String(format: "%.1f", targetHours))h per night")
                            .font(.subheadline)
                            .foregroundStyle(themeManager.theme.textColor)
                        Slider(value: $targetHours, in: 5...10, step: 0.5)
                            .tint(themeManager.theme.primaryColor)
                    }
                    .padding()
                    .background(themeManager.theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Spacer(minLength: 20)

                    Button {
                        saveProfile()
                    } label: {
                        Text("Save & Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(themeManager.theme.primaryColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
        }
    }

    private func saveProfile() {
        let profile = UserProfile(
            age: age,
            gender: gender == "Not specified" ? "" : gender,
            targetSleepMinutes: Int(targetHours * 60)
        )
        modelContext.insert(profile)
        onComplete()
    }
}

#Preview {
    ProfileSetupView(onComplete: {})
        .environmentObject(ThemeManager())
        .modelContainer(for: [SleepEntry.self, UserProfile.self], inMemory: true)
}
