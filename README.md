# Roll'n Write

A SwiftUI **scorecard** app for roll-and-write dice games (Qwixx, *That's Pretty
Clever*, …), built so new games slot in cleanly. Universal — iPhone (all sizes)
and iPad — touch-driven, with the official rules included in-app.

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

## Running it

- **Xcode:** open `RollnWrite.xcodeproj` (Xcode 16+) and run on a simulator or
  device.
- **Xcode Cloud:** a shared `RollnWrite` scheme is included — see
  [`docs/XCODE_CLOUD.md`](docs/XCODE_CLOUD.md).

## Architecture

Protocol-oriented and SOLID, organised so adding a game means adding a folder and
registering one `GameDefinition` — no edits to existing code. See
[`CLAUDE.md`](CLAUDE.md) for the full design and the "add a new game" recipe.
