//
//  SleepEntry.swift
//  SleepApp
//

import Foundation
import SwiftData

@Model
final class SleepEntry {
    var date: Date = Date()
    var bedTime: Date = Date()
    var wakeTime: Date = Date()
    var quality: Int = 3
    var hadCaffeine: Bool = false
    var hadScreenBeforeBed: Bool = false
    var didExercise: Bool = false
    var hadAlcohol: Bool = false
    var morningFeeling: Int = 0
    var hrv: Double = 0
    var restingHeartRate: Double = 0
    var remMinutes: Int = 0
    var deepMinutes: Int = 0
    var respiratoryRate: Double = 0
    var bodyTempDelta: Double = 0
    var sleepScore: Int = 0
    var readinessScore: Int = 0
    var strainScore: Double = 0
    var activeEnergy: Double = 0
    var exerciseMinutes: Double = 0
    var avgHeartRate: Double = 0
    var stepCount: Double = 0

    init(
        date: Date,
        bedTime: Date,
        wakeTime: Date,
        quality: Int,
        hadCaffeine: Bool,
        hadScreenBeforeBed: Bool,
        didExercise: Bool,
        hadAlcohol: Bool
    ) {
        self.date = date
        self.bedTime = bedTime
        self.wakeTime = wakeTime
        self.quality = quality
        self.hadCaffeine = hadCaffeine
        self.hadScreenBeforeBed = hadScreenBeforeBed
        self.didExercise = didExercise
        self.hadAlcohol = hadAlcohol
        self.morningFeeling = 0
        self.hrv = 0
        self.restingHeartRate = 0
        self.remMinutes = 0
        self.deepMinutes = 0
        self.respiratoryRate = 0
        self.bodyTempDelta = 0
        self.sleepScore = 0
        self.readinessScore = 0
        self.strainScore = 0
        self.activeEnergy = 0
        self.exerciseMinutes = 0
        self.avgHeartRate = 0
        self.stepCount = 0
    }

    var durationInMinutes: Int {
        let calendar = Calendar.current
        let bedComponents = calendar.dateComponents([.hour, .minute], from: bedTime)
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: wakeTime)

        let bedMinutes = (bedComponents.hour ?? 0) * 60 + (bedComponents.minute ?? 0)
        var wakeMinutes = (wakeComponents.hour ?? 0) * 60 + (wakeComponents.minute ?? 0)

        if wakeMinutes < bedMinutes {
            wakeMinutes += 24 * 60
        }

        return wakeMinutes - bedMinutes
    }
}
