# Two-Sided Market Extension for Clinical Trial Health

## Current Architecture: Patient-to-Trial Search

Clinical Trial Health currently operates as a **one-sided discovery tool**. Patients connect their Apple HealthKit data — vitals, lab results, medications, activity levels — and the system scores their eligibility against clinical trial criteria via the Clinical Trial Copilot backend. The data flow is unidirectional:

```
Patient → HealthKit → iOS App → Backend API → Eligibility Score
```

The patient initiates every interaction. Trials are passive listings. The system answers one question: *"Which trials might I qualify for?"*

This document describes how the product could be extended into a **two-sided market** where clinical trials actively search for, locate, and recruit patients — while preserving the privacy guarantees that make patient participation possible in the first place.

---

## The Two-Sided Market Model

### What Changes

In a two-sided market, the system answers a second question from the opposite direction: *"Where are the patients who match my trial's requirements?"*

The participants:

| Side | Current Role | Extended Role |
|------|-------------|---------------|
| **Patients** | Search for trials, share health data for scoring | Optionally contribute anonymized data to an aggregate pool; receive inbound recruitment messages |
| **Trial Sponsors / CROs** | Passive listings scored against patient data | Actively query aggregate patient data; select trial sites based on demand geography; recruit from matching patient pools |

### New Capabilities for the Trial Side

**1. Aggregate Demand Mapping**

Trial sponsors designing a new study need to answer: *"Where should we place trial sites?"* Today this is driven by relationships with academic medical centers and guesswork about patient populations. With aggregated, anonymized patient data, sponsors could query:

- How many patients in a metropolitan area match a given set of inclusion/exclusion criteria
- Which geographies have unmet demand (patients searching for a trial type with no nearby sites)
- How demographic and clinical distributions vary by region

This does not require identifying individual patients. It requires statistical queries over population-level aggregates.

**2. Feasibility Assessment**

Before committing to a Phase III trial with 3,000-patient enrollment targets, sponsors need to know whether that population exists and is reachable. Aggregate data enables:

- Estimation of eligible patient pools for specific criteria combinations
- Identification of criteria that are overly restrictive (e.g., a biomarker threshold that eliminates 95% of otherwise-eligible patients)
- Modeling of realistic enrollment timelines based on patient density and historical opt-in rates

**3. Diversity and Representation Planning**

FDA guidance increasingly requires demographic diversity in trial enrollment. Aggregate data, properly anonymized, could show:

- Demographic composition of eligible patient pools by geography
- Whether a proposed site selection plan will produce enrollment that meets diversity targets
- Underrepresented populations that could be reached with targeted outreach in specific regions

**4. Patient Recruitment**

The most sensitive capability: allowing trial sponsors to reach patients who match their criteria. This moves from aggregate statistics to individual-level matching and messaging, which introduces the core tension of the two-sided model.

---

## Privacy Architecture

### The Core Tension

The value of the two-sided market depends on patient data. The viability of patient participation depends on privacy. These are in direct tension.

Patients who share health data to learn about their own eligibility have not consented to being marketed to by pharmaceutical companies. The transition from "I'm searching for trials" to "trials are searching for me" must be explicit, granular, and revocable.

### HIPAA Requirements

Clinical Trial Health handles protected health information (PHI) as defined under HIPAA. The relevant constraints:

**Covered Entity vs. Business Associate:** If the platform processes health data on behalf of a covered entity (a hospital, insurer, or provider), it is a business associate and must execute a BAA. If it operates independently as a consumer health tool, HIPAA's direct applicability is narrower — but state laws (California's CCMR Act, Washington's My Health My Data Act) impose analogous obligations on consumer health data.

**De-identification Standard:** HIPAA defines two paths to de-identification:

1. **Expert Determination (§164.514(b)(1)):** A qualified statistical expert certifies that the risk of identifying an individual is "very small." This is the standard required for aggregate queries.
2. **Safe Harbor (§164.514(b)(2)):** Remove 18 specific identifiers (name, geographic data below state level, dates more specific than year, etc.). This is rigid but unambiguous.

For the aggregate demand mapping and feasibility features, Safe Harbor de-identification with k-anonymity guarantees (minimum group sizes for any query result) is the baseline. For recruitment messaging, additional consent and access controls are required.

**Minimum Necessary Standard:** Any data shared with trial sponsors must be limited to the minimum necessary for the stated purpose. A sponsor evaluating site placement does not need individual lab values — they need counts and distributions.

**Patient Authorization:** Direct recruitment outreach using PHI requires explicit patient authorization under §164.508, separate from the general consent to use the app. This authorization must specify:

- What information will be shared
- With whom
- For what purpose
- An expiration date
- The right to revoke

### Consent Architecture

The platform should implement tiered consent:

| Tier | What the Patient Agrees To | Data Exposure |
|------|---------------------------|---------------|
| **Tier 0** (default) | Use my data to score my own eligibility | Data sent to backend, used only for the patient's session, not retained in aggregate pools |
| **Tier 1** | Include my anonymized data in aggregate statistics | De-identified data contributes to population-level queries; no individual identification possible |
| **Tier 2** | Allow matching trials to send me anonymized notifications | Platform matches patient profile against trial criteria and delivers blinded messages; sponsor never sees patient identity |
| **Tier 3** | Allow me to reveal my identity to a specific trial | Patient explicitly opts in to share contact information with a named sponsor for a named trial |

Each tier is independently revocable. Revoking Tier 1 removes the patient's data from aggregate pools. Revoking Tier 2 stops inbound recruitment messages. Tier 3 is per-trial and cannot be batch-granted.

### Data Retention and Deletion

- Aggregate contributions should be re-derived periodically rather than accumulated indefinitely. A patient who revokes Tier 1 consent should see their contribution removed from aggregates within a defined window (e.g., the next recomputation cycle).
- Individual profiles used for Tier 2 matching should be stored in encrypted form and deleted upon consent revocation.
- Tier 3 identity disclosures create a record that the patient shared information with a specific sponsor. This record should be auditable by the patient and subject to deletion requests.

---

## Platform Mechanics

### Trial-Side Interface

Trial sponsors or CROs would interact with the platform through a web-based dashboard (not the iOS app). Core workflows:

**Query Builder:** Define inclusion/exclusion criteria using the same clinical parameters the patient-side system already understands (lab values, vitals, medications, diagnoses, activity levels). The system returns aggregate statistics — counts, distributions, geographic heat maps — never individual records.

**Site Optimization:** Given a set of criteria and a target enrollment number, the system recommends geographic regions for trial sites based on eligible patient density. This consumes only Tier 1 (aggregate) data.

**Recruitment Campaigns:** For sponsors who want to reach individual patients (Tier 2), the system operates as a blind intermediary:

1. Sponsor defines criteria and composes a recruitment message
2. Platform matches criteria against opted-in patient profiles
3. Platform delivers the message to matching patients
4. Patient sees the message with trial details but the sponsor does not know which patients received it
5. Patient decides whether to respond (Tier 3 opt-in)

The sponsor pays for reach (number of matching patients messaged) without knowing who those patients are until the patient chooses to respond.

### Revenue Model

The two-sided market creates revenue opportunities beyond the current patient-facing product:

- **Aggregate query fees:** Sponsors pay per query or subscribe for ongoing access to aggregate population statistics
- **Feasibility reports:** Packaged analysis combining aggregate data with public trial registry data
- **Recruitment campaign fees:** Per-message or per-response pricing for blinded recruitment outreach
- **Site optimization consulting:** Analysis of optimal site placement using aggregate demand data

Patient-side features remain free to maximize the data network effect. The value to sponsors scales with the number of participating patients, creating a flywheel: more patients → better data → more sponsor revenue → more investment in patient experience → more patients.

---

## Addendum: Technical Approaches to Privacy-Preserving Computation

The architecture described above relies on a trusted intermediary — the platform itself — to enforce privacy boundaries. The platform sees all patient data and is trusted not to misuse it. This section considers cryptographic and architectural alternatives that reduce or eliminate the need for that trust.

### Zero-Knowledge Proofs

A zero-knowledge proof (ZKP) allows one party to prove a statement is true without revealing the underlying data. In this context:

**Application to Aggregate Queries:** A patient's device could generate a ZKP proving "this patient satisfies criteria X" without revealing the patient's actual lab values, diagnoses, or other health data. The platform (or sponsor) learns only the boolean result — eligible or not — and can aggregate these results into counts.

**Practical Considerations:**

- **Computational cost:** General-purpose ZKP systems (zk-SNARKs, zk-STARKs) are computationally expensive. Generating proofs for complex eligibility criteria (multiple lab value ranges, medication histories, comorbidity checks) on a mobile device may be prohibitive today but is improving rapidly.
- **Circuit complexity:** Each eligibility criterion must be encoded as an arithmetic circuit. The space of possible trial criteria is large and heterogeneous. A practical system would need a domain-specific language for trial criteria that compiles to ZKP circuits.
- **Trusted setup:** zk-SNARKs require a trusted setup ceremony. zk-STARKs avoid this but produce larger proofs. For a consumer health application, the choice depends on acceptable proof sizes and verification times.
- **Freshness:** ZKPs prove facts about data at a point in time. The system needs a mechanism to ensure proofs reflect current health status, not stale data.

**Where ZKPs Add Value:** ZKPs are most compelling for Tier 2 recruitment matching. Instead of the platform storing patient profiles and running matches centrally, patients' devices could periodically evaluate new trial criteria and generate ZKPs of eligibility. The platform learns only "Patient #hash123 is eligible for Trial #456" without knowing why — the specific clinical data that produces eligibility remains on-device.

### Secure Multi-Party Computation (MPC)

MPC allows multiple parties to jointly compute a function over their inputs without revealing those inputs to each other.

**Application:** Patients and sponsors could jointly compute aggregate eligibility statistics without any single party seeing all the data. For example, a sponsor's criteria and patients' health data could be inputs to an MPC protocol that outputs only the aggregate count of eligible patients in a region.

**Practical Considerations:** MPC protocols require multiple rounds of communication and are orders of magnitude slower than plaintext computation. For aggregate statistical queries over thousands of patients, current MPC performance may be acceptable. For complex matching with real-time requirements, it is not yet practical.

### Differential Privacy

Differential privacy adds calibrated noise to query results to prevent any single individual's data from being inferred from the output.

**Application:** Aggregate query results returned to sponsors could be differentially private — the counts and distributions would be approximately correct but noisy enough that no individual patient's presence or absence in the dataset can be determined.

**Practical Considerations:** Differential privacy is well-understood and computationally cheap. It is the most immediately deployable privacy-enhancing technology for the aggregate query features (Tier 1). The tradeoff is accuracy: heavily-noised results are less useful to sponsors, and the privacy budget (epsilon) must be managed to prevent information leakage across many queries.

**Recommendation:** Differential privacy should be the baseline for all aggregate queries from day one. ZKPs and MPC are longer-term investments for Tier 2 matching.

### Anonymous Messaging via Blind Intermediary

For Tier 2 recruitment, the simplest privacy-preserving architecture does not require advanced cryptography:

1. Each patient is assigned a pseudonymous mailbox (a random identifier unlinked to their real identity in any sponsor-visible system)
2. The platform runs matching in a secure enclave or trusted execution environment (TEE)
3. Matching results are routed to pseudonymous mailboxes
4. Patients check their mailbox via the app using a local credential
5. The sponsor sees only aggregate delivery statistics (X messages delivered, Y responses received)

This is not cryptographically trustless — it relies on the platform operating the TEE honestly — but it is a practical architecture that can be deployed with current technology and later hardened with ZKPs or MPC as those technologies mature.

### Federated Learning for Site Optimization

Rather than centralizing patient data for geographic analysis, federated learning could allow the platform to train site-optimization models across patient devices without extracting raw data:

1. A model predicting trial demand is pushed to patient devices
2. Each device computes a gradient update using local health data
3. Updates are aggregated centrally (with differential privacy) to improve the model
4. The central model can answer geographic demand questions without ever seeing individual patient data

This is well-suited to the site optimization use case, where the output is a geographic heat map rather than individual patient matches.

### 23andMe as Cautionary Counter-Architecture

23andMe's trajectory illustrates the risks of a centralized, consent-agnostic approach to health data aggregation, and several specific architectural decisions that a two-sided clinical trial market must avoid.

**What 23andMe Did:**

23andMe collected genetic data from approximately 15 million customers under a consumer genomics product. Over time, it monetized this data through a therapeutics division (partnering with GSK for drug discovery) and a research arm that sold aggregate genetic insights to pharmaceutical companies. In 2023, a data breach exposed the genetic and ancestry data of 6.9 million users. In 2024, the company's therapeutics division was sold, and the company entered bankruptcy proceedings in early 2025, raising the question of what happens to 15 million people's genetic data when the company that holds it is sold to the highest bidder in bankruptcy court.

**Architectural Failures to Avoid:**

1. **Centralized raw data storage.** 23andMe stored raw genetic sequences centrally. A breach exposed irreversible data — you cannot change your genome. Clinical Trial Health must minimize centralized storage of raw health data. Aggregates should be derived on-device or in secure enclaves, with raw data retained only on the patient's device (in HealthKit, where Apple's security model protects it).

2. **Consent scope creep.** 23andMe's initial consent covered ancestry and health reports. The expansion to pharmaceutical partnerships and drug discovery research stretched this consent beyond what most customers understood when they spit in a tube. Clinical Trial Health's tiered consent model must be enforced technically (different data pipelines for each tier), not just legally (terms of service updates that nobody reads).

3. **Data as a balance-sheet asset.** When 23andMe entered bankruptcy, its user data became a corporate asset subject to sale. This is the endgame of any architecture where the platform owns user data. Clinical Trial Health should ensure that patient data is never a transferable corporate asset:
   - Raw data stays on-device (HealthKit)
   - Aggregate contributions are derived, not stored as raw records
   - Consent is tied to the patient, not the platform — if the platform is acquired, consent does not transfer automatically
   - Patients can export and delete their data at any time (HIPAA right of access and state-law deletion rights)

4. **No data survivorship plan.** 23andMe had no public plan for what happens to user data if the company ceases to exist. Clinical Trial Health should define this from the start: if the platform shuts down, all centrally-stored data is deleted, patients are notified, and on-device data remains under the patient's control via HealthKit.

5. **Irrevocable data.** Genetic data cannot be revoked — once exposed, it is compromised permanently, and it compromises not just the individual but their relatives. Health data from HealthKit is sensitive but not irrevocable in the same way. Vitals and lab values change over time, and historical values have diminishing relevance. The system should enforce data expiration: aggregate contributions should age out, and the matching system should work only with recent health data (consistent with the current 30-day activity window the app already uses).

**The Core Lesson:** 23andMe demonstrates that a company can build a large user base on the promise of personal health insights, pivot to monetizing that data with third parties, suffer a breach that exposes the most sensitive possible data, and then lose control of that data entirely through bankruptcy — all while operating within the bounds of its terms of service. The two-sided market model proposed here must be designed so that this sequence of events is architecturally impossible, not merely contractually prohibited.

---

## Implementation Priorities

If extending Clinical Trial Health to a two-sided market, the recommended sequence:

1. **Tier 1 aggregate queries with differential privacy.** Lowest privacy risk, immediate value to sponsors for feasibility and site planning. No individual patient identification. Deployable with current technology.

2. **Trial-side dashboard for aggregate query and site optimization.** Web application for sponsors to query aggregate data. Revenue-generating from launch.

3. **Tier 2 blind recruitment messaging.** Requires careful consent UX in the iOS app, pseudonymous mailbox infrastructure, and sponsor-side campaign tools. Higher privacy risk, higher revenue potential.

4. **On-device ZKP-based matching.** Long-term replacement for centralized Tier 2 matching. Eliminates the need to trust the platform with individual health data for recruitment. Dependent on ZKP tooling maturity for mobile.

5. **Federated learning for demand modeling.** Replaces centralized geographic analysis with privacy-preserving distributed computation. Requires significant ML infrastructure investment.

Each phase should be accompanied by an independent privacy audit, a legal review of HIPAA and state-law compliance, and user research on consent comprehension — because a consent tier that patients do not actually understand is not meaningful consent.
