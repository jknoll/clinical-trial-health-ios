import Foundation
import HealthKit

/// Manages HealthKit authorization and data queries for clinical trial health data.
@Observable
final class HealthKitManager {
    private let store = HKHealthStore()

    var stepAverage: Double?
    var activeMinutesAverage: Double?
    var latestWeight: Double?       // lbs
    var latestHeight: Double?       // inches
    var latestBMI: Double?
    var latestHeartRate: Double?    // bpm
    var latestBPSystolic: Double?   // mmHg
    var latestBPDiastolic: Double?  // mmHg
    var latestTemperature: Double?
    var latestRespiratoryRate: Double?
    var latestOxygenSaturation: Double?
    var latestBloodGlucose: Double?
    var latestVO2Max: Double?
    var labResults: [LabResult] = []
    var medications: [MedicationRecord] = []

    var isAuthorized = false
    var authError: String?

    // MARK: - Types to read

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.bodyMass),
            HKQuantityType(.height),
            HKQuantityType(.bodyMassIndex),
            HKQuantityType(.heartRate),
            HKQuantityType(.bloodPressureSystolic),
            HKQuantityType(.bloodPressureDiastolic),
            HKQuantityType(.bodyTemperature),
            HKQuantityType(.respiratoryRate),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.bloodGlucose),
            HKQuantityType(.vo2Max),
        ]
        // Clinical record types (requires health-records entitlement)
        if let labType = HKClinicalType(.labResultRecord) as? HKObjectType {
            types.insert(labType)
        }
        if let medType = HKClinicalType(.medicationRecord) as? HKObjectType {
            types.insert(medType)
        }
        if let condType = HKClinicalType(.conditionRecord) as? HKObjectType {
            types.insert(condType)
        }
        return types
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authError = "HealthKit is not available on this device."
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
        } catch {
            authError = error.localizedDescription
        }
    }

    // MARK: - Fetch all data

    func fetchAll() async {
        async let steps: () = fetchStepAverage()
        async let active: () = fetchActiveMinutes()
        async let vitals: () = fetchLatestVitals()
        async let clinical: () = fetchClinicalRecords()
        _ = await (steps, active, vitals, clinical)
    }

    // MARK: - Step average (30-day)

    func fetchStepAverage() async {
        let type = HKQuantityType(.stepCount)
        let now = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -30, to: now) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: now)
        let interval = DateComponents(day: 1)

        stepAverage = await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: Calendar.current.startOfDay(for: start),
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                guard let results else {
                    continuation.resume(returning: nil)
                    return
                }
                var total = 0.0
                var days = 0
                results.enumerateStatistics(from: start, to: now) { stats, _ in
                    if let sum = stats.sumQuantity() {
                        total += sum.doubleValue(for: .count())
                        days += 1
                    }
                }
                let avg = days > 0 ? total / Double(days) : nil
                continuation.resume(returning: avg)
            }
            store.execute(query)
        }
    }

    // MARK: - Active minutes average (30-day)

    func fetchActiveMinutes() async {
        let type = HKQuantityType(.appleExerciseTime)
        let now = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -30, to: now) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: now)
        let interval = DateComponents(day: 1)

        activeMinutesAverage = await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: Calendar.current.startOfDay(for: start),
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                guard let results else {
                    continuation.resume(returning: nil)
                    return
                }
                var total = 0.0
                var days = 0
                results.enumerateStatistics(from: start, to: now) { stats, _ in
                    if let sum = stats.sumQuantity() {
                        total += sum.doubleValue(for: .minute())
                        days += 1
                    }
                }
                let avg = days > 0 ? total / Double(days) : nil
                continuation.resume(returning: avg)
            }
            store.execute(query)
        }
    }

    // MARK: - Latest vitals

    func fetchLatestVitals() async {
        async let w: Double? = fetchLatestQuantity(.bodyMass, unit: .pound())
        async let h: Double? = fetchLatestQuantity(.height, unit: .inch())
        async let bmi: Double? = fetchLatestQuantity(.bodyMassIndex, unit: .count())
        async let hr: Double? = fetchLatestQuantity(.heartRate, unit: .count().unitDivided(by: .minute()))
        async let sys: Double? = fetchLatestQuantity(.bloodPressureSystolic, unit: .millimeterOfMercury())
        async let dia: Double? = fetchLatestQuantity(.bloodPressureDiastolic, unit: .millimeterOfMercury())
        async let temp: Double? = fetchLatestQuantity(.bodyTemperature, unit: .degreeFahrenheit())
        async let rr: Double? = fetchLatestQuantity(.respiratoryRate, unit: .count().unitDivided(by: .minute()))
        async let spo2: Double? = fetchLatestQuantity(.oxygenSaturation, unit: .percent())
        async let glucose: Double? = fetchLatestQuantity(.bloodGlucose, unit: .gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci)))
        async let vo2: Double? = fetchLatestQuantity(.vo2Max, unit: HKUnit(from: "mL/kg*min"))

        latestWeight = await w
        latestHeight = await h
        latestBMI = await bmi
        latestHeartRate = await hr
        latestBPSystolic = await sys
        latestBPDiastolic = await dia
        latestTemperature = await temp
        latestRespiratoryRate = await rr
        latestOxygenSaturation = await spo2
        latestBloodGlucose = await glucose
        latestVO2Max = await vo2
    }

    private func fetchLatestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let type = HKQuantityType(identifier)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    // MARK: - Clinical records (FHIR)

    func fetchClinicalRecords() async {
        labResults = await fetchClinicalType(.labResultRecord)
        medications = await fetchMedications()
    }

    private func fetchClinicalType(_ identifier: HKClinicalTypeIdentifier) async -> [LabResult] {
        guard let type = HKClinicalType(identifier) as? HKSampleType else { return [] }

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let results = (samples as? [HKClinicalRecord])?.compactMap { record -> LabResult? in
                    guard let fhir = record.fhirResource,
                          let json = try? JSONSerialization.jsonObject(with: fhir.data) as? [String: Any] else {
                        return nil
                    }
                    let name = record.displayName
                    // Attempt to extract value from FHIR Observation
                    let valueQuantity = json["valueQuantity"] as? [String: Any]
                    let value = valueQuantity?["value"] as? Double ?? 0
                    let unit = valueQuantity?["unit"] as? String ?? ""
                    let dateStr = json["effectiveDateTime"] as? String ?? ""
                    return LabResult(testName: name, value: value, unit: unit, date: dateStr, source: "HealthKit-FHIR")
                } ?? []
                continuation.resume(returning: results)
            }
            store.execute(query)
        }
    }

    private func fetchMedications() async -> [MedicationRecord] {
        guard let type = HKClinicalType(.medicationRecord) as? HKSampleType else { return [] }

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let results = (samples as? [HKClinicalRecord])?.compactMap { record -> MedicationRecord? in
                    guard let fhir = record.fhirResource,
                          let json = try? JSONSerialization.jsonObject(with: fhir.data) as? [String: Any] else {
                        return nil
                    }
                    let name = record.displayName
                    let status = json["status"] as? String ?? ""
                    let dateStr = json["authoredOn"] as? String ?? ""
                    return MedicationRecord(name: name, dose: "", frequency: "", startDate: dateStr, endDate: "", isActive: status == "active")
                } ?? []
                continuation.resume(returning: results)
            }
            store.execute(query)
        }
    }

    // MARK: - Seed sample data (DEBUG only)

    #if DEBUG
    func seedSampleData() async throws {
        let now = Date()
        let calendar = Calendar.current
        let restDays: Set<Int> = [5, 12, 22]

        // Step count & exercise time for 30 days with realistic variation
        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let start = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .hour, value: 12, to: start) else { continue }

            // Steps: rest/illness days get 500-1500, normal days get 3000-8500
            let steps = restDays.contains(dayOffset)
                ? Double.random(in: 500...1500)
                : Double.random(in: 3000...8500)
            let stepSample = HKQuantitySample(
                type: HKQuantityType(.stepCount),
                quantity: HKQuantity(unit: .count(), doubleValue: steps),
                start: start, end: end
            )
            try await store.save(stepSample)

            // Exercise time: 10-50 min/day for more variation
            let exerciseMin = Double.random(in: 10...50)
            let exerciseSample = HKQuantitySample(
                type: HKQuantityType(.appleExerciseTime),
                quantity: HKQuantity(unit: .minute(), doubleValue: exerciseMin),
                start: start, end: end
            )
            try await store.save(exerciseSample)
        }

        // Vitals (single most-recent samples)
        let vitals: [(HKQuantityTypeIdentifier, Double, HKUnit)] = [
            (.bodyMass, 165.0, .pound()),
            (.height, 69.0, .inch()),            // 5'9"
            (.bodyMassIndex, 24.4, .count()),
            (.heartRate, 78.0, .count().unitDivided(by: .minute())),
            (.bloodPressureSystolic, 128.0, .millimeterOfMercury()),
            (.bloodPressureDiastolic, 82.0, .millimeterOfMercury()),
            (.bodyTemperature, 98.4, .degreeFahrenheit()),
            (.respiratoryRate, 16.0, .count().unitDivided(by: .minute())),
            (.oxygenSaturation, 0.97, .percent()),
        ]
        for (id, value, unit) in vitals {
            let sample = HKQuantitySample(
                type: HKQuantityType(id),
                quantity: HKQuantity(unit: unit, doubleValue: value),
                start: now, end: now
            )
            try await store.save(sample)
        }

        // Lab-like quantities relevant for clinical trial eligibility
        let labQuantities: [(HKQuantityTypeIdentifier, Double, HKUnit)] = [
            (.bloodGlucose, 95.0, .gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))),
            (.vo2Max, 32.0, HKUnit(from: "mL/kg*min")),
        ]
        for (id, value, unit) in labQuantities {
            let sample = HKQuantitySample(
                type: HKQuantityType(id),
                quantity: HKQuantity(unit: unit, doubleValue: value),
                start: now, end: now
            )
            try await store.save(sample)
        }

        // Date of birth (age is a key trial eligibility criterion)
        // Set DOB to ~52 years old
        if let dob = calendar.date(from: DateComponents(year: 1974, month: 3, day: 15)) {
            try await store.save(HKQuantitySample(
                type: HKQuantityType(.bodyMass),
                quantity: HKQuantity(unit: .pound(), doubleValue: 165.0),
                start: dob, end: dob,
                metadata: [HKMetadataKeyWasUserEntered: true]
            ))
        }

        // 30-day heart rate + blood pressure history
        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let start = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .hour, value: 1, to: start) else { continue }

            // Heart rate: 72-84 bpm with variation
            let hr = Double.random(in: 72...84)
            let hrSample = HKQuantitySample(
                type: HKQuantityType(.heartRate),
                quantity: HKQuantity(unit: .count().unitDivided(by: .minute()), doubleValue: hr),
                start: start, end: end
            )
            try await store.save(hrSample)

            // Blood pressure: sys 122-134, dia 78-88
            let sys = Double.random(in: 122...134)
            let sysSample = HKQuantitySample(
                type: HKQuantityType(.bloodPressureSystolic),
                quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: sys),
                start: start, end: end
            )
            try await store.save(sysSample)

            let dia = Double.random(in: 78...88)
            let diaSample = HKQuantitySample(
                type: HKQuantityType(.bloodPressureDiastolic),
                quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: dia),
                start: start, end: end
            )
            try await store.save(diaSample)

            // Blood glucose daily variation (fasting 85-105 mg/dL)
            let glucose = Double.random(in: 85...105)
            let glucoseSample = HKQuantitySample(
                type: HKQuantityType(.bloodGlucose),
                quantity: HKQuantity(unit: .gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci)), doubleValue: glucose),
                start: start, end: end
            )
            try await store.save(glucoseSample)
        }
    }
    #endif
}

// MARK: - Local data models

struct LabResult: Identifiable {
    let id = UUID()
    let testName: String
    let value: Double
    let unit: String
    let date: String
    let source: String
}

struct MedicationRecord: Identifiable {
    let id = UUID()
    let name: String
    let dose: String
    let frequency: String
    let startDate: String
    let endDate: String
    let isActive: Bool
}
