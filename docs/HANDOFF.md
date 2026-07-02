# Session handoff — state as of PR #47 (2026-07-02)

Paste the prompt at the bottom into a fresh Claude Code session to continue.
Keep this file updated at the end of significant sessions.

## Where things stand

**Shipped to `main` (all compile-verified green via TestFlight):**
- Qwixx: 9 flavours, rules-audited twice against official NSV/WGG sources;
  feature-complete (concede, manual finish, game-over + high scores, exact
  fill-the-screen layouts, 12-item design polish pass).
- Clever 1: redesigned as a printed-sheet miniature with THREE layouts under
  test — sheet + paged editor modal, list mode (header toggle), and the
  "(v3)" catalogue entry with a landscape two-column reflow. Crossable
  rounds bar; re-roll/+1 tracks auto-count earned bonuses (derived state).
  13-item design polish pass applied.
- App-wide dice colours (Settings), optional dice roller on every board
  (#30), in-app feedback → GitHub issues (#33), light/dark mode, keep-awake,
  orientation fixes.
- Release pipeline: `release/1.0` branch + "5. App Store Release" workflow
  builds a Qwixx-only store candidate via the `QWIXX_ONLY` flag.
  NOTE: `release/1.0` was cut at the PR #46 merge — re-cut it from current
  `main` before building the 1.0 candidate if the newer fixes should ship.

## Open decisions (owner)

1. **Clever layout verdict**: sheet vs list vs v3 (on-device comparison).
   This gates the Clever 2/3/4 redesign rollout (#32).
2. **App Store 1.0 submission**: run "5. App Store Release" on
   `release/1.0`, verify the Qwixx-only candidate in TestFlight, then
   attach + submit in App Store Connect (docs/APP_STORE.md §7).

## Open issues backlog

- #31 brainstorm: next roll-and-write games (Qwixx Longo, Encore!, …)
- #32 Clever redesign rollout to 2/3/4 (after layout verdict)
- #34 Clever 1 "Challenge 1" fan sheet (PDF attached to the issue;
  owner-approved exception to the official-only rule)
- #35 Android version (big; unscoped)
- #41 Qwixx Double & Bonus official Version B variants (A/B switch like Mixx)
- "6. Simulator Smoke Test" workflow SHIPPED (manual, Actions tab): boots a
  Simulator, screenshots the catalogue + every game (Debug-only
  `-smokeTestGame <id>` launch arg in RootView), uploads artifacts. First
  run pending — check that the rotated Qwixx shots read upright (the
  workflow rotates them 90°; flip to 270° if they come out upside down).

## How to work here

Read `CLAUDE.md` (architecture + non-negotiable layout rules + conventions),
then `.claude/skills/rollnwrite-dev-loop/SKILL.md` (verification without a
compiler, PR/TestFlight cadence, screenshot iteration, subagent patterns) and
`.claude/skills/ios-testflight-no-mac/SKILL.md` (the signing/upload pipeline
and its failure modes). The owner reviews on TestFlight and replies with
annotated screenshots; official rules PDFs and photos of the physical pads
are the ground truth for any rules/layout question.

---

## Paste-able prompt for a new session

```
Read CLAUDE.md, docs/HANDOFF.md, and the two skills under .claude/skills/
(rollnwrite-dev-loop and ios-testflight-no-mac) before doing anything.

Context: RollnWrite is a SwiftUI iOS scorecard app for roll-and-write dice
games (9 Qwixx flavours + Clever 1-4), developed entirely without a Mac —
CI (push to main → TestFlight) is the only compiler. Follow the dev-loop
skill strictly: verify Swift changes with the no-compiler checklist, commit
per workstream, ALWAYS open a PR, and watch the TestFlight run after merge,
fixing until green. Never touch engines/scoring during design passes; any
new persisted field needs a tolerant decoder; new user-facing strings need
nl + de entries in Localizable.xcstrings.

Current state and open decisions are in docs/HANDOFF.md ("Where things
stand"). My priorities this session: [FILL IN — e.g. "roll the Clever
redesign out to Clever 2 using the sheet layout", "prepare the 1.0 App
Store submission", "implement #41 Version B", "build the simulator
smoke-test workflow"].

I test on TestFlight and will reply with annotated screenshots; treat those
as the source of truth for visual work. Ask before anything scoring-related
that lacks an official source — I own several of the physical games and can
photograph the real sheets.
```
