import Foundation

// MARK: - Session State

struct SessionStateResponse: Decodable {
    let session_id: String
    let phase: String
    let profile_complete: Bool
    let search_complete: Bool
    let matching_complete: Bool
    let report_generated: Bool
}

// MARK: - Matched Trials

struct MatchedTrialResponse: Decodable {
    let nct_id: String
    let brief_title: String
    let phase: String
    let overall_status: String
    let fit_score: Double
    let fit_summary: String
    let plain_language_summary: String
    let interventions: [String]
    let nearest_location: TrialLocationResponse?
}

struct TrialLocationResponse: Decodable {
    let facility: String
    let city: String
    let state: String
    let distance_miles: Double?
}
