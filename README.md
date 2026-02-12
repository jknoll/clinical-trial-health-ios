# Clinical Trial Health — iOS HealthKit Companion

A SwiftUI iOS app that reads HealthKit data on-device and sends it directly to the [Clinical Trial Copilot](https://github.com/jknoll/clinical-trial-copilot) backend for clinical trial eligibility scoring.

## What It Does

- Reads vitals, lab results, medications, and activity data from Apple HealthKit
- Computes 30-day step and exercise averages
- Accesses FHIR clinical records (lab results, medications) if available
- Posts health data as JSON to the backend, bypassing the XML export workflow
- Estimates ECOG performance status from step data

## Prerequisites

- **macOS 14+** (Sonoma or later)
- **Xcode 16+** — [Download from Apple Developer](https://developer.apple.com/xcode/) or the Mac App Store
- **XcodeGen** (optional, for generating `.xcodeproj` from `project.yml`)

## Setup

### 1. Install Xcode

You need the full Xcode IDE (not just Command Line Tools). Check if you already have it:

```bash
xcode-select -p
# If it prints /Applications/Xcode.app/Contents/Developer, you're good — skip to step 2.
# If it prints /Library/Developer/CommandLineTools or errors, continue below.
```

**Step 1a — Download Xcode**

Pick one method:

- **Mac App Store (easiest):** Open the App Store, search "Xcode", click Get/Install. This auto-installs to `/Applications/Xcode.app`.
- **Direct download:** Go to https://developer.apple.com/xcode/ and click the download link. Requires a free Apple ID. Move the `.app` to `/Applications/` after extracting.

> Xcode is ~3 GB to download and ~35 GB installed. Make sure you have disk space.

**Step 1b — Set the active developer directory**

After installation completes, point `xcode-select` to the full Xcode:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

**Step 1c — Accept the license**

```bash
sudo xcodebuild -license accept
```

**Step 1d — Install additional components**

Launch Xcode once to trigger its first-run setup. It will download simulator runtimes and other components:

```bash
open -a Xcode
```

Wait for the "Installing components..." dialog to finish, then quit Xcode.

Alternatively, install the iOS 18 simulator runtime from the CLI:

```bash
xcodebuild -downloadPlatform iOS
```

**Step 1e — Verify**

```bash
# Confirm Xcode is active:
xcode-select -p
# Expected: /Applications/Xcode.app/Contents/Developer

# Confirm version:
xcodebuild -version
# Expected: Xcode 16.x

# Confirm simulator runtimes are available:
xcrun simctl list runtimes | grep iOS
# Expected: iOS 18.x
```

### 2. Generate the Xcode Project

Install XcodeGen if you don't have it:

```bash
brew install xcodegen
```

Generate the `.xcodeproj`:

```bash
cd ios/   # or wherever this repo is checked out
xcodegen generate
```

This reads `project.yml` and creates `ClinicalTrialHealth.xcodeproj`.

### 3. Build from CLI

```bash
xcodebuild \
  -project ClinicalTrialHealth.xcodeproj \
  -scheme ClinicalTrialHealth \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

### 4. Run in Simulator

Boot the simulator and install:

```bash
# Boot simulator
xcrun simctl boot "iPhone 16"

# Build and install
xcodebuild \
  -project ClinicalTrialHealth.xcodeproj \
  -scheme ClinicalTrialHealth \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  install

# Or open in Xcode and press Cmd+R
open ClinicalTrialHealth.xcodeproj
```

## Usage

### Connecting to the Backend

1. Start the Clinical Trial Copilot backend:
   ```bash
   cd /path/to/clinical-trial-copilot
   uvicorn backend.main:app --port 8100
   ```

2. In the iOS app, enter your **Session ID** (from the web app URL, e.g., `abc123`)

3. Tap **Connect to Health** to authorize HealthKit access

4. Tap **Fetch Health Data** to read from HealthKit

5. Tap **Send Health Data** to POST to the backend

### Seeding Sample Data (Simulator)

In Debug builds, a **Seed Sample Data** button appears. This populates HealthKit with synthetic data matching the demo profile:

- Steps: ~5,500/day (30 days)
- Exercise: ~35 min/day (30 days)
- Weight: 165 lbs
- Height: 5'9"
- BMI: 24.4
- Heart Rate: 78 bpm
- Blood Pressure: 128/82 mmHg

### Network Configuration

| Environment | Backend URL |
|---|---|
| Simulator | `http://localhost:8100` |
| Device | `https://clinical-trial-copilot.fly.dev` |

The URL is selected automatically at compile time via `#if targetEnvironment(simulator)`.

## Architecture

```
ClinicalTrialHealth/
├── ClinicalTrialHealthApp.swift    — App entry point
├── HealthKitManager.swift          — HealthKit auth & queries (@Observable)
├── APIClient.swift                 — JSON POST to backend
├── ContentView.swift               — Main UI (session link, fetch, send)
├── HealthSummaryView.swift         — Data summary display
├── Info.plist                      — Privacy usage descriptions
└── ClinicalTrialHealth.entitlements — HealthKit entitlement
```

## Verification

Take a simulator screenshot to verify the UI:

```bash
xcrun simctl io booted screenshot /tmp/clinical-trial-health.png
open /tmp/clinical-trial-health.png
```

## License

Part of the [Clinical Trial Copilot](https://github.com/jknoll/clinical-trial-copilot) project.
