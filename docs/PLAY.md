# Releasing to Google Play — without touching a build machine by hand

## TL;DR (the condensed RollnWrite version)

Same shape as `docs/TESTFLIGHT.md`: a GitHub-hosted runner builds and signs;
your job is browser clicks + secrets.

1. **Pay** the one-time $25 Google Play registration fee (if you haven't
   already) at <https://play.google.com/console/signup>.
2. Create the **app record** in Play Console (name `RollnWrite`, free), fill
   in the declarations screens, and enrol in **Play App Signing** using the
   upload keystore already generated at
   `~/Keys/rollnwrite-android/upload-keystore.jks` (alias `rollnwrite-upload`).
3. Add **2 GitHub secrets** now — `PLAY_KEYSTORE_B64`, `PLAY_KEYSTORE_PASSWORD`
   — and run **Actions → 8. Android Release** to get a signed `.aab` as a
   workflow artifact.
4. **Upload that first `.aab` by hand** in Play Console → Internal testing
   (the Play Developer API can't create the first release for a brand-new
   app — see step (d) below). Every upload after that can go through the API.
5. Later, create a **service account**, add `PLAY_SERVICE_ACCOUNT_JSON` as a
   3rd secret, and workflow 8 starts uploading straight to the internal track
   for you.
6. To eventually reach **production**, run a closed test first: 12 opted-in
   testers, active for 14 continuous days, then apply for production access
   (~7-day Google review). See the dates math in step (e).

Full step-by-step below.

---

## What you need (all browser-based, except the keystore which lives locally)

1. A Google Play Developer account ($25 one-time registration fee) —
   <https://play.google.com/console/signup>.
2. The upload keystore, already generated and sitting at
   `~/Keys/rollnwrite-android/upload-keystore.jks` on the dev machine (alias
   `rollnwrite-upload`; the store and key share one password, recorded in
   `~/Keys/rollnwrite-android/README.txt` — keep both files out of git, they
   never belong in this repo).
3. A GitHub account with push access to this repo (you have it).

---

## One-time setup

### (a) Create the app record + declarations

1. Play Console → **All apps** → **Create app**.
2. **App name**: `RollnWrite`. **Default language**: English (add nl/de later
   if you want localised store listings — the app itself is already
   localised, see root `CLAUDE.md`). **App or game**: App. **Free or paid**:
   Free. Accept the Developer Program Policies + US export laws
   declarations, then **Create app**.
3. Play Console walks you through **Dashboard → Set up your app**, which is
   the actual list of "declarations screens" — work through each:
   - **App access** — declare whether any part of the app requires special
     access (login, etc.). RollnWrite has no login: declare all
     functionality is available without restrictions.
   - **Ads** — declare whether the app shows ads (it doesn't).
   - **Content ratings** — fill in the questionnaire (IARC); a scorecard app
     with no violence/gambling-simulation content rates as the lowest tier
     everywhere.
   - **Target audience and content** — select the target age group(s).
   - **Data safety** — declare what data the app collects. RollnWrite stores
     scores locally (`UserDefaults`-equivalent on Android) and sends nothing
     off-device, so declare **no data collected or shared**. (Internal-testing-
     only releases are exempt from this form, but fill it in anyway now — it's
     required the moment you move to closed testing or production, and doing
     it once up front avoids a blocked release later.)
   - **Government apps**, **Financial features**, etc. — not applicable;
     Play Console skips/greys these out when they don't apply.
   - **Store listing** — short/full description, screenshots (phone at
     minimum), 512×512 icon, feature graphic. Reuse the iOS App Store
     screenshots/icon as a starting point.
4. **Play App Signing**: Play Console → **Setup** → **App integrity** → **App
   signing**. When you upload your very first release (step (d) below), Play
   Console prompts you to either let Google generate a new app signing key or
   **use your own upload key** — choose to continue with the upload keystore
   you already have (`rollnwrite-upload`). Google then generates and holds the
   *app signing key* it actually ships to users; your local `.jks` becomes
   purely an *upload* key used to authenticate builds to Google, which is
   Google's recommended model (fixes what used to be a single non-rotatable
   signing key).
   - **If the upload key is ever lost or compromised**: it's resettable.
     Play Console → App integrity → App signing → **Request upload key
     reset**, follow the identity-verification flow. The app signing key
     that actually matters to users is unaffected — this is exactly why Play
     App Signing exists.

### (b) Add the two keystore secrets

```bash
# Base64-encode the keystore (no newlines) and set both secrets:
gh secret set PLAY_KEYSTORE_B64 --repo Sjoerd-Bo3/rollnwrite \
  --body "$(base64 -i ~/Keys/rollnwrite-android/upload-keystore.jks | tr -d '\n')"

gh secret set PLAY_KEYSTORE_PASSWORD --repo Sjoerd-Bo3/rollnwrite \
  --body "$(grep password ~/Keys/rollnwrite-android/README.txt | cut -d' ' -f2)"
```

(Swap the `--repo` owner/name if this is run from a fork.) Verify:

```bash
gh secret list --repo Sjoerd-Bo3/rollnwrite
```

You should see `PLAY_KEYSTORE_B64` and `PLAY_KEYSTORE_PASSWORD` listed (values
are never shown back).

### (c) Service-account setup (for automatic API uploads)

This step is what lets workflow 8 upload to Play **without** you downloading
and re-uploading the `.aab` by hand every time. Do it whenever — before or
after the first manual upload — but the upload-to-Play step in the workflow
stays a no-op until `PLAY_SERVICE_ACCOUNT_JSON` is set.

1. **Create/select a GCP project**: <https://console.cloud.google.com> → pick
   or create a project (e.g. `rollnwrite-play`).
2. **Enable the Android Publisher API**: in that project, go to **APIs &
   Services → Library**, search **Google Play Android Developer API**,
   click **Enable**.
3. **Create a service account**: **IAM & Admin → Service Accounts → Create
   Service Account**. Name it e.g. `play-publisher-ci`. No project-level
   role needed (permissions are granted inside Play Console instead, step
   below).
4. **Create its JSON key**: open the new service account → **Keys** tab →
   **Add Key → Create new key → JSON**. This downloads a `.json` file —
   treat it like a password, it's the entire credential.
5. **Invite it in Play Console**: Play Console → **Users and permissions** →
   **Invite new users** → enter the service account's email address (the
   `...@...iam.gserviceaccount.com` address from its Details tab) → under
   **App permissions** add **RollnWrite** and grant at minimum **Release to
   testing tracks** → **Send invite** (service accounts auto-accept — there's
   no separate confirmation step). Google removed the requirement to link
   the developer account to a GCP project first; the API access page no
   longer offers a "Link project" flow for new setups.
6. *(no separate permission-grant step — access is granted directly on the
   invite in step 5 above)*
7. **Set the third secret**:
   ```bash
   gh secret set PLAY_SERVICE_ACCOUNT_JSON --repo Sjoerd-Bo3/rollnwrite \
     --body "$(cat /path/to/downloaded-key.json)"
   ```

### (d) Release flow

1. Actions tab → **8. Android Release** → **Run workflow** → pick the branch
   → **Run workflow**.
2. The job (~2–5 min) decodes the keystore, builds a signed `.aab` with an
   auto-incrementing `versionCode` (`github.run_number + 1000` by default —
   see the comment in `.github/workflows/android-release.yml` for the offset
   rationale; override it with the workflow's `version_code` input if you
   ever need an exact value), and **always** uploads it as a workflow
   artifact named `app-release-aab`.
3. **First release only** (no app record has ever received a bundle yet):
   download that artifact from the workflow run summary, then Play Console →
   your app → **Testing → Internal testing → Create new release** →
   upload the `.aab` manually → **Save → Review release → Roll out**. This
   manual step is unavoidable: the Play Developer API refuses to create the
   very first release for an app that doesn't have at least one existing
   release yet.
4. **Every release after that**, once `PLAY_SERVICE_ACCOUNT_JSON` is set (see
   (c)): the workflow's upload step runs automatically and pushes straight to
   the **internal** track with `status: completed` — no manual step needed.
5. Add internal testers: Play Console → Testing → Internal testing →
   **Testers** tab → create/edit the tester list (by email or a Google
   Group) → share the opt-in link so they can install via the Play Store.

### (e) The path from internal testing to production

Google requires **closed testing before production** for personal developer
accounts created after 2023-11-13 (RollnWrite's account qualifies — assume
this applies unless you know otherwise):

1. **Internal testing** (workflow 8's default track) — instant, up to 100
   testers, no review. Good for you and a couple of friends right now.
2. **Closed testing** — create a closed track (Play Console → Testing →
   Closed testing → create a track, e.g. "Closed"), add it as a promotion
   target from internal or upload directly. Requirements to unlock
   **production access**:
   - **≥ 12 testers opted in** (real Google accounts on real devices — no
     emulators, no duplicate/bot accounts).
   - **Opted in continuously for the last 14 days** at the moment you apply
     — the clock only counts days where the 12-tester threshold holds
     continuously; it is not "any 14 days ever."
   - **Engagement matters**: adding 12 emails to the tester list does not by
     itself satisfy the requirement — each person must actually accept the
     opt-in and the app must show real usage; Google's review can and does
     reject applications with low engagement even after 14 days have
     nominally passed.
   - **Dates math for planning**: if you get 12 engaged testers opted in
     starting **today (2026-07-06)**, day 14 lands **2026-07-20**; the
     earliest you'd realistically apply for production access is that date.
     Add Google's review window on top (see below) — realistic go-live is
     **~2026-07-27**, assuming testers stay engaged the whole window and the
     review doesn't need a second pass.
3. **Apply for production access**: Play Console prompts you for this once
   the 12-testers/14-days condition is met (Dashboard → a banner/task
   appears, or Testing → Closed testing → **Apply for production access**).
4. **Review time**: Google's stated review is **~7 days or less** in most
   cases, but can take longer, and uploading a new build right before or
   during review can reset/complicate it — freeze the build once you apply.
5. Once approved, promote the tested release to **Production** (Play Console
   → Production → **Create release** → promote from the closed track, or
   upload fresh) and roll out — staged rollout percentages are optional but
   recommended for a first production release.

---

## `applicationId` is permanent — do not change it

`dev.bo3.rollnwrite` (set in `android/app/build.gradle.kts`) is baked into
the Play Console app record the moment the first release is uploaded. There
is **no supported way to change an app's package name/applicationId** after
that without publishing an entirely new app listing (losing all reviews,
install counts, and the existing user base's update path). Treat it exactly
like the iOS bundle id (`dev.bo3.RollnWrite`) — fixed for the app's lifetime.
If a rename is ever truly required, it means shipping a new Play Store
listing, not editing this value.

---

## Troubleshooting

- **"You need to use a different package name" / upload rejected on first
  manual upload** — Play Console locks the `applicationId` to whatever the
  very first uploaded bundle declares; if you test-uploaded a bundle with a
  placeholder id before this pipeline existed, you'll need a fresh app
  record.
- **API upload step fails with a 403 / permission error** — the service
  account either isn't granted access to this specific app (step (c).5) or
  the Android Publisher API isn't enabled on the linked GCP project (step
  (c).2).
- **"APK/Bundle was already used" / duplicate versionCode** — start a **new**
  run via Actions → **8. Android Release** → **Run workflow** (the **Re-run
  jobs** button reuses the same `run_number` and therefore the same
  `versionCode` — it will hit the exact same duplicate error). Only collides
  on a fresh run if you manually pass an explicit `version_code` input that's
  already been used.
- **Signed bundle won't build locally** — confirm `PLAY_KEYSTORE_FILE` points
  at the real `.jks` path and `PLAY_KEYSTORE_PASSWORD` matches
  `~/Keys/rollnwrite-android/README.txt` exactly (one password serves both
  store and key for this keystore).
- **"Only releases with status draft may be created on draft app"** — the
  first manual internal release was saved but not rolled out; go to
  **Testing → Internal testing** and complete the **Roll out**, then
  re-dispatch the workflow.
