import SwiftUI
import CoreImage.CIFilterBuiltins

struct MatchedTrialsView: View {
    let trials: [MatchedTrialResponse]
    var reportGenerated: Bool = false

    @State private var qrTrialID: String? = nil

    var body: some View {
        let topTrials = Array(trials.prefix(3))
        ForEach(topTrials, id: \.nct_id) { trial in
            VStack(alignment: .leading, spacing: 0) {
                if let url = URL(string: "https://clinicaltrials.gov/study/\(trial.nct_id)") {
                    Link(destination: url) {
                        VStack(alignment: .leading, spacing: 8) {
                            // Title and fit score
                            HStack(alignment: .top) {
                                Text(trial.brief_title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.blue)
                                    .lineLimit(2)
                                Spacer()
                                FitScoreBadge(score: trial.fit_score)
                            }

                            // Phase and status
                            HStack(spacing: 8) {
                                Text(trial.phase)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.systemGray5))
                                    .clipShape(Capsule())
                                Text(trial.overall_status)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            // Plain language summary
                            Text(trial.plain_language_summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)

                            // Location and link indicator
                            HStack {
                                if let loc = trial.nearest_location {
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundStyle(.secondary)
                                        Text("\(loc.facility), \(loc.city), \(loc.state)")
                                            .lineLimit(1)
                                        if let miles = loc.distance_miles {
                                            Text("(\(Int(miles)) mi)")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .font(.caption2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if reportGenerated {
                    Button {
                        qrTrialID = trial.nct_id
                    } label: {
                        Label("Physician Shortcut", systemImage: "qrcode")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .padding(.top, 6)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { qrTrialID != nil },
            set: { if !$0 { qrTrialID = nil } }
        )) {
            if let id = qrTrialID, let trial = trials.first(where: { $0.nct_id == id }) {
                QRCodeSheetView(trial: trial)
            }
        }
    }
}

// MARK: - QR Code Sheet

private struct QRCodeSheetView: View {
    let trial: MatchedTrialResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(trial.brief_title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let qrImage = generateQRCode(from: "https://clinicaltrials.gov/study/\(trial.nct_id)") {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                } else {
                    Text("Unable to generate QR code")
                        .foregroundStyle(.secondary)
                }

                Text(trial.nct_id)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospaced()

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Physician Shortcut")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Fit Score Badge

private struct FitScoreBadge: View {
    let score: Double

    private var color: Color {
        if score >= 70 { return .green }
        if score >= 40 { return .orange }
        return .red
    }

    var body: some View {
        Text("\(Int(score))%")
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
