# App Store submission checklist — Roll'n Write

Everything needed to take the app from TestFlight to the App Store. The build
pipeline (fastlane match → TestFlight) is already done; this covers the
**App Store Connect** metadata and review steps, all doable from a browser.

---

## 0. Before you start

- [ ] App record exists in App Store Connect (bundle id `dev.bo3.RollnWrite`).
- [ ] At least one build is processed in TestFlight (build #10 ✅).
- [ ] Export compliance already declared in the app
      (`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`) — **no per-build
      prompt**, and on the App Store form answer "uses encryption: No".

## 1. App Privacy — "Data Not Collected"

The app collects nothing and makes no network calls, so:

- App Store Connect → your app → **App Privacy** → **Data Collection** →
  **"No, we do not collect data from this app."**
- That's the whole section — no data types, no tracking.
- **Privacy Policy URL** is still required. Use the bundled [`PRIVACY.md`](../PRIVACY.md),
  hosted at a public URL once the repo is public, e.g.
  `https://github.com/Sjoerd-Bo3/rollnwrite/blob/main/PRIVACY.md`
  (or enable GitHub Pages for a cleaner URL).

## 2. ⚠️ Trademarks — read this first

The app is an **unofficial** scorecard. *Qwixx* (NSV) and the *Clever* series
(Wolfgang Warsch / Schmidt Spiele) are third-party trademarks. App Review
enforces **Guideline 5.2 (Intellectual Property)**, and apps that lean on
another company's trademarks can be rejected.

To stay safe:

- [ ] **App name / subtitle:** keep generic — "Roll'n Write" is good. Do **not**
      name the app "Qwixx …" or "… Clever".
- [ ] **Description / keywords:** describe *compatibility* factually
      ("a scorecard for popular roll-and-write dice games") rather than implying
      it's the official product. Minimise trademark use; never claim affiliation.
- [ ] Include the disclaimer (see the README) in the description.
- [ ] If you want to use the names prominently, get written permission from the
      rights holders first.

## 3. Metadata to prepare

| Field | Limit | Notes |
|---|---|---|
| App name | 30 chars | "Roll'n Write" |
| Subtitle | 30 chars | e.g. "Scorecards for dice games" |
| Promotional text | 170 chars | editable without a new build |
| Description | 4000 chars | features + the disclaimer |
| Keywords | 100 chars | comma-separated; mind trademarks (§2) |
| Support URL | — | the repo or a contact page |
| Marketing URL | optional | — |
| Privacy Policy URL | required | the `PRIVACY.md` link (§1) |
| Primary category | — | **Utilities** or **Entertainment** (the "Games" category implies it *is* a game; a scorecard helper fits Utilities better) |
| Age rating | — | **4+** (no objectionable content) |
| Price | — | Free / paid tier |

## 4. Screenshots

Required display sizes (App Store Connect accepts these and scales down):

- [ ] **iPhone 6.9"** — 1290 × 2796 (portrait) or **2796 × 1290 (landscape)**.
- [ ] **iPad 13"** — 2048 × 2732 (portrait) or **2732 × 2048 (landscape)**.

Because the single-player scorecards run in **landscape** on iPhone, capture
landscape screenshots. 3–6 per device is plenty. Good shots: Qwixx Big Points
mid-game, a Clever board, the in-app rules sheet, the two-player mirrored view.

Capture them in TestFlight on a device, or from the Xcode Simulator if you get
Mac access; otherwise any landscape device screenshots at the right resolution
work.

## 5. App Review notes

Make the reviewer's life easy:

- [ ] **Sign-in:** none required — the app is fully offline, no account.
- [ ] **Notes:** "Offline digital scorecard for roll-and-write dice games. No
      login, no network, no data collection. Unofficial fan project; not
      affiliated with the game publishers (see disclaimer)."
- [ ] Demo account: not applicable.

## 6. Submit

- [ ] Pick the processed build (#10+) under **Build**.
- [ ] Fill **Export Compliance** → uses encryption: **No**.
- [ ] Set **pricing & availability**.
- [ ] Complete **App Privacy** (§1) and **age rating**.
- [ ] Add screenshots (§4) and metadata (§3).
- [ ] **Submit for Review.**

---

### Notes

- Metadata, screenshots, and the privacy URL can be edited without a new build;
  only binary changes need a fresh TestFlight upload (just push to `main`).
- Keep the disclaimer visible in the description to reduce IP-review friction.
