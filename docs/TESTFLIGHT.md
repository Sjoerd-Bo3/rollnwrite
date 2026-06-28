# Releasing to TestFlight — without a Mac

You can build, sign, and ship RollnWrite to TestFlight entirely from your
browser. A GitHub-hosted macOS runner does the Xcode work; Apple's servers do
the signing (App Store Connect API key + automatic **cloud signing**). You never
touch Xcode or a Mac.

The pipeline is driven by **fastlane** (`fastlane/Fastfile`), the same tool the
Loop/Trio/iAPS DIY apps use for browser-only builds. Two workflows wrap it:

- **Validate Secrets** (`.github/workflows/validate_secrets.yml`) — a ~1-minute
  preflight that proves your secrets work before any real build.
- **TestFlight** (`.github/workflows/testflight.yml`) — builds, cloud-signs, and
  uploads a new build to TestFlight.

> **Why no `match`?** Trio stores its signing certificates in a private
> `Match-Secrets` git repo (needing a `GH_PAT` and `MATCH_PASSWORD`) because it
> has several code-signed targets — a watch app, a complication, a live
> activity — sharing App Groups, where Apple's cloud signing is awkward.
> RollnWrite is a **single target**, so Apple's cloud signing
> (`-allowProvisioningUpdates` + the API key) manages the certificate
> automatically with **no `match`, no extra repo, and two fewer secrets**.

---

## What you need (all browser-based)

1. **An Apple Developer Program membership** ($99/year). Enroll at
   <https://developer.apple.com/programs/enroll/>. This is the only paid step
   and the only hard requirement Apple imposes for TestFlight.
2. A GitHub account with push access to this repo (you have it).

That's it. Everything else is configuration you paste into GitHub.

---

## One-time setup

### 1. Create the app record in App Store Connect

1. Go to <https://appstoreconnect.apple.com> → **Apps** → **+** → **New App**.
2. Platform: **iOS**. Name: `RollnWrite` (or any unique name).
3. **Bundle ID**: click the dropdown — if nothing is there, first register one
   at <https://developer.apple.com/account/resources/identifiers/list> →
   **+** → **App IDs** → **App**. Use something like
   `com.yourname.RollnWrite`. Capabilities: none needed. Remember this exact
   string — it becomes the `APP_BUNDLE_ID` secret.
4. SKU: any string (e.g. `rollnwrite01`). Finish creating the app.

### 2. Find your Team ID

<https://developer.apple.com/account> → scroll to **Membership details** →
copy the 10-character **Team ID** (e.g. `A1B2C3D4E5`). This is `APPLE_TEAM_ID`.

### 3. Create an App Store Connect API key

1. <https://appstoreconnect.apple.com/access/integrations/api> (Users and
   Access → **Integrations** → **App Store Connect API**).
2. Click **+** to generate a key. Name it `RollnWrite CI`. Access role:
   **App Manager** (enough to upload builds).
3. After creating it you'll see:
   - **Key ID** (e.g. `2X9ABC3DEF`) → `ASC_KEY_ID`
   - **Issuer ID** (a UUID at the top of the page) → `ASC_ISSUER_ID`
   - A **Download** link for the `AuthKey_XXXXXX.p8` file. **Download it now —
     Apple only lets you download it once.** Open it in any text editor; its
     full contents (including the `-----BEGIN PRIVATE KEY-----` lines) become
     `ASC_KEY_P8`.

### 4. Add the five GitHub secrets

In this repo: **Settings → Secrets and variables → Actions → New repository
secret**. Add each of these:

| Secret name     | Value                                                        |
|-----------------|--------------------------------------------------------------|
| `APPLE_TEAM_ID` | Your 10-char Team ID from step 2                             |
| `APP_BUNDLE_ID` | The bundle id from step 1 (e.g. `com.yourname.RollnWrite`)   |
| `ASC_KEY_ID`    | API Key ID from step 3                                       |
| `ASC_ISSUER_ID` | API Issuer ID from step 3                                    |
| `ASC_KEY_P8`    | The entire text of the `AuthKey_XXXXXX.p8` file from step 3  |

### 5. App icon (required by App Store Connect)

TestFlight rejects builds without a marketplace icon. Make sure
`Assets.xcassets/AppIcon.appiconset` contains a 1024×1024 PNG (no alpha,
no transparency). If you don't have one yet, generate any solid 1024px PNG and
drop it in — you can refine it later. A build with a placeholder icon still
installs fine on your phone.

---

## Releasing

1. **Preflight (recommended the first time):** Actions tab → **Validate
   Secrets** → **Run workflow**. In ~1 minute it confirms your API key
   authenticates and can see the app. Green check = your secrets are good. Fix
   any reported problem before building.
2. Actions tab → **TestFlight** → **Run workflow** → pick the
   `claude/qwixx-scorecard-ios-app-1gmje1` branch → **Run workflow**.
3. The job (~10–15 min) picks the next build number (latest on TestFlight + 1),
   builds, cloud-signs via your API key, and uploads. Watch the logs if you like.
4. The build then **processes on Apple's side** for a few more minutes. Track
   it at App Store Connect → your app → **TestFlight** tab.

### Installing on your iPhone

1. Once the build shows **Ready to Test**, add yourself as an **Internal
   Tester**: App Store Connect → your app → **TestFlight** → **Internal
   Testing** → create a group → add your Apple ID email.
2. Install **TestFlight** from the App Store on your iPhone, sign in with that
   same Apple ID, and the RollnWrite build appears. Tap **Install**.

Internal testers get builds immediately with no Apple review. (External testing
requires a one-time Beta App Review, which you don't need just to test on your
own phone.)

---

## How the workflow signs without a Mac

- fastlane's **`build_app`** runs `xcodebuild` with `-allowProvisioningUpdates`
  and the App Store Connect API key, so Apple's servers create/refresh the
  signing certificate and provisioning profile on the fly (**cloud signing**) —
  no manual certificate juggling, no Keychain, no `match`.
- fastlane's **`upload_to_testflight`** sends the signed `.ipa` to App Store
  Connect with a changelog (branch + commit), and handles upload retries.
- **`latest_testflight_build_number + 1`** picks the next build number
  automatically, so every upload is unique and increasing (App Store Connect
  rejects duplicates). `MARKETING_VERSION` is pinned to `1.0`. Neither value is
  written into `project.pbxproj` — they're passed at build time.
- The API key is supplied to fastlane purely through the `ASC_KEY_P8`
  environment variable; nothing is written to disk by the workflow.

---

## Troubleshooting

- **"No profiles for '…' were found"** — the bundle id in `APP_BUNDLE_ID`
  doesn't match a registered App ID, or the API key lacks access. Re-check
  steps 1 and 3.
- **"Authentication credentials are invalid"** — `ASC_KEY_P8` is truncated.
  Re-paste the *entire* file contents, including the BEGIN/END lines and
  trailing newline.
- **"Missing app icon" / "asset validation failed"** — add the 1024×1024 icon
  (step 5) and re-run.
- **"Redundant binary upload" / duplicate build number** — re-run the
  workflow; the build number tracks the run number, so a fresh run gets a new
  one automatically.
