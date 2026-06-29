# Roll'n Write

[![TestFlight](https://github.com/Sjoerd-Bo3/rollnwrite/actions/workflows/testflight.yml/badge.svg)](https://github.com/Sjoerd-Bo3/rollnwrite/actions/workflows/testflight.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-lightgrey.svg)](#)

A SwiftUI **scorecard** app for roll-and-write dice games (Qwixx, *That's Pretty
Clever*, …), built so new games slot in cleanly. Universal — iPhone (all sizes)
and iPad — touch-driven, with the official rules included in-app.

It is a *pure scorecard*: you tap to cross out spaces, the engine enforces the
official rules strictly, and scores are computed automatically. No dice are
rolled in-app.

## First game: Qwixx Big Points

The **Qwixx Big Points** variant is fully implemented:

- The official scorecard layout: red & yellow rows `2→12`, green & blue rows
  `12→2`, each locking on the right, plus the two-colour **bonus rows**
  (red/yellow and green/blue).
- **Strict rule enforcement** — left-to-right marking, the lock needs 5+ crosses,
  bonus spaces need an adjacent crossed colour space, and game-end on two locks
  or four penalties. Illegal taps are blocked.
- **Automatic scoring**, including the Big Points rule that each bonus cross
  counts for *both* adjacent colours (up to 120 points per colour).
- Undo, new-game, in-app rules, and automatic save/restore.

> Rules and scoring follow the official Qwixx Big Points variant by
> Nürnberger-Spielkarten-Verlag (NSV).

## The Clever series (1–4)

All four Wolfgang Warsch *Clever* games are implemented as interactive,
auto-scoring scorecards, each transcribed from its **official score sheet**:

- **That's Pretty Clever** (*Ganz schön clever*, art. 88198) — yellow 4×4
  (columns 10/14/16/20), blue 2–12 grid (to 56), green threshold row, orange
  ×2/×3, strictly-increasing purple. Foxes auto-detected.
- **Twice as Clever** (*Doppelt so clever*, art. 88234) — silver per-row scale,
  yellow circle-then-cross, descending blue, green pair-subtraction, pink sum.
- **Clever Cubed** (*Clever hoch Drei*) — yellow/turquoise per-row tables, the
  blue ±1 track around 7, brown crosses table, pink × multipliers.
- **Clever 4ever** (art. 49424) — yellow 3-row (neg/pos/columns), blue 6×6
  coordinate grid, grey 4×16 columns, green split-triangle fields, pink bar.

The app **enforces each area's structure** and **auto-computes every score**,
including **foxes** (each scores your lowest area). **Map your physical dice**:
remap the colour shown for any area to match your copy of the game (presentation
only — scoring is unchanged).

> Bonus actions (re-roll, +1, extra marks) are applied by tapping the granted
> space yourself, matching physical play; foxes are counted for you.

## Running it

- **Xcode:** open `RollnWrite.xcodeproj` (Xcode 16+) and run on a simulator or
  device. Deployment target is iOS 17.

## Building & releasing — no Mac required

The whole release pipeline runs on GitHub-hosted macOS runners, so you can ship
to TestFlight entirely from a browser:

- **`.github/workflows/testflight.yml`** (`2. TestFlight`) builds, signs, and
  uploads to TestFlight via [fastlane](fastlane/Fastfile). It runs on every push
  to `main` (and on demand from the Actions tab).
- Code signing uses **fastlane match** — the distribution certificate and
  provisioning profile are stored encrypted in a separate private repo, so CI
  never mints a throwaway cert per run. The build is **self-healing**: if the
  distribution certificate has expired, it auto-renews (revoke + recreate) and
  carries on, so cert maintenance is hands-off.
- **`.github/workflows/ios.yml`** (`3. iOS Build`) is a manual, signing-free
  compile check.

Required repository secrets are documented at the top of the TestFlight
workflow. See also [`docs/`](docs) for the setup notes.

## Roadmap

- ✅ TestFlight (internal testing)
- ⏳ App Store release
- More Qwixx variants and roll-and-write titles, slotting into the same
  framework.

## Architecture

Protocol-oriented and SOLID, organised so adding a game means adding a folder and
registering one `GameDefinition` — no edits to existing code. See
[`CLAUDE.md`](CLAUDE.md) for the full design and the "add a new game" recipe.

## License

Licensed under the **GNU General Public License v3.0** — see [`LICENSE`](LICENSE).
You may use, study, share, and modify the source, but derivative works must also
be released under the GPL-3.0.

## Disclaimer

This is an unofficial, fan-made scorecard app and is **not affiliated with,
endorsed by, or sponsored by** the publishers or designers of the games it
supports. *Qwixx* is a trademark of Nürnberger-Spielkarten-Verlag (NSV); the
*Clever* series (*Ganz schön clever*, *Doppelt so clever*, *Clever hoch Drei*,
*Clever 4ever*) are by Wolfgang Warsch, published by Schmidt Spiele. All game
names, rules, and trademarks belong to their respective owners. This app provides
only a digital scorecard — you supply your own physical dice and game.
