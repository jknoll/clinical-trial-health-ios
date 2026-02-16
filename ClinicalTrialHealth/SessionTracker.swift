import Foundation

@Observable
class SessionTracker {
    var phase: String = ""
    var matchingComplete = false
    var reportGenerated = false
    var matchedTrials: [MatchedTrialResponse] = []
    var isPolling = false
    var error: String?

    private var sessionId: String = ""
    private var timer: Timer?

    var reportURL: URL? {
        guard reportGenerated, !sessionId.isEmpty else { return nil }
        return URL(string: "\(APIClient.baseURL)/api/sessions/\(sessionId)/report")
    }

    func startTracking(sessionId: String) {
        self.sessionId = sessionId
        self.error = nil
        self.isPolling = true
        self.matchedTrials = []
        self.matchingComplete = false
        self.reportGenerated = false
        self.phase = ""

        // Poll immediately, then every 5 seconds
        Task { await pollState() }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.pollState() }
        }
    }

    func stopTracking() {
        timer?.invalidate()
        timer = nil
        isPolling = false
    }

    @MainActor
    private func pollState() async {
        do {
            let state = try await APIClient.fetchSessionState(sessionId: sessionId)
            phase = state.phase
            matchingComplete = state.matching_complete
            reportGenerated = state.report_generated

            // Fetch matched trials once when matching completes
            if state.matching_complete && matchedTrials.isEmpty {
                matchedTrials = try await APIClient.fetchMatchedTrials(sessionId: sessionId)
            }

            // Stop polling when report is generated (terminal state)
            if state.report_generated {
                stopTracking()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
