//
//  HealthKitManager.swift
//  SleepApp
//

import Foundation
import HealthKit

final class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()

    private init() {}

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    struct SleepSummary {
        let bedTime: Date
        let wakeTime: Date
        let durationMinutes: Int
    }

    struct SleepStages {
        let remMinutes: Int
        let deepMinutes: Int
        let coreMinutes: Int
        let awakeMinutes: Int
    }

    struct SleepScoreResult {
        let score: Int
        let timeInBedMinutes: Int
        let timeAsleepMinutes: Int
        let efficiency: Int
        let isCalibrating: Bool
    }

    struct ReadinessResult {
        let score: Int
        let hrv: Double?
        let restingHeartRate: Double?
        let isCalibrating: Bool
    }

    struct StressResult {
        let score: Int
        let hrv: Double?
        let isCalibrating: Bool
    }

    struct StrainResult {
        let score: Double
        let activeEnergy: Double?
        let exerciseMinutes: Double?
        let averageHeartRate: Double?
    }

    struct HourlyStressPoint {
        let time: Date
        let score: Int
    }

    /// Uyku, HRV, RHR, solunum hizi, vucut sicakligi, anlik nabiz ve aktivite icin izin ister
    func requestSleepAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard isHealthDataAvailable else {
            completion(false, nil)
            return
        }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
                      let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
                      let restingHRType = HKObjectType.quantityType(forIdentifier: .restingHeartRate),
                      let respiratoryType = HKObjectType.quantityType(forIdentifier: .respiratoryRate),
                      let bodyTempType = HKObjectType.quantityType(forIdentifier: .bodyTemperature),
                      let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
                      let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
                      let exerciseTimeType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) else {
                    completion(false, nil)
                    return
                }

                var typesToRead: Set<HKObjectType> = [sleepType, hrvType, restingHRType, respiratoryType, bodyTempType, heartRateType, activeEnergyType, exerciseTimeType, HKObjectType.workoutType()]

                if let wristTempType = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
                    typesToRead.insert(wristTempType)
                
                    if let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) {
                                typesToRead.insert(stepType)
                            }
                }

        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }

    /// Son gecenin uyku kayitlarini ceker
    func fetchLastNightSleep(completion: @escaping ([HKCategorySample]) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion([])
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfYesterday = calendar.date(byAdding: .hour, value: -24, to: now) ?? now

        let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let sleepSamples = samples as? [HKCategorySample], error == nil else {
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            DispatchQueue.main.async {
                completion(sleepSamples)
            }
        }

        healthStore.execute(query)
    }

    /// Son 24 saatteki ortalama HRV degerini ceker (medyan, ms cinsinden)
    func fetchAverageHRV(completion: @escaping (Double?) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let startOfYesterday = calendar.date(byAdding: .hour, value: -24, to: now) ?? now
        fetchHRVForDateRange(start: startOfYesterday, end: now, completion: completion)
    }

    /// Belirli bir tarih araligindaki HRV medyanini ceker (aykiri degerlere karsi dayanikli)
    func fetchHRVForDateRange(start: Date, end: Date, completion: @escaping (Double?) -> Void) {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            completion(nil)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let hrvSamples = samples as? [HKQuantitySample], !hrvSamples.isEmpty else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            let values = hrvSamples.map { $0.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)) }
            let sortedValues = values.sorted()
            let count = sortedValues.count
            let median: Double
            if count % 2 == 0 {
                median = (sortedValues[count / 2 - 1] + sortedValues[count / 2]) / 2
            } else {
                median = sortedValues[count / 2]
            }

            DispatchQueue.main.async {
                completion(median)
            }
        }

        healthStore.execute(query)
    }

    /// Stress icin - uyku saatlerinden bagimsiz, son birkac saatin guncel HRV medyani
    func fetchCurrentHRV(completion: @escaping (Double?) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .hour, value: -4, to: now) ?? now
        fetchHRVForDateRange(start: start, end: now, completion: completion)
    }

    /// Son 24 saatteki dinlenme kalp atis hizini ceker (bpm cinsinden)
    func fetchRestingHeartRate(completion: @escaping (Double?) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let startOfYesterday = calendar.date(byAdding: .hour, value: -24, to: now) ?? now
        fetchRestingHeartRateForDateRange(start: startOfYesterday, end: now, completion: completion)
    }

    /// Belirli bir tarih araligindaki dinlenme kalp atis hizini ceker
    func fetchRestingHeartRateForDateRange(start: Date, end: Date, completion: @escaping (Double?) -> Void) {
        guard let rhrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            completion(nil)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(sampleType: rhrType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: HKUnit(from: "count/min"))
            DispatchQueue.main.async {
                completion(value)
            }
        }

        healthStore.execute(query)
    }

    /// En son anlik kalp atis hizi olcumunu ceker (bpm cinsinden)
    func fetchLatestHeartRate(completion: @escaping (Double?, Date?) -> Void) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(nil, nil)
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.date(byAdding: .hour, value: -6, to: now) ?? now

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else {
                DispatchQueue.main.async {
                    completion(nil, nil)
                }
                return
            }
            let value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            DispatchQueue.main.async {
                completion(value, sample.startDate)
            }
        }

        healthStore.execute(query)
    }

    /// Son 24 saatteki ortalama solunum hizini ceker (nefes/dakika)
    func fetchAverageRespiratoryRate(completion: @escaping (Double?) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let startOfYesterday = calendar.date(byAdding: .hour, value: -24, to: now) ?? now
        fetchRespiratoryRateForDateRange(start: startOfYesterday, end: now, completion: completion)
    }

    /// Belirli bir tarih araligindaki ortalama solunum hizini ceker
    func fetchRespiratoryRateForDateRange(start: Date, end: Date, completion: @escaping (Double?) -> Void) {
        guard let respiratoryType = HKObjectType.quantityType(forIdentifier: .respiratoryRate) else {
            completion(nil)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: respiratoryType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
            let average = result?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
            DispatchQueue.main.async {
                completion(average)
            }
        }

        healthStore.execute(query)
    }

    /// Son 24 saatteki vucut sicakligi degisimini ceker (referans noktasina gore fark, Celsius)
    func fetchBodyTemperatureDelta(completion: @escaping (Double?) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let startOfYesterday = calendar.date(byAdding: .hour, value: -24, to: now) ?? now
        fetchBodyTemperatureDeltaForDateRange(start: startOfYesterday, end: now, completion: completion)
    }

    /// Belirli bir tarih araligindaki vucut sicakligi degisimini ceker
    func fetchBodyTemperatureDeltaForDateRange(start: Date, end: Date, completion: @escaping (Double?) -> Void) {
        guard let bodyTempType = HKObjectType.quantityType(forIdentifier: .bodyTemperature) else {
            completion(nil)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: bodyTempType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
            let average = result?.averageQuantity()?.doubleValue(for: HKUnit.degreeCelsius())
            DispatchQueue.main.async {
                completion(average)
            }
        }

        healthStore.execute(query)
    }
    /// Apple Watch'in "sleeping wrist temperature" verisini ceker (Series 8+ ozelligi)
        func fetchWristTemperature(completion: @escaping (Double?) -> Void) {
            guard let wristTempType = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature) else {
                completion(nil)
                return
            }

            let calendar = Calendar.current
            let now = Date()
            let startOfYesterday = calendar.date(byAdding: .hour, value: -24, to: now) ?? now

            let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: now, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let query = HKSampleQuery(sampleType: wristTempType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: HKUnit.degreeCelsius())
                DispatchQueue.main.async {
                    completion(value)
                }
            }

            self.healthStore.execute(query)
        }
    /// Gunun toplam aktif enerji harcamasi (kcal)
    func fetchTodayActiveEnergy(completion: @escaping (Double?) -> Void) {
        guard let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion(nil)
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let now = Date()

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: activeEnergyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let sum = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie())
            DispatchQueue.main.async {
                completion(sum)
            }
        }

        healthStore.execute(query)
    }

    /// Gunun toplam egzersiz dakikasi (Apple'in kendi tanimladigi "Exercise" halkasi)
    func fetchTodayExerciseMinutes(completion: @escaping (Double?) -> Void) {
        guard let exerciseTimeType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) else {
            completion(nil)
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let now = Date()

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: exerciseTimeType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let sum = result?.sumQuantity()?.doubleValue(for: HKUnit.minute())
            DispatchQueue.main.async {
                completion(sum)
            }
        }

        healthStore.execute(query)
    }

    /// Gun boyunca gerceklesen ortalama kalp atis hizi (Strain hesaplamasi icin)
    func fetchTodayAverageHeartRate(completion: @escaping (Double?) -> Void) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(nil)
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let now = Date()

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
            let average = result?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
            DispatchQueue.main.async {
                completion(average)
            }
        }

        healthStore.execute(query)
    }
    
    /// Gunun toplam adim sayisi
        func fetchTodayStepCount(completion: @escaping (Double?) -> Void) {
            guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
                completion(nil)
                return
            }

            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            let now = Date()

            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let sum = result?.sumQuantity()?.doubleValue(for: HKUnit.count())
                DispatchQueue.main.async {
                    completion(sum)
                }
            }

            healthStore.execute(query)
        }
    /// Bugunun 15 dakikalik dilimlere gore Stress gecmisini olusturur (HealthKit'in ham HRV ve nabiz verisinden)
    func fetchTodayStressHistory(
        recentHRVAverage: Double?,
        daysOfHistory: Int,
        completion: @escaping ([HourlyStressPoint]) -> Void
    ) {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion([])
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let now = Date()

        let hrvPredicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        let hrvQuery = HKSampleQuery(sampleType: hrvType, predicate: hrvPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, hrvSamplesRaw, _ in

            let hrPredicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
            let hrQuery = HKSampleQuery(sampleType: heartRateType, predicate: hrPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, hrSamplesRaw, _ in

                let hrvSamples = hrvSamplesRaw as? [HKQuantitySample] ?? []
                let hrSamples = hrSamplesRaw as? [HKQuantitySample] ?? []

                guard !hrvSamples.isEmpty || !hrSamples.isEmpty else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }

                func timeSlot(for date: Date) -> Date {
                    let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                    let minute = (comps.minute ?? 0)
                    let roundedMinute = (minute / 5) * 5
                    var newComps = comps
                    newComps.minute = roundedMinute
                    newComps.second = 0
                    return calendar.date(from: newComps) ?? date
                }

                var hourlyGroups: [Date: [Double]] = [:]
                for sample in hrvSamples {
                    let slot = timeSlot(for: sample.startDate)
                    let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    hourlyGroups[slot, default: []].append(value)
                }

                var hourlyHRGroups: [Date: [Double]] = [:]
                for sample in hrSamples {
                    let slot = timeSlot(for: sample.startDate)
                    let value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    hourlyHRGroups[slot, default: []].append(value)
                }

                self.fetchRestingHeartRate { rhr in
                    var points: [HourlyStressPoint] = []

                    let allSlots = Set(hourlyGroups.keys).union(hourlyHRGroups.keys)

                    for slot in allSlots.sorted() {
                        let hrvValues = hourlyGroups[slot] ?? []
                        let sortedHRV = hrvValues.sorted()
                        let medianHRV = sortedHRV.isEmpty ? nil : sortedHRV[sortedHRV.count / 2]

                        let hrValues = hourlyHRGroups[slot] ?? []
                        let avgHR = hrValues.isEmpty ? nil : hrValues.reduce(0, +) / Double(hrValues.count)

                        guard medianHRV != nil || avgHR != nil else { continue }

                        let result = self.calculateStressScore(
                            hrv: medianHRV,
                            heartRate: avgHR,
                            restingHeartRate: rhr,
                            recentHRVAverage: recentHRVAverage,
                            daysOfHistory: daysOfHistory
                        )

                        points.append(HourlyStressPoint(time: slot, score: result.score))
                    }

                    DispatchQueue.main.async {
                        completion(points.sorted { $0.time < $1.time })
                    }
                }
            }
            self.healthStore.execute(hrQuery)
        }
        healthStore.execute(hrvQuery)
    }

    /// Bugunun 5 dakikalik dilimlere gore Heart Rate gecmisini olusturur
    func fetchTodayHeartRateHistory(completion: @escaping ([HourlyStressPoint]) -> Void) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion([])
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let now = Date()

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samplesRaw, _ in

            let samples = samplesRaw as? [HKQuantitySample] ?? []
            guard !samples.isEmpty else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            func timeSlot(for date: Date) -> Date {
                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                let minute = (comps.minute ?? 0)
                let roundedMinute = (minute / 5) * 5
                var newComps = comps
                newComps.minute = roundedMinute
                newComps.second = 0
                return calendar.date(from: newComps) ?? date
            }

            var groups: [Date: [Double]] = [:]
            for sample in samples {
                let slot = timeSlot(for: sample.startDate)
                let value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                groups[slot, default: []].append(value)
            }

            var points: [HourlyStressPoint] = []
            for slot in groups.keys.sorted() {
                let values = groups[slot] ?? []
                guard !values.isEmpty else { continue }
                let avg = values.reduce(0, +) / Double(values.count)
                points.append(HourlyStressPoint(time: slot, score: Int(avg.rounded())))
            }

            DispatchQueue.main.async {
                completion(points.sorted { $0.time < $1.time })
            }
        }

        self.healthStore.execute(query)
    }

    /// Ham HealthKit orneklerinden, kullanilabilir bir uyku ozeti cikarir
    func summarizeSleep(from samples: [HKCategorySample]) -> SleepSummary? {
        let asleepSamples = samples.filter { sample in
            if #available(iOS 16.0, *) {
                return sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                    || sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                    || sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                    || sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
            } else {
                return sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue
            }
        }

        guard !asleepSamples.isEmpty else { return nil }

        let earliestStart = asleepSamples.map { $0.startDate }.min()
        let latestEnd = asleepSamples.map { $0.endDate }.max()

        guard let bedTime = earliestStart, let wakeTime = latestEnd else { return nil }

        let durationMinutes = Int(wakeTime.timeIntervalSince(bedTime) / 60)

        return SleepSummary(bedTime: bedTime, wakeTime: wakeTime, durationMinutes: durationMinutes)
    }

    /// Uyku evrelerini (REM, Deep, Core, Awake) ayri ayri hesaplar
    func calculateSleepStages(from samples: [HKCategorySample]) -> SleepStages? {
        guard !samples.isEmpty else { return nil }

        var remMinutes = 0
        var deepMinutes = 0
        var coreMinutes = 0
        var awakeMinutes = 0

        for sample in samples {
            let duration = Int(sample.endDate.timeIntervalSince(sample.startDate) / 60)

            if #available(iOS 16.0, *) {
                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    remMinutes += duration
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    deepMinutes += duration
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue, HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    coreMinutes += duration
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    awakeMinutes += duration
                default:
                    break
                }
            } else {
                if sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue {
                    coreMinutes += duration
                } else if sample.value == HKCategoryValueSleepAnalysis.awake.rawValue {
                    awakeMinutes += duration
                }
            }
        }

        guard remMinutes + deepMinutes + coreMinutes > 0 else { return nil }

        return SleepStages(remMinutes: remMinutes, deepMinutes: deepMinutes, coreMinutes: coreMinutes, awakeMinutes: awakeMinutes)
    }

    /// Uyku skorunu hesaplar. Ilk 4 gun genel referanslarla, sonrasinda
    /// kullanicinin kendi HRV/RHR ortalamasina gore kisisellestirilmis sekilde.
    func calculateSleepScore(
        from samples: [HKCategorySample],
        hrv: Double?,
        restingHeartRate: Double?,
        recentHRVAverage: Double?,
        recentRHRAverage: Double?,
        daysOfHistory: Int
    ) -> SleepScoreResult? {
        guard !samples.isEmpty else { return nil }

        let allTimes = samples.map { ($0.startDate, $0.endDate) }
        guard let bedStart = allTimes.map({ $0.0 }).min(),
              let bedEnd = allTimes.map({ $0.1 }).max() else { return nil }

        let timeInBedMinutes = Int(bedEnd.timeIntervalSince(bedStart) / 60)

        let asleepSamples = samples.filter { sample in
            if #available(iOS 16.0, *) {
                return sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                    || sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                    || sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                    || sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
            } else {
                return sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue
            }
        }

        let timeAsleepMinutes = asleepSamples.reduce(0) { total, sample in
            total + Int(sample.endDate.timeIntervalSince(sample.startDate) / 60)
        }

        guard timeInBedMinutes > 0 else { return nil }

        let efficiency = Int((Double(timeAsleepMinutes) / Double(timeInBedMinutes)) * 100)

        let durationScore: Double
        if timeAsleepMinutes >= 420 && timeAsleepMinutes <= 540 {
            durationScore = 100
        } else if timeAsleepMinutes < 420 {
            durationScore = max(0, Double(timeAsleepMinutes) / 420.0 * 100)
        } else {
            let excess = timeAsleepMinutes - 540
            durationScore = max(60, 100 - Double(excess) / 3.0)
        }

        let efficiencyScore = Double(min(efficiency, 100))

        let isCalibrating = daysOfHistory < 4

        let hrvScore: Double
        if let hrvValue = hrv {
            if isCalibrating {
                hrvScore = min(100, max(0, ((hrvValue - 20) / 50) * 100))
            } else if let baseline = recentHRVAverage, baseline > 0 {
                let ratio = hrvValue / baseline
                hrvScore = min(100, max(0, ratio * 75))
            } else {
                hrvScore = min(100, max(0, ((hrvValue - 20) / 50) * 100))
            }
        } else {
            hrvScore = 70
        }

        let rhrScore: Double
        if let rhrValue = restingHeartRate {
            if isCalibrating {
                rhrScore = min(100, max(0, (1 - ((rhrValue - 50) / 30)) * 100))
            } else if let baseline = recentRHRAverage, baseline > 0 {
                let ratio = baseline / rhrValue
                rhrScore = min(100, max(0, ratio * 75))
            } else {
                rhrScore = min(100, max(0, (1 - ((rhrValue - 50) / 30)) * 100))
            }
        } else {
            rhrScore = 70
        }

        let finalScore = Int(
            (durationScore * 0.35) +
            (efficiencyScore * 0.25) +
            (hrvScore * 0.25) +
            (rhrScore * 0.15)
        )

        return SleepScoreResult(
            score: min(max(finalScore, 0), 100),
            timeInBedMinutes: timeInBedMinutes,
            timeAsleepMinutes: timeAsleepMinutes,
            efficiency: efficiency,
            isCalibrating: isCalibrating
        )
    }

    /// Readiness Score: HRV + RHR birlesiminden, vucudun ne kadar hazir oldugunu hesaplar
    func calculateReadinessScore(
        hrv: Double?,
        restingHeartRate: Double?,
        recentHRVAverage: Double?,
        recentRHRAverage: Double?,
        daysOfHistory: Int
    ) -> ReadinessResult {
        let isCalibrating = daysOfHistory < 4

        let hrvScore: Double
        if let hrvValue = hrv {
            if isCalibrating {
                hrvScore = min(100, max(0, ((hrvValue - 20) / 50) * 100))
            } else if let baseline = recentHRVAverage, baseline > 0 {
                hrvScore = min(100, max(0, (hrvValue / baseline) * 75))
            } else {
                hrvScore = min(100, max(0, ((hrvValue - 20) / 50) * 100))
            }
        } else {
            hrvScore = 70
        }

        let rhrScore: Double
        if let rhrValue = restingHeartRate {
            if isCalibrating {
                rhrScore = min(100, max(0, (1 - ((rhrValue - 50) / 30)) * 100))
            } else if let baseline = recentRHRAverage, baseline > 0 {
                rhrScore = min(100, max(0, (baseline / rhrValue) * 75))
            } else {
                rhrScore = min(100, max(0, (1 - ((rhrValue - 50) / 30)) * 100))
            }
        } else {
            rhrScore = 70
        }

        let finalScore = Int((hrvScore * 0.6) + (rhrScore * 0.4))

        return ReadinessResult(
            score: min(max(finalScore, 0), 100),
            hrv: hrv,
            restingHeartRate: restingHeartRate,
            isCalibrating: isCalibrating
        )
    }

    /// Stress Score: HRV (%65) ve BPM'in dinlenme degerinden sapmasi (%35) birlikte kullanilir.
    /// YUKSEK skor = YUKSEK stres.
    func calculateStressScore(
        hrv: Double?,
        heartRate: Double?,
        restingHeartRate: Double?,
        recentHRVAverage: Double?,
        daysOfHistory: Int
    ) -> StressResult {
        let isCalibrating = daysOfHistory < 4

        let hrvCalmScore: Double
        if let hrvValue = hrv {
            if isCalibrating {
                hrvCalmScore = min(100, max(0, ((hrvValue - 20) / 50) * 100))
            } else if let baseline = recentHRVAverage, baseline > 0 {
                hrvCalmScore = min(100, max(0, (hrvValue / baseline) * 75))
            } else {
                hrvCalmScore = min(100, max(0, ((hrvValue - 20) / 50) * 100))
            }
        } else {
            hrvCalmScore = 70
        }

        let bpmCalmScore: Double
        if let hr = heartRate, let rhr = restingHeartRate, rhr > 0 {
            let elevation = max(0, hr - rhr)
            bpmCalmScore = min(100, max(0, 100 - (elevation * 3)))
        } else {
            bpmCalmScore = 70
        }

        let calmScore = (hrvCalmScore * 0.65) + (bpmCalmScore * 0.35)
        let stressScore = 100 - calmScore

        return StressResult(
            score: Int(min(max(stressScore, 0), 100)),
            hrv: hrv,
            isCalibrating: isCalibrating
        )
    }

    /// Strain: gunun ne kadar fiziksel olarak zorlayici gectigini 0-21 skalasinda hesaplar
    func calculateStrainScore(
        activeEnergy: Double?,
        exerciseMinutes: Double?,
        averageHeartRate: Double?,
        restingHeartRate: Double?
    ) -> StrainResult {
        let energyScore = min(100, max(0, (activeEnergy ?? 0) / 6.0))
        let exerciseScore = min(100, max(0, (exerciseMinutes ?? 0) / 0.6))

        let heartRateLoadScore: Double
        if let avgHR = averageHeartRate, let restHR = restingHeartRate, restHR > 0 {
            let elevation = max(0, avgHR - restHR)
            heartRateLoadScore = min(100, elevation * 2.5)
        } else {
            heartRateLoadScore = 0
        }

        let combined = (energyScore * 0.35) + (exerciseScore * 0.35) + (heartRateLoadScore * 0.3)
        let strainScale = (combined / 100.0) * 21.0

        return StrainResult(
            score: min(21, max(0, strainScale)),
            activeEnergy: activeEnergy,
            exerciseMinutes: exerciseMinutes,
            averageHeartRate: averageHeartRate
        )
    }
}
