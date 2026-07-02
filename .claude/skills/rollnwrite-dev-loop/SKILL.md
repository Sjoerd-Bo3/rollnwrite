---
name: rollnwrite-dev-loop
description: >
  The working loop for developing RollnWrite with NO Mac and no local compiler:
  how to verify Swift changes before pushing, the branch → PR → merge →
  TestFlight cadence, screenshot-driven design iteration with the owner, and
  the parallel-subagent punch-list pattern. Use when making any change to this
  repo, when a TestFlight build fails, or when running a design/rules review.
---

# RollnWrite dev loop (no Mac, no compiler)

There is no Swift toolchain in the dev environment and no Mac anywhere. The
compile check is CI. Everything below exists to make "first compile in CI"
almost always green.

## The cadence

1. Develop on the working branch (reset it from `origin/main` after every
   merge: `git fetch origin main && git checkout -B <branch> origin/main`).
2. Verify locally (checklist below), commit per logical workstream with a
   descriptive body, push, **always open a PR** (owner's standing rule).
3. The owner merges; push-to-main triggers "2. TestFlight" — the real compile
   check (~15–20 min). Watch it. If red: pull the failed job logs
   (`get_job_logs` with `failed_only`), fix the actual Swift errors, push a
   new PR. Iterate to green — green upload is the terminal state.
4. For big/risky batches, ask the owner to click Actions → "3. iOS Build" on
   the branch first (manual compile-only pre-merge check).

## Verification without a compiler (do ALL of these before pushing Swift)

- **Brace balance** per edited file:
  `o=$(tr -cd '{' < f | wc -c); c=$(tr -cd '}' < f | wc -c)` — must match.
- **Call-site sweep**: grep EVERY call site of any signature you changed.
  New parameters get defaults so existing sites compile unchanged.
- **Access levels**: anything used across files must not be `private`
  (beware: a `private @State`/`@ObservedObject` makes the synthesized
  memberwise init non-internal — add an explicit init).
- **Stale references**: after deleting/renaming anything, grep the whole
  `RollnWrite/` tree for the old name. Zero hits or the build is red.
- **Layout unit math**: boards size via unit systems (`BoardMetrics` for
  Qwixx bands, `ScaledSheet` design-space for Clever). If you change any
  height/padding, RE-DERIVE the units from the actual modifiers and write
  the derivation in a comment. Mismatch = overflow on device.
- **xcstrings**: `python3 -c "import json; json.load(open('RollnWrite/Localizable.xcstrings'))"`
  after every edit; new user-facing strings need nl + de entries.
- **Tolerant decoding**: any new stored field in a `Codable` state struct
  needs a custom `init(from:)` with `decodeIfPresent` + defaults for EVERY
  field, or existing players' saves reset (or crash).
- **Ruby/YAML** when touched: `ruby -c fastlane/Fastfile`;
  `python3 -c "import yaml; yaml.safe_load(open(...))"`.

## Screenshot-driven design iteration

The owner tests on TestFlight and returns annotated screenshots. Treat them
as the source of truth for visual defects:

- Read the screenshot files (they arrive as uploads); zoom by cropping with
  PIL when detail matters. Restate each mark as a concrete defect before
  fixing.
- When asked to "review as a design snob": produce a numbered punch list
  (P1 geometry bugs / P2 rhythm & consistency / P3 nits), get the owner's
  go-ahead ("fix all" is common), then implement the list verbatim and
  report per-item. Items verified already-correct are reported as such, not
  silently skipped.
- Fixes are presentation-only unless the owner says otherwise — never touch
  engines/scoring during a design pass.

## Parallel subagent pattern (for multi-workstream batches)

- One subagent per workstream with **strict file ownership** — list the
  owned files and the forbidden files explicitly in each prompt; parallel
  agents must never share a Swift file. `Localizable.xcstrings` is the one
  shared file: instruct each agent to edit it LAST with a fresh
  read-modify-write, and reconcile at review time.
- Review every agent's diff yourself before committing (braces, greps,
  spot-read the risky hunks). Commit each workstream separately.
- Agents sometimes die mid-task (session limits). Their partial work is
  usually good: audit item-by-item against the original spec, finish the
  gaps by hand (past examples: a dangling deleted-component reference; a
  view referenced but never written).
- For rules research: fan out one researcher per game with instructions to
  fetch OFFICIAL sources (nsv.de / schmidtspiele.de PDFs, publisher sheet
  renders) and quote them verbatim; treat product photos as unreliable
  (occlusion has caused real errors — prefer PDFs, sheet renders, or the
  owner's photos of the physical pad, which outrank everything).

## Release

`main` → TestFlight (full app). App Store ships from `release/1.0` via the
manual "5. App Store Release" workflow, which builds with `QWIXX_ONLY`
(trims Clever + the dice-colour Settings section at compile time — a build
flag, never divergent branch code). Checklist: `docs/APP_STORE.md` §7.
After any merge that should ship, re-cut: `git push origin
origin/main:refs/heads/release/1.0 --force-with-lease` (it carries no
unique commits by design).

## Etiquette

- Commit messages: what + why, wrapped body; reference issues
  ("Fixes #NN") so merges auto-close them.
- High-score keys = board display titles — never rename them casually.
- The stop-hook complains about GitHub's own merge commits being
  "unverified" — those are not yours to fix; ignore for merge commits only.
