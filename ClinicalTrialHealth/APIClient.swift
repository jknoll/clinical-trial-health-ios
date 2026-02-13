import Foundation

/// Posts HealthKit data to the Clinical Trial Copilot backend.
struct APIClient {

    #if targetEnvironment(simulator)
    static var baseURL = "http://localhost:8100"
    #else
    static var baseURL = "https://clinical-trial-copilot.fly.dev"
    #endif

    /// Import payload matching the backend `HealthKitImport` Pydantic model.
    struct HealthKitPayload: Encodable {
        let lab_results: [LabResultPayload]
        let vitals: [VitalPayload]
        let medications: [MedicationPayload]
        let activity_steps_per_day: Double?
        let activity_active_minutes_per_day: Double?
        let import_date: String
        let source_file: String
    }

    struct LabResultPayload: Encodable {
        let test_name: String
        let value: Double
        let unit: String
        let date: String
        let source: String
    }

    struct VitalPayload: Encodable {
        let type: String
        let value: Double
        let unit: String
        let date: String
    }

    struct MedicationPayload: Encodable {
        let name: String
        let dose: String
        let frequency: String
        let start_date: String
        let end_date: String
        let is_active: Bool
    }

    struct ImportResponse: Decodable {
        let status: String
        let lab_count: Int?
        let vital_count: Int?
        let medication_count: Int?
        let estimated_ecog: Int?
        let steps_per_day: Double?
        let active_minutes_per_day: Double?
    }

    // MARK: - Build payload from HealthKitManager data

    static func buildPayload(from manager: HealthKitManager) -> HealthKitPayload {
        let isoFormatter = ISO8601DateFormatter()
        let now = isoFormatter.string(from: Date())

        let labs = manager.labResults.map {
            LabResultPayload(test_name: $0.testName, value: $0.value, unit: $0.unit, date: $0.date, source: $0.source)
        }

        var vitals: [VitalPayload] = []
        if let w = manager.latestWeight {
            vitals.append(VitalPayload(type: "body_mass", value: w, unit: "lb", date: now))
        }
        if let h = manager.latestHeight {
            vitals.append(VitalPayload(type: "height", value: h, unit: "in", date: now))
        }
        if let bmi = manager.latestBMI {
            vitals.append(VitalPayload(type: "bmi", value: bmi, unit: "count", date: now))
        }
        if let hr = manager.latestHeartRate {
            vitals.append(VitalPayload(type: "heart_rate", value: hr, unit: "bpm", date: now))
        }
        if let sys = manager.latestBPSystolic {
            vitals.append(VitalPayload(type: "blood_pressure_systolic", value: sys, unit: "mmHg", date: now))
        }
        if let dia = manager.latestBPDiastolic {
            vitals.append(VitalPayload(type: "blood_pressure_diastolic", value: dia, unit: "mmHg", date: now))
        }

        let meds = manager.medications.map {
            MedicationPayload(
                name: $0.name, dose: $0.dose, frequency: $0.frequency,
                start_date: $0.startDate, end_date: $0.endDate, is_active: $0.isActive
            )
        }

        return HealthKitPayload(
            lab_results: labs,
            vitals: vitals,
            medications: meds,
            activity_steps_per_day: manager.stepAverage,
            activity_active_minutes_per_day: manager.activeMinutesAverage,
            import_date: now,
            source_file: "ios-healthkit"
        )
    }

    // MARK: - Send to backend

    static func sendHealthData(sessionId: String, payload: HealthKitPayload) async throws -> ImportResponse {
        let urlString = "\(baseURL)/api/sessions/\(sessionId)/health-import-json"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "APIClient",
                code: statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Server returned \(statusCode): \(body)"]
            )
        }

        return try JSONDecoder().decode(ImportResponse.self, from: data)
    }
}
