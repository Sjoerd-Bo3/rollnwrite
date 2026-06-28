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
│  └─ Qwixx/                One game module
│     ├─ GameColor.swift          Colour/number model
│     ├─ QwixxModels.swift        Codable value types (ColorRow, BonusRow, state)
│     ├─ QwixxGame.swift          Engine: rules + transitions + persistence
│     ├─ QwixxBigPointsGame.swift GameDefinition + official rules text
│     └─ QwixxScorecardView.swift Scorecard UI (presentation only)
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

- Universal: iPhone (all sizes) and iPad. Portrait + landscape.
- Deployment target: iOS 17.
- The scorecard sizes its cells with `GeometryReader` and caps the card width
  (700 pt) so it stays touch-friendly and centered on large/iPad screens.
  Verified targets include iPhone 15 Pro Max and iPhone 15 Plus.

## Build & CI

- Open `RollnWrite.xcodeproj` in Xcode 16+ and run, or build via **Xcode Cloud**
  (shared scheme: `RollnWrite`). See `docs/XCODE_CLOUD.md`.
- The project uses `objectVersion = 77` (file-system synchronized groups);
  build with Xcode 16 or newer.

## Conventions

- Keep rule logic in engines, not views. Views ask `can…` and call mutators.
- Keep `Core` free of game-specific code.
- Persist game state via the engine (Qwixx uses `UserDefaults` + `Codable`).
