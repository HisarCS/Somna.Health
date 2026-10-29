//
//  UserProfile.swift
//  SleepApp
//

import Foundation
import SwiftData

@Model
class UserProfile {
    var age: Int = 18
    var gender: String = ""
    var targetSleepMinutes: Int = 480

    init(
        age: Int = 18,
        gender: String = "",
        targetSleepMinutes: Int = 480
    ) {
        self.age = age
        self.gender = gender
        self.targetSleepMinutes = targetSleepMinutes
    }
}
