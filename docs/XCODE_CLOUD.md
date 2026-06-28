# Building with Xcode Cloud

This project is ready to build with **Xcode Cloud**. The repository already
contains everything Xcode Cloud needs:

- `RollnWrite.xcodeproj` — the app project.
- A **shared scheme** named `RollnWrite`
  (`RollnWrite.xcodeproj/xcshareddata/xcschemes/RollnWrite.xcscheme`). Xcode
  Cloud can only build shared schemes.

## One-time setup (in App Store Connect / Xcode)

1. In Xcode, open `RollnWrite.xcodeproj` and sign in with your Apple ID under
   **Settings → Accounts**.
2. Select the project → **Signing & Capabilities**. Set your **Team**. Signing
   is `Automatic`; Xcode Cloud manages cloud signing certificates for you.
3. Update **Bundle Identifier** if needed. It currently defaults to
   `com.sjoerdbo3.RollnWrite` — change it to one your team owns.
4. Open **Product → Xcode Cloud → Create Workflow** (or do this in App Store
   Connect → your app → **Xcode Cloud**).
5. Choose the GitHub repository `sjoerd-bo3/rollnwrite` and grant access.
6. Pick the **`RollnWrite`** scheme.

## Suggested workflow

- **Start condition:** push to the working branch / `main`, or pull requests.
- **Environment:** latest Xcode 16 (required — the project uses
  `objectVersion = 77`).
- **Actions:**
  - **Build** — `RollnWrite` scheme, *Any iOS Device*. Good for CI on every push.
  - (Optional) **Archive** — for TestFlight distribution. Requires the Team set
    above; cloud signing is automatic.

No `ci_scripts` are required: the app has no third-party dependencies or code
generation. If you later add dependencies that need bootstrapping, add
`ci_scripts/ci_post_clone.sh` at the repo root.

## Notes

- The app is universal (iPhone + iPad). For the App Store you'll need to provide
  a 1024×1024 App Icon in `RollnWrite/Assets.xcassets/AppIcon.appiconset`
  (currently a placeholder slot with no image, which builds fine for CI).
