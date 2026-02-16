import SwiftUI

struct ContentView: View {
    @State private var manager = HealthKitManager()
    @State private var sessionId = ""
    @State private var statusMessage = ""
    @State private var isFetching = false
    @State private var isSending = false
    @State private var hasFetched = false
    @State private var importResponse: APIClient.ImportResponse?
    @State private var backendURL = APIClient.baseURL
    @State private var showScanner = false
    @State private var showBackendURL = false
    @State private var scannedCode: String?
    @State private var tracker = SessionTracker()
    @State private var showDebug = false
    @State private var seedStatus: SeedStatus = .idle

    var onReplaySplash: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Text("Clinical Trial Compass")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.bar)

            Form {
                // Session link
                Section("Session") {
                    TextField("Session ID", text: $sessionId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Enter the session ID from the web app to link your health data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    }
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

                // Session progress (after upload)
                if tracker.isPolling || tracker.reportGenerated {
                    SessionProgressView(tracker: tracker)
                }

                // Debug tools
                #if DEBUG
                Section {
                    DisclosureGroup("Debug", isExpanded: $showDebug) {
                        // Backend URL (moved from Session section)
                        TextField("Backend URL", text: $backendURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: backendURL) { _, newValue in
                                APIClient.baseURL = newValue
                            }
                        Text("URL of the Clinical Trial Compass backend server.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Seed sample data with status indicator
                        Button {
                            Task {
                                seedStatus = .seeding
                                do {
                                    try await manager.seedSampleData()
                                    seedStatus = .success
                                } catch {
                                    seedStatus = .failure(error.localizedDescription)
                                }
                            }
                        } label: {
                            HStack {
                                Text("Seed Sample Data")
                                Spacer()
                                switch seedStatus {
                                case .idle:
                                    EmptyView()
                                case .seeding:
                                    ProgressView()
                                case .success:
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                case .failure:
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .disabled(seedStatus == .seeding)

                        if case .failure(let msg) = seedStatus {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Button("Reset Health Connection") {
                            manager.isAuthorized = false
                            manager.authError = nil
                            hasFetched = false
                            importResponse = nil
                            statusMessage = ""
                        }
                        Text("Resets local state only. To revoke HealthKit permissions, delete and reinstall the app.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        // New replay splash button
                        Button("Replay Splash Screen") {
                            onReplaySplash?()
                        }
                    }
                }
                #endif
            }
            .sheet(isPresented: $showScanner) {
                QRScannerView(scannedCode: $scannedCode, isPresented: $showScanner)
            }
            .onChange(of: scannedCode) { _, newValue in
                guard let code = newValue,
                      let data = code.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return }
                if let sid = json["session_id"] { sessionId = sid }
                if let url = json["backend_url"] {
                    backendURL = url
                    APIClient.baseURL = url
                }
            }
            .onDisappear { tracker.stopTracking() }
        }
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
            tracker.startTracking(sessionId: sessionId)
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
        isSending = false
    }
}

enum SeedStatus: Equatable {
    case idle, seeding, success
    case failure(String)
}

#Preview {
    ContentView()
}
