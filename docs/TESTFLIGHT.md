# Releasing to TestFlight — without a Mac

## TL;DR (the condensed RollnWrite version)

Loop/Trio's guides are long because of `match`, App Groups, and multi-target
signing. Ours is shorter — one app, cloud signing, **3 secrets, 2 clicks**:

1. **Pay** for the Apple Developer Program ($99/yr) — the only hard requirement.
2. In **App Store Connect**, create the app record using bundle id
   **`dev.bo3.RollnWrite`**, and an **API key** (App Manager role) → note **Key
   ID**, **Issuer ID**, download the **`.p8`** (one-time download!).
3. Add **3 GitHub secrets**: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`.
   (Bundle id `dev.bo3.RollnWrite` and Team ID `794HF2GP3T` are already baked
   into the project — no secret needed. Override them with optional
   `APP_BUNDLE_ID` / `APPLE_TEAM_ID` secrets only if you fork to a new account.)
4. The **1024×1024 app icon** is already committed, so nothing to add.
5. **Actions tab → 1. Validate Secrets → Run** (1 min sanity check) → **Actions
   → 2. TestFlight → Run** (~15 min). Add yourself as an internal tester,
   install the TestFlight app on your iPhone — done.

A scheduled rebuild runs monthly so your build never hits the 90-day TestFlight
expiry. Full step-by-step below.

---

You can build, sign, and ship RollnWrite to TestFlight entirely from your
browser. A GitHub-hosted macOS runner does the Xcode work; Apple's servers do
the signing (App Store Connect API key + automatic **cloud signing**). You never
touch Xcode or a Mac.

The pipeline is driven by **fastlane** (`fastlane/Fastfile`), the same tool the
Loop/Trio/iAPS DIY apps use for browser-only builds. The Actions tab lists the
workflows in run order:

- **1. Validate Secrets** (`validate_secrets.yml`) — a ~1-minute preflight that
  proves your secrets work before any real build.
- **2. TestFlight** (`testflight.yml`) — builds, cloud-signs, and uploads a new
  build to TestFlight. Runs on **every code push** to `main`/`claude/**` (doc
  changes skipped), plus a monthly rebuild, plus manual *Run workflow*.
- **3. iOS Build** (`ios.yml`) — automatic compile-check on every push/PR (no
  signing); this is the no-Mac way to confirm the project still builds.
- **4. Bump Version** (`bump_version.yml`) — manual helper to set the marketing
  version (e.g. 1.0 → 1.1) for the next release. The build number itself
  auto-increments, so you only run this to change the visible version.

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
3. **Bundle ID**: click the dropdown and pick **`dev.bo3.RollnWrite`**. If it's
   not there yet, first register it at
   <https://developer.apple.com/account/resources/identifiers/list> →
   **+** → **App IDs** → **App** → bundle id `dev.bo3.RollnWrite`, **all
   capabilities unchecked** (the app needs none). This exact string is already
   set in the Xcode project, so don't invent a new one.
4. SKU: any string (e.g. `rollnwrite01`). Finish creating the app.

> The Team ID (`794HF2GP3T`) and bundle id (`dev.bo3.RollnWrite`) are already
> committed in the project, so you do **not** need to add them as secrets — only
> the three API-key values below.

### 2. Create an App Store Connect API key

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

### 3. Add the three GitHub secrets

In this repo: **Settings → Secrets and variables → Actions → New repository
secret**. Add each of these:

| Secret name     | Value                                                        |
|-----------------|--------------------------------------------------------------|
| `ASC_KEY_ID`    | API Key ID from step 2                                       |
| `ASC_ISSUER_ID` | API Issuer ID from step 2                                    |
| `ASC_KEY_P8`    | The entire text of the `AuthKey_XXXXXX.p8` file from step 2  |

Optional overrides (only if you fork to a different Apple account): set
`APP_BUNDLE_ID` and/or `APPLE_TEAM_ID` to replace the committed defaults.

### 4. App icon & encryption — already done

- A compliant **1024×1024** icon (no alpha) is committed at
  `RollnWrite/Assets.xcassets/AppIcon.appiconset/AppIcon.png`. Swap the PNG any
  time to rebrand.
- `ITSAppUsesNonExemptEncryption = NO` is set in the project, so TestFlight
  won't ask the export-compliance question on every upload.

---

## Releasing

1. **Preflight (recommended the first time):** Actions tab → **1. Validate
   Secrets** → **Run workflow**. In ~1 minute it confirms your API key
   authenticates and can see the app. Green check = your secrets are good. Fix
   any reported problem before building.
2. Actions tab → **2. TestFlight** → **Run workflow** → pick the
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

## Keeping your build fresh (automatic monthly rebuilds)

A TestFlight build **stops working 90 days after upload**. So, like Loop and
Trio, the TestFlight workflow also runs on a schedule — **06:37 UTC on the 1st
of every month** — and uploads a fresh build (the build number just bumps; no
code change needed). You don't have to do anything; the app keeps working.

- **To turn it off:** delete the `schedule:` block in
  `.github/workflows/testflight.yml`. You can always build manually instead.
- **Heads-up (from LoopDocs):** GitHub disables scheduled workflows after **60
  days with no repository activity**. If you go quiet for two months, the
  monthly build won't fire — re-enable it from the Actions tab, or just run it
  manually, and any push re-arms the schedule.

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

- **"No profiles for 'dev.bo3.RollnWrite' were found"** — the App ID isn't
  registered yet, or the API key lacks access. Re-check step 1 (register the
  bundle id) and step 2 (key role = App Manager).
- **"Authentication credentials are invalid"** — `ASC_KEY_P8` is truncated.
  Re-paste the *entire* file contents, including the BEGIN/END lines and
  trailing newline.
- **"Missing app icon" / "asset validation failed"** — the committed icon
  should prevent this; if you swapped it, make sure the replacement is exactly
  1024×1024 with no alpha channel.
- **"Redundant binary upload" / duplicate build number** — re-run the
  workflow; the build number is `latest TestFlight build + 1`, so a fresh run
  gets a new one automatically.
