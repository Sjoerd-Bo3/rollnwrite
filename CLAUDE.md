# RollnWrite — Project Guide

A SwiftUI iOS/iPadOS app that acts as a digital **scorecard** for roll-and-write
dice games (Qwixx, *That's Pretty Clever*, …). The first implemented game is
**Qwixx Big Points**. The app is a *pure scorecard*: you tap to cross out
spaces, the engine enforces the official rules strictly, and scores are computed
automatically. No dice are rolled in-app.

The codebase is deliberately built as a small **framework** so new games can be
added with minimal, isolated changes.

---

## Architecture & engineering principles

The app is layered. Dependencies point **inward**: `App` → `Games` → `Core`.
`Core` knows nothing about any specific game.

```
RollnWrite/
├─ App/                     App entry + game catalogue (composition layer)
│  ├─ RollnWriteApp.swift    @main; just hosts RootView
│  └─ RootView.swift         Catalogue UI, driven entirely by GameRegistry
├─ Core/                    Game-agnostic framework (reusable across games)
│  ├─ GameDefinition.swift   GameDefinition protocol + GameRegistry (extension point)
│  ├─ ScoringStrategy.swift  ScoringStrategy + TriangularScoring + Scoreboard
│  ├─ RulesDocument.swift    Rules content model + generic RulesView renderer
│  └─ Components.swift        Reusable cells/chips (MarkableCell, ScoreChip)
├─ Games/
│  ├─ Qwixx/                One game module
│  │  ├─ GameColor.swift          Colour/number model
│  │  ├─ QwixxModels.swift        Codable value types (ColorRow, BonusRow, state)
│  │  ├─ QwixxGame.swift          Engine: rules + transitions + persistence
│  │  ├─ QwixxBigPointsGame.swift GameDefinition + official rules text
│  │  └─ QwixxScorecardView.swift Scorecard UI (presentation only)
│  ├─ Clever/               "That's Pretty Clever" (Clever 1)
│  │  ├─ CleverModels.swift       Areas, colour theme, EXACT official layout data
│  │  ├─ CleverGame.swift         Engine: per-area structure + auto scoring + foxes
│  │  ├─ CleverScorecardView.swift Scorecard UI + dice-colour mapping
│  │  └─ CleverGameDefinition.swift GameDefinition + official rules text
│  └─ Clever2/              "Twice as Clever" (Clever 2)
│     ├─ Clever2Models.swift      Silver/yellow/blue/green/pink layout data
│     ├─ Clever2Game.swift        Engine: per-area scoring (manual foxes)
│     ├─ Clever2ScorecardView.swift Scorecard UI + dice-colour mapping
│     └─ Clever2GameDefinition.swift GameDefinition + official rules text
└─ Assets.xcassets
```

### SOLID, applied here

- **S — Single Responsibility.** Each type has one job: `QwixxModels` hold
  state, `QwixxGame` owns rules + transitions, `ScoringStrategy` does scoring
  math, the views only present. Rules *content* (`RulesDocument`) is separate
  from rules *presentation* (`RulesView`).
- **O — Open/Closed.** Adding a game means **adding** a `GameDefinition` and
  registering it in `GameRegistry.games` — no existing type is modified.
  `RootView` iterates the registry, so the catalogue and navigation extend for
  free. The Xcode target uses a *file-system synchronized group*, so new files
  under `RollnWrite/` are compiled automatically with **no `.pbxproj` edits**.
- **L — Liskov Substitution.** Every `GameDefinition` is interchangeable in the
  catalogue; `QwixxGame` conforms to the generic `Scoreboard` protocol and can
  stand in wherever a scoreboard is expected.
- **I — Interface Segregation.** Protocols are small and focused:
  `GameDefinition` (catalogue + view factory), `ScoringStrategy` (one method),
  `Scoreboard` (headline score + game-over + undo/reset).
- **D — Dependency Inversion.** `QwixxGame` depends on the `ScoringStrategy`
  abstraction and has a concrete strategy **injected** (Big Points = cap 15;
  classic Qwixx would be cap 12 — a constructor argument, not a code edit).
  `RootView` depends on `GameDefinition`, never on a concrete game type.

Patterns used: **Strategy** (scoring), **Registry/Factory** (`GameRegistry` +
`makeScorecardView()`), **type erasure** (`AnyView`) to keep a heterogeneous
game list, and a **LIFO command history** for exact, dependency-safe undo.

---

## How to add a new game (the OCP recipe)

1. Create `Games/<NewGame>/`. The synchronized group picks the files up
   automatically — no Xcode project edits.
2. Model its state as `Codable` value types (see `QwixxModels.swift`).
3. Write an engine: an `ObservableObject` that enforces the rules and conforms
   to `Scoreboard`. Inject a `ScoringStrategy` (reuse `TriangularScoring` or add
   a new conformer).
4. Provide a scorecard `View` (presentation only — never enforce rules in the
   view; ask the engine `canMark…`).
5. Add a `GameDefinition` (metadata + `RulesDocument` + `makeScorecardView()`).
6. Register it in `GameRegistry.games`. Done — it appears in the catalogue.

> Always use the **official** scorecard and rules for each variant. If they
> can't be sourced, ask before implementing — don't guess.

---

## Platforms & layout

- Universal: iPhone (all sizes) and iPad.
- Deployment target: iOS 17.

### Scorecard layout & interaction requirements (non-negotiable)

These are explicit product requirements. **Every** scorecard — Qwixx Big
Points, classic, all Qwixx variants, and all Clever games — must follow them.
`Games/Qwixx/QwixxScorecardView.swift` is the canonical reference; new and
existing games should mirror its approach.

- **Always fullscreen, edge-to-edge.** The board fills the entire available
  space with no empty margins and no scrolling. Tiles fill the full width
  edge-to-edge; tile **width and height are decoupled** (a `GeometryReader`
  computes `w` from the available width and a row height from the available
  height). Do not cap the card width or centre it with side margins.
- **Tile height: fill, capped at square, floored at a min.** A tile's height
  fills its row but never exceeds its width (square is the MAX — never tall
  skinny tiles) and never drops below a readable MIN. Leftover height centres
  the board. So cramped boards (Big Points, 8 rows) go rectangular and fill;
  roomy boards stay square.
- **No system nav bar.** Replace it with a compact in-board header (back,
  title, optional 2-player toggle, info) via `.toolbar(.hidden, for:
  .navigationBar)`, so the board gets the full height.
- **Orientation is per-screen.** The catalogue (menu) rotates freely. A
  single-player scorecard pins iPhone to landscape via
  `.landscapeLockediPhone(when:)` (an `AppDelegate` + `OrientationGate` mask in
  `App/OrientationLock.swift`); Info.plist still *allows* portrait so other
  screens can rotate.
- **Style like the real game.** Match the official card: full-width colour
  bands with light number tiles, a direction chevron per row, inline lock, and
  per-row scores — not a generic grid. Study the official scorecard art.
- **Tap-to-undo.** Tapping the player's most-recent mark (number, bonus, or
  penalty) un-checks it — a second way to undo alongside the undo button. Undo
  stays strictly LIFO, so only the *last* action is tap-undoable; ring that
  cell. Engines expose `isLast…` helpers (see `QwixxGame`).
- **Two-player (mirrored).** A board may offer a "2 players" toggle that shows
  a second, independent engine's board mirrored (`rotationEffect(180°)`) above
  the first — for players across a table. Works on iPad and on iPhone in
  portrait (the two boards stack; two-player frees rotation). See
  `QwixxBoardView` (pure board) + `QwixxScorecardView` (nav + optional mirror).

**Architecture pattern:** split each game into a pure board view (no nav, takes
the engine) plus a thin wrapper that adds the header, orientation lock, rules
sheet, and optional 2-player mirror — exactly like `QwixxBoardView` /
`QwixxScorecardView`. This makes the mirror and fullscreen behaviour reusable.

## Build & CI

- Open `RollnWrite.xcodeproj` in Xcode 16+ and run, or build via **Xcode Cloud**
  (shared scheme: `RollnWrite`). See `docs/XCODE_CLOUD.md`.
- The project uses `objectVersion = 77` (file-system synchronized groups);
  build with Xcode 16 or newer.
- **CI without a Mac:** `.github/workflows/ios.yml` builds the app on a
  GitHub-hosted macOS runner (iOS Simulator, no signing) on every push/PR. This
  is the no-Mac way to verify the project compiles; check it after each change.

## Game notes

**Qwixx Big Points** — strict marking, bonus crosses count for both adjacent
colours (cap 15 → 120). See `Games/Qwixx`.

**That's Pretty Clever (Clever 1)** — `Games/Clever`.
- All grid numbers, thresholds, multipliers, point scales and bonus/fox
  positions in `CleverModels.swift` (`CleverLayout`) were transcribed from the
  official Schmidt Spiele rulebook & score sheet (art. 88198). Treat that file
  as the source of truth; verify against the official sheet before changing.
- The engine enforces each area's *structure* (yellow/blue any-order single
  marks, green left→right, orange left→right with multipliers, purple strictly
  increasing with the after-6 exception) and computes every area score.
- **Foxes are auto-detected**: every fox sits at a row/column/reach-this-cell
  completion, and foxes only matter at scoring time, so the engine derives the
  fox count rather than asking the player to track it.
- **Re-roll/+1 are auto-counted onto the tracks**: earned counts are DERIVED
  from state (like foxes) — crossed rounds 1–3 (`roundsCrossed`) plus completed
  area triggers with a printed re-roll/+1 — so undo can never desync them. A
  track slot can only be spent once earned (uncrossing is always allowed);
  circles render used / available / not-earned. The 1–6 rounds bar is crossable
  as pure bookkeeping: `toggleRound` never enters the LIFO history. Remaining
  bonuses (extra marks of the player's choice) are applied manually —
  consistent with the pure-scorecard model (no in-app dice).
- **Dice-colour mapping**: the player's physical dice colours are an APP-WIDE
  setting (`Core/DiceTheme.swift`, edited in Settings — six colour slots,
  classic Clever dice by default). Every Clever game derives each area's
  display colour as the nearest palette colour (unique assignment; achromatic
  standards match by brightness). Presentation only, never scoring.

**Twice as Clever (Clever 2)** — `Games/Clever2`. Areas: silver (per-row
scale, summed), yellow (circle-then-cross, scored by crosses), blue
(descending-or-equal, scale to 78), green (6 pairs, each scores first−second
of die×multiplier), pink (sum). Layout in `Clever2Layout` is transcribed from
the official sheet (art. 88234). Foxes are a **manual stepper** here (their
triggers are spread across many area completions, unlike Clever 1 where each
fox is a single clean completion), each scoring the lowest area.

**Clever Cubed (Clever 3)** — `Games/Clever3`. All five areas auto-scored from
the official score sheet: yellow (3 rows, 2/6/12/20/30/42), turquoise (5 rows,
1/3/6/10/15/21), blue (±1 track around 7; outermost-left + outermost-right of
3/6/9/13/17/22, +4 per 2/3/4/10/11/12), brown (one row,
2/5/9/14/20/27/35/44/54/65/77/90 by crosses), pink (sum of written die ×
multiplier). Foxes are a manual stepper.

**Clever 4ever (Clever 4)** — `Games/Clever4`. The most complex board, now fully
interactive and auto-scored from the official sheet (art. 49424): yellow (3×5;
top ascending = 0 pts, middle negative, bottom positive, completed-column stars
10/10/15/15/20), blue (6×6; columns 7–12 at ≥2 crosses, TR→BL diagonal +6), grey
(4×16; completed columns 1…11 — polyomino marking modelled as free crossing),
green (11 split fields, top+bottom summed, doubled from the 4th), pink (12-field
bar 2…42 + circled 2/4/6 bonuses). Foxes are a manual stepper.

Do not generalise the Clever engines prematurely — each Clever has a
materially different board.

## Conventions

- Keep rule logic in engines, not views. Views ask `can…` and call mutators.
- Keep `Core` free of game-specific code.
- Persist game state via the engine (`UserDefaults` + `Codable`).
- Always implement from the **official** rules/scorecard; if unavailable, ask.
