import SwiftUI
import UserNotifications

struct ContentView: View {
    @State private var manager = HealthKitManager()
    @State private var sessionId = ""
    @State private var statusMessage = ""
    @State private var isFetching = false
    @State private var isSending = false
    @State private var hasFetched = false
    @State private var importResponse: APIClient.ImportResponse?
    @State private var notificationsEnabled = false
    @State private var notificationsDenied = false

    var body: some View {
        NavigationStack {
            Form {
                // Session link
                Section("Session") {
                    TextField("Session ID", text: $sessionId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Enter the session ID from the web app to link your health data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // HealthKit authorization & fetch
                Section("Health Data") {
                    if manager.isAuthorized {
                        Label("Connected to Health", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Connect to Health") {
                            Task {
                                await manager.requestAuthorization()
                            }
                        }
                    }

                    if let error = manager.authError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if manager.isAuthorized {
                        Button {
                            Task {
                                isFetching = true
                                await manager.fetchAll()
                                isFetching = false
                                hasFetched = true
                                statusMessage = "Health data loaded."
                            }
                        } label: {
                            HStack {
                                Text("Fetch Health Data")
                                if isFetching {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isFetching)
                    }
                }

                // Data summary
                if hasFetched {
                    HealthSummaryView(manager: manager, importResponse: importResponse)
                }

                // Send to backend
                if hasFetched {
                    Section("Upload") {
                        Button {
                            Task { await sendData() }
                        } label: {
                            HStack {
                                Text("Send Health Data")
                                if isSending {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(sessionId.isEmpty || isSending)

                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundStyle(importResponse != nil ? .green : .secondary)
                        }
                    }
                }

                // Notifications
                Section("Notifications") {
                    if notificationsEnabled {
                        Label("Notifications Enabled", systemImage: "bell.badge.fill")
                            .foregroundStyle(.green)
                    } else if notificationsDenied {
                        Label("Notifications Denied", systemImage: "bell.slash")
                            .foregroundStyle(.secondary)
                        Text("Enable notifications in Settings to receive trial match alerts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Enable Notifications") {
                            Task { await requestNotificationPermission() }
                        }
                        Text("Get notified when future trials match your profile and criteria.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Debug tools
                #if DEBUG
                Section("Debug") {
                    Button("Seed Sample Data") {
                        Task {
                            await manager.seedSampleData()
                            statusMessage = "Sample data seeded into HealthKit."
                        }
                    }
                }
                #endif
            }
            .navigationTitle("Clinical Trial Health")
            .task { await checkNotificationStatus() }
        }
    }

    private func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            notificationsEnabled = true
        case .denied:
            notificationsDenied = true
        default:
            break
        }
    }

    private func requestNotificationPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                notificationsEnabled = true
                await scheduleThankYouNotification()
            } else {
                notificationsDenied = true
            }
        } catch {
            notificationsDenied = true
        }
    }

    private func scheduleThankYouNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Clinical Trial Health"
        content.body = "Thanks for enabling push notifications. We will notify you if future trials meet your profile and criteria."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "notifications-enabled",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func sendData() async {
        guard !sessionId.isEmpty else {
            statusMessage = "Enter a session ID first."
            return
        }
        isSending = true
        statusMessage = "Sending..."
        do {
            let payload = APIClient.buildPayload(from: manager)
            let response = try await APIClient.sendHealthData(sessionId: sessionId, payload: payload)
            importResponse = response
            statusMessage = "Uploaded successfully."
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
        isSending = false
    }
}

#Preview {
    ContentView()
}
