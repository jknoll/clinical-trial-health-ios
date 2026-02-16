import SwiftUI

struct SessionProgressView: View {
    let tracker: SessionTracker
    @State private var showReport = false

    private var phaseSteps: [(key: String, label: String)] {
        [
            ("intake", "Gathering profile"),
            ("search", "Searching trials"),
            ("matching", "Analyzing eligibility"),
            ("selection", "Selecting trials"),
            ("report", "Generating report"),
        ]
    }

    private var currentPhaseIndex: Int {
        phaseSteps.firstIndex(where: { $0.key == tracker.phase }) ?? -1
    }

    var body: some View {
        Section("Session Progress") {
            // Phase steps
            ForEach(Array(phaseSteps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 10) {
                    if index < currentPhaseIndex || (index == currentPhaseIndex && tracker.reportGenerated) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if index == currentPhaseIndex {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                    }
                    Text(step.label)
                        .font(.subheadline)
                        .foregroundStyle(index <= currentPhaseIndex ? .primary : .secondary)
                }
            }

            if let error = tracker.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Matched trials
            if !tracker.matchedTrials.isEmpty {
                MatchedTrialsView(trials: tracker.matchedTrials, reportGenerated: tracker.reportGenerated)
            }

            // Report button
            if tracker.reportGenerated, let url = tracker.reportURL {
                Button {
                    showReport = true
                } label: {
                    Label("View Full Report", systemImage: "doc.text")
                }
                .sheet(isPresented: $showReport) {
                    NavigationStack {
                        ReportWebView(url: url)
                            .navigationTitle("Trial Report")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") { showReport = false }
                                }
                            }
                    }
                }
            }
        }
    }
}
