---
name: ios-testflight-no-mac
description: Ship a SwiftUI/iOS app to TestFlight and the App Store from a browser with NO Mac, using GitHub Actions (macOS runners) + fastlane match. Use when setting up, porting, or debugging a browser-only iOS release pipeline — code signing, certificate storage/renewal, the App Store Connect API key, and the specific errors that come up (Repository not found, invalid branch, readonly nuke, signing identity, profile spaces). Also covers conserving Actions minutes, export compliance, and App Store prep.
---

# No-Mac iOS → TestFlight / App Store pipeline

Build, sign, and upload a SwiftUI app to TestFlight entirely on GitHub-hosted
macOS runners, driven by fastlane. No local Mac. Code signing uses **fastlane
match** (cert + profile stored encrypted in a private git repo). This skill is
the battle-tested setup plus every gotcha, each of which cost a debug cycle.

## When to use

- Standing up CI/CD for a new SwiftUI/iOS app with no Mac available.
- Porting this pipeline to another app (change bundle id / team id, reuse certs).
- Debugging a match/signing/upload failure (jump to **Troubleshooting**).

## Prerequisites (all browser-doable)

1. **Apple Developer Program** membership; note your **Team ID** (10 chars).
2. **App Store Connect → API key** (Users and Access → Integrations → App Store
   Connect API): role **Admin** or **App Manager** (needed so match can
   create/revoke certificates). Save the **Key ID**, **Issuer ID**, and the
   `AuthKey_XXXX.p8` text.
3. An **app record** in App Store Connect with your bundle id.
4. A **private `Match-Secrets` repo** to hold the encrypted cert + profiles
   (can be shared across your apps — distribution certs are per-team).
5. A **GitHub PAT** (`GH_PAT`) that can read/write the `Match-Secrets` repo.

## Secrets to add (repo → Settings → Secrets and variables → Actions)

| Secret | What |
|---|---|
| `ASC_KEY_ID` | App Store Connect API key id |
| `ASC_ISSUER_ID` | API key issuer id |
| `ASC_KEY_P8` | full text of the `AuthKey_XXXX.p8` (incl. BEGIN/END lines) |
| `MATCH_PASSWORD` | passphrase that encrypts the match repo |
| `GH_PAT` | PAT with access to the `Match-Secrets` repo |

Bundle id and Team ID are **not secret** — bake them into the Fastfile as
defaults (they ship in every binary). `MATCH_GIT_URL` is set in the workflow.

---

## The 9 gotchas (each one is a real failure mode)

1. **match git auth must be `base64("<owner>:<PAT>")`, not `x-access-token:<PAT>`.**
   `x-access-token` only authenticates GitHub *App* installation tokens; a PAT
   with that username fails and GitHub returns **`Repository not found`** (404)
   for the private repo. Use the account owner as the basic-auth username.

2. **The PAT must belong to an account that can actually see `Match-Secrets`.**
   A valid token for the *wrong* account → 404. Verify with a probe:
   `curl -H "Authorization: Bearer $GH_PAT" https://api.github.com/user` (check
   `login`) and `.../repos/<owner>/Match-Secrets` (expect HTTP 200, not 404).

3. **Never pass an empty `MATCH_GIT_BRANCH`.** fastlane `match` auto-reads it
   from the environment; an unset secret arrives as `""` and overrides the
   default branch (`master`) → **`fatal: '' is not a valid branch name`**. Just
   don't set the env var.

4. **`setup_ci` enables match readonly mode.** Pass `readonly: false` explicitly
   to `match` *and* `match_nuke`, or the nuke reports
   **"doesn't delete anything when running with --readonly enabled"** and certs
   never renew.

5. **Auto-renew expired certs, but only on the specific error.** When the stored
   distribution cert expires, match raises *"… is not valid, please … renew it"*.
   Rescue *only* that error (regex), `match_nuke` + `match` to recreate, then
   retry. Re-raise everything else so a transient failure can't nuke the store.

6. **Shell-escape build settings that contain spaces.** `xcargs` is space-joined
   and run through a shell. The match profile name is `match AppStore <bundle>`
   (spaces!) — unescaped, xcodebuild sees only `PROVISIONING_PROFILE_SPECIFIER=match`
   and signing fails. Use `String#shellescape` (and `require "shellwords"`).

7. **Pin `CODE_SIGN_IDENTITY=Apple Distribution` for App Store archives.** Without
   it the archive falls back to the project default ("iOS Development") →
   **"No signing certificate 'iOS Development' found"**. (Also has a space →
   escape it.)

8. **`match_nuke` is team-wide and destructive.** It revokes the distribution
   cert and deletes *all* App Store profiles in the repo — affecting every app
   sharing that `Match-Secrets`. Each app regenerates its profile on its next
   build; shipped builds are unaffected. Fine for a single-owner account, but
   know the blast radius before automating it.

9. **The `ASC_KEY_P8` secret is fragile.** Newlines get mangled on paste.
   Reconstruct a clean PEM in the Fastfile (strip armor, keep base64 body,
   re-wrap at 64 chars) and validate with OpenSSL before use — fixes
   *"invalid curve name"* / empty-key errors.

---

## Fastfile (template)

`fastlane/Fastfile` — replace `PROJECT`/`SCHEME` and the two defaults.

```ruby
default_platform(:ios)
PROJECT = "YourApp.xcodeproj"
SCHEME  = "YourApp"
DEFAULT_BUNDLE_ID = "com.example.YourApp"
DEFAULT_TEAM_ID   = "XXXXXXXXXX"

require "base64"; require "openssl"; require "shellwords"

def env_or(n, d); v = ENV[n]; v.nil? || v.strip.empty? ? d : v.strip; end
def bundle_id; env_or("APP_BUNDLE_ID", DEFAULT_BUNDLE_ID); end
def team_id;   env_or("APPLE_TEAM_ID", DEFAULT_TEAM_ID);   end

# Rebuild a clean PEM no matter how ASC_KEY_P8 was pasted (gotcha #9).
def clean_p8_pem(raw)
  raw = raw.to_s.strip.gsub('\\r\\n', "\n").gsub('\\n', "\n").gsub("\r\n", "\n")
  text = raw.include?("PRIVATE KEY") ? raw : ((Base64.decode64(raw) rescue ""))
  text = text.include?("PRIVATE KEY") ? text : raw
  text = text.gsub(/-----[^-]*-----/m, "") if text.include?("PRIVATE KEY")
  body = text.gsub(%r{[^A-Za-z0-9+/=]}, "")
  pem  = "-----BEGIN PRIVATE KEY-----\n" + body.scan(/.{1,64}/).join("\n") + "\n-----END PRIVATE KEY-----"
  OpenSSL::PKey.read(pem) # raises on a bad/truncated secret
  pem
end

def asc_api_key
  app_store_connect_api_key(
    key_id: ENV.fetch("ASC_KEY_ID"), issuer_id: ENV.fetch("ASC_ISSUER_ID"),
    key_content: clean_p8_pem(ENV["ASC_KEY_P8"].to_s), is_key_content_base64: false, in_house: false)
end

platform :ios do
  lane :beta do
    key = asc_api_key
    setup_ci
    build_number = latest_testflight_build_number(api_key: key, app_identifier: bundle_id, initial_build_number: 0) + 1

    sign_base = {
      type: "appstore", app_identifier: bundle_id, api_key: key, team_id: team_id,
      storage_mode: "git", git_url: ENV.fetch("MATCH_GIT_URL")
    }
    # gotcha #3: do NOT set git_branch from an empty env var.
    sign_base[:git_branch] = ENV["MATCH_GIT_BRANCH"] unless ENV["MATCH_GIT_BRANCH"].to_s.strip.empty?

    # gotcha #5: self-healing — auto-renew ONLY on the expired-cert error.
    begin
      match(sign_base.merge(readonly: false))
    rescue => e
      raise unless e.message =~ /not valid|expired|renew it|revoked/i
      UI.important("🔁 Distribution cert expired — auto-renewing…")
      match_nuke(sign_base.merge(skip_confirmation: true, readonly: false)) # gotcha #4 + #8
      match(sign_base.merge(readonly: false))
    end

    profile = "match AppStore #{bundle_id}"
    build_app(
      project: PROJECT, scheme: SCHEME, configuration: "Release", export_method: "app-store",
      xcargs: [
        "CODE_SIGN_STYLE=Manual",
        "CODE_SIGN_IDENTITY=#{'Apple Distribution'.shellescape}",     # gotcha #7
        "DEVELOPMENT_TEAM=#{team_id}",
        "PRODUCT_BUNDLE_IDENTIFIER=#{bundle_id}",
        "PROVISIONING_PROFILE_SPECIFIER=#{profile.shellescape}",      # gotcha #6
        "MARKETING_VERSION=1.0", "CURRENT_PROJECT_VERSION=#{build_number}"
      ].join(" "),
      export_options: { method: "app-store", teamID: team_id, signingStyle: "manual",
        provisioningProfiles: { bundle_id => profile }, generateAppStoreInformation: false })

    upload_to_testflight(api_key: key, app_identifier: bundle_id, skip_waiting_for_build_processing: true)
  end
end
```

## Workflow (template)

`.github/workflows/testflight.yml`:

```yaml
name: TestFlight
on:
  workflow_dispatch:
  push:
    branches: [main]
    paths-ignore: ["**.md", "docs/**", "LICENSE"]   # don't waste runs on docs
concurrency: { group: testflight-${{ github.ref }}, cancel-in-progress: true }
jobs:
  testflight:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - uses: maxim-lobanov/setup-xcode@v1
        with: { xcode-version: latest-stable }
      - uses: ruby/setup-ruby@v1
        with: { ruby-version: "3.3", bundler-cache: true }
      - name: Configure match git auth          # gotcha #1: <owner>:<PAT>, NOT x-access-token
        run: |
          AUTH=$(printf '%s' "${{ github.repository_owner }}:${{ secrets.GH_PAT }}" | base64 | tr -d '\n')
          echo "::add-mask::$AUTH"
          echo "MATCH_GIT_BASIC_AUTHORIZATION=$AUTH" >> "$GITHUB_ENV"
      - name: Build & upload
        run: bundle exec fastlane ios beta
        env:
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
          APP_BUNDLE_ID: ${{ secrets.APP_BUNDLE_ID }}
          ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}
          ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
          ASC_KEY_P8: ${{ secrets.ASC_KEY_P8 }}
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          MATCH_GIT_URL: https://github.com/<owner>/Match-Secrets.git
          # gotcha #3: never set MATCH_GIT_BRANCH to an empty secret.
```

`Gemfile`: `source "https://rubygems.org"` + `gem "fastlane"`.

## Actions minutes

macOS runners bill at **10×** and private repos only get 2,000 free min/month.
Two levers:

- **Only build from `main`** (`push: branches: [main]` + `paths-ignore`), and use
  a separate **manual** compile-check workflow (`workflow_dispatch`) instead of
  building on every branch/PR.
- **Make the repo public** → Actions minutes become **unlimited and free**.
  Secrets stay encrypted and are never exposed to fork PRs; a separate private
  `Match-Secrets` repo stays private. Scrub old run logs first if they printed
  internal identifiers (e.g. a `match_nuke` preview lists every app's bundle/
  profile ids).

## Export compliance (skip the per-build prompt)

If the app uses no non-exempt encryption, set in the target's build settings
(generated Info.plist): `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`.
TestFlight then never prompts, and on the App Store form answer "uses
encryption: No".

## App Store prep

- **App Privacy:** a purely-local app (state in `UserDefaults`, no network)
  declares **"Data Not Collected."** A **Privacy Policy URL is still required** —
  host a short policy (a `PRIVACY.md` works once the repo is public).
- **Trademarks (Guideline 5.2):** if the app references third-party games/brands,
  keep the app name generic, describe compatibility factually, add a "not
  affiliated" disclaimer, and don't claim endorsement — or get permission.
- **Screenshots:** iPhone **6.9"** (1290×2796 / 2796×1290 landscape) and, if
  iPad-supported, **13"** (2048×2732 / 2732×2048). Match the app's orientation.

## Troubleshooting (error → cause → fix)

| Log says | Cause | Fix |
|---|---|---|
| `Repository not found` (clone) | wrong auth format **or** PAT can't see the repo | use `<owner>:<PAT>` (gotcha #1); probe `/user` + repo with the token (gotcha #2) |
| `'' is not a valid branch name` | empty `MATCH_GIT_BRANCH` env | don't set it (gotcha #3) |
| `match nuke … doesn't delete … readonly` | `setup_ci` readonly mode | `readonly: false` on `match_nuke` (gotcha #4) |
| `certificate '…' is not valid, please … renew` | stored dist cert expired | auto-renew rescue (gotcha #5) |
| `No signing certificate "iOS Development" found` | archive used dev identity | `CODE_SIGN_IDENTITY=Apple Distribution` (gotcha #7) |
| signing fails, `PROVISIONING_PROFILE_SPECIFIER = match` only | space in profile name word-split | `.shellescape` (gotcha #6) |
| `invalid curve name` / empty key | mangled `ASC_KEY_P8` | `clean_p8_pem` rebuild (gotcha #9) |
| cert create/revoke `not allowed` / 403 | ASC API key role too low | set key to **Admin / App Manager** |
| `maximum number of certificates` | hit Apple's dist-cert cap | reuse the match cert (don't mint per run); nuke+recreate the expired one |

## Porting to a new app

1. New private repo (or reuse) + a `Match-Secrets` repo.
2. Copy `Gemfile`, `fastlane/Fastfile`, `.github/workflows/testflight.yml`.
3. Change `PROJECT`, `SCHEME`, `DEFAULT_BUNDLE_ID`, `DEFAULT_TEAM_ID`, and
   `MATCH_GIT_URL`. Reuse the **same** `Match-Secrets` + `MATCH_PASSWORD` to
   share the team distribution cert across apps.
4. Add the 5 secrets. Push to `main`. First run creates the app's profile.
