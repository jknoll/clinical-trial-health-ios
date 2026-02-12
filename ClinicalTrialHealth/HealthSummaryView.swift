import SwiftUI

struct HealthSummaryView: View {
    let manager: HealthKitManager
    let importResponse: APIClient.ImportResponse?

    var body: some View {
        Section("Health Summary") {
            // Activity
            if let steps = manager.stepAverage {
                row("Avg Steps/Day", value: String(format: "%.0f", steps))
            }
            if let active = manager.activeMinutesAverage {
                row("Avg Active Min/Day", value: String(format: "%.0f", active))
            }

            // Vitals
            if let w = manager.latestWeight {
                row("Weight", value: String(format: "%.1f lbs", w))
            }
            if let h = manager.latestHeight {
                let feet = Int(h) / 12
                let inches = Int(h) % 12
                row("Height", value: "\(feet)'\(inches)\"")
            }
            if let bmi = manager.latestBMI {
                row("BMI", value: String(format: "%.1f", bmi))
            }
            if let hr = manager.latestHeartRate {
                row("Heart Rate", value: String(format: "%.0f bpm", hr))
            }
            if let sys = manager.latestBPSystolic, let dia = manager.latestBPDiastolic {
                row("Blood Pressure", value: "\(Int(sys))/\(Int(dia)) mmHg")
            }

            // Counts
            if !manager.labResults.isEmpty {
                row("Lab Results", value: "\(manager.labResults.count)")
            }
            if !manager.medications.isEmpty {
                row("Medications", value: "\(manager.medications.count)")
            }

            // Estimated ECOG from step data
            if let steps = manager.stepAverage {
                let ecog = estimateECOG(stepsPerDay: steps)
                HStack {
                    Text("Estimated ECOG")
                    Spacer()
                    Text("\(ecog)")
                        .bold()
                        .foregroundStyle(ecog <= 1 ? .green : .orange)
                }
            }
        }

        // Server response
        if let resp = importResponse {
            Section("Server Response") {
                row("Status", value: resp.status)
                if let labs = resp.lab_count { row("Labs imported", value: "\(labs)") }
                if let vitals = resp.vital_count { row("Vitals imported", value: "\(vitals)") }
                if let meds = resp.medication_count { row("Meds imported", value: "\(meds)") }
                if let ecog = resp.estimated_ecog {
                    HStack {
                        Text("Server ECOG")
                        Spacer()
                        Text("\(ecog)")
                            .bold()
                            .foregroundStyle(ecog <= 1 ? .green : .orange)
                    }
                }
                if let steps = resp.steps_per_day {
                    row("Steps/day", value: String(format: "%.0f", steps))
                }
                if let active = resp.active_minutes_per_day {
                    row("Active min/day", value: String(format: "%.0f", active))
                }
            }
        }
    }

    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    /// Estimates ECOG performance status from average daily step count.
    /// Matches the backend `estimate_ecog_from_steps` logic.
    private func estimateECOG(stepsPerDay: Double) -> Int {
        switch stepsPerDay {
        case 7000...: return 0  // Fully active
        case 4000...: return 1  // Restricted but ambulatory
        case 1500...: return 2  // Ambulatory, capable of self-care
        case 500...:  return 3  // Limited self-care
        default:      return 4  // Completely disabled
        }
    }
}
