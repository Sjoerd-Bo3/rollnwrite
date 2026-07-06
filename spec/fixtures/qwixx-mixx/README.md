# Qwixx Mixx fixtures

Golden fixtures for the Qwixx "gemixxt" (Mixx) engine — mirrors the shape of
`spec/README.md` (the normative Qwixx Big Points/classic contract) but adapted
to Mixx's engine surface, which addresses rows **by printed row index (0…3)**
rather than by colour, and has **no bonus rows**.

Both platforms' Mixx runners implement this document exactly, replaying every
`*.json` fixture here against their real engine (`MixxGame.swift` on iOS,
`MixxGame.kt` on Android). A rule divergence on either platform fails that
platform's build.

## Why rows-by-index, not rows-by-colour

Mixx ships two boards (Variant A / Variant B) with *different* printed
layouts (`MixxLayout.variantA` / `.variantB`), each still exactly 4 rows of 11
cells. Unlike classic Qwixx (where row = colour 1:1), a Mixx row's colour is
just a display property of its cells/lock (`MixxRowLayout.lockColor`) — the
rule engine (left-to-right, lock-at-≥5, scoring, penalties, concede, finish,
undo/redo) is **identical index arithmetic regardless of board or colour**, so
fixtures never need to reference cell colours at all. `board` is part of
`config` only so the runner constructs the right layout (for fidelity/future
board-dependent assertions); no fixture below currently asserts anything
board-specific.

## Fixture file format

```json
{
  "game": "qwixx-mixx",
  "variant": "variantA" | "variantB",
  "config": { "board": "variantA" | "variantB", "scoringCap": 12 },
  "name": "kebab-slug",
  "description": "what this case proves",
  "steps": [ ... ]
}
```

- `game` — always `"qwixx-mixx"`.
- `variant` — which board the fixture exercises (`"variantA"` or
  `"variantB"`); must equal `config.board`.
- `config.board` — selects `MixxLayout.variantA` / `.variantB` (which layout
  the engine is constructed against). Never affects scoring math.
- `config.scoringCap` — triangular scoring cap. Mixx always plays classic
  scoring (cap 12, 78 max/row) — included explicitly (rather than hard-coded
  in the runner) so a fixture is self-describing and the runner needs no
  variant-specific branching.
- `name` — kebab-case slug, must match the filename (without `.json`).
- `description` — one sentence: what rule(s) this fixture pins down.
- `steps` — executed in order against ONE fresh engine instance on the
  configured board.

### Step forms

```json
{"do":"mark","row":0-3,"index":0-10,"expect":true|false}
{"do":"penalty","expect":true|false}
{"do":"concede","row":0-3,"expect":true|false}
{"do":"finish","expect":true|false}
{"do":"undo","expect":true|false}
{"do":"redo","expect":true|false}

{"assert":{
  "points":          {"0":0,"1":0,"2":0,"3":0},
  "crosses":         {"0":0,"1":0,"2":0,"3":0},
  "penalties":       0,
  "penaltyPoints":   0,
  "totalScore":      0,
  "isGameOver":      false,
  "lockedRowCount":  0,
  "rowLocked":       {"0":false,"1":false,"2":false,"3":false},
  "canUndo":         false,
  "canRedo":         false
}}
```

- `row` is the **printed row index** (0…3, top-to-bottom order as in
  `MixxLayout.rows(for:)` / `MixxLayout.rows(board)`) — NOT a colour. `points`,
  `crosses` and `rowLocked` maps key by that same row index (as a string key,
  since JSON object keys are strings), and may list any subset of rows.
- `index` is the cell position within the row (0…10, left to right as
  printed); index 10 is always the lock cell, matching classic Qwixx.
- Every `"do"` step carries an explicit `"expect"` — no default.
- Every key inside `"assert"` is optional.
- Any step may carry an optional `"note"` string; runners MUST ignore it.

### Runner semantics (normative — both platforms implement exactly this)

For a `"do"` step:

1. Query the engine's can-precondition (`canMark`, `canAddPenalty`,
   `canConcedeRow`, `canFinishManually`, `canUndo`, `canRedo`) and assert it
   equals `"expect"`. For `undo`/`redo`, compare against `canUndo`/`canRedo`
   *before* the call.
2. Invoke the mutator (`mark`, `addPenalty`, `concedeRow`, `finishGame`,
   `undo`, `redo`) regardless of the expectation.
3. When `"expect"` is `false`, the mutator MUST leave all observable state
   unchanged (illegal attempts are silent no-ops, never recorded in history).

For an `"assert"` step, compare each listed key against the engine's
observable state:

| key              | engine observable                                          |
|------------------|-------------------------------------------------------------|
| `points`         | `points(rowIndex)` per row                                   |
| `crosses`        | `crosses(rowIndex)` per row                                  |
| `penalties`      | penalty count                                                |
| `penaltyPoints`  | `penalties * 5`                                              |
| `totalScore`     | sum of the four rows' points minus `penaltyPoints`            |
| `isGameOver`     | manual finish OR ≥2 locked rows OR 4 penalties                |
| `lockedRowCount` | number of rows with `locked == true` (concessions count)      |
| `rowLocked`      | per-row `locked` flag                                         |
| `canUndo`        | history non-empty                                             |
| `canRedo`        | redo stack non-empty                                          |

Any mismatch fails the fixture with the step index, the key, expected and
actual values.

## Qwixx Mixx conventions the fixtures rely on

- **Rows-by-index, identical rule engine to classic Qwixx.** Every row has 11
  cells at indices 0…10, left to right as printed, regardless of board or
  colour. A cell is markable only if its index is strictly greater than every
  already-marked index in that row (skipped cells are forfeited forever), and
  index 10 additionally requires ≥5 existing marks. Marking index 10 sets the
  row locked AND itself counts as a scoring cross plus a +1 lock bonus (a
  self-locked row of *n* marks scores *n*+1 crosses) — exactly the classic
  Qwixx rule, just addressed by row index instead of colour.
- **No bonus rows.** Mixx has none of Big Points' two-colour bonus spaces;
  `crosses(rowIndex)` is exactly `marks.count + (locked ? 1 : 0)`, with no
  extra contribution possible.
- **Scoring:** `points = triangular(clamp(crosses, 0, 12))` with
  `triangular(n) = n(n+1)/2`. Values for n = 1…12:
  1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66, 78. Mixx always plays the classic
  cap (12), never Big Points' 15 — there are no bonus rows to push a row past
  12 valued crosses.
- **Penalties:** −5 each, maximum 4; the 4th ends the game.
- **Concede:** locks a row WITHOUT marking index 10 — but `scoringCrosses`
  reads the `locked` flag alone (`marks.count + (locked ? 1 : 0)`), not
  whether index 10 specifically is in `marks`, so a conceded row STILL gets
  the +1 lock-bonus cross, exactly as if it had one more mark than it
  actually does. (This differs from base Qwixx's `ColorRow`, whose
  `scoringCrosses` instead checks `marks.contains(lockIndex)` — a conceded
  Big-Points row scores no bonus. Mixx's `MixxRow.scoringCrosses` is
  genuinely written differently; treat this asymmetry as an intentional
  divergence to preserve, not a transcription slip, unless the owner says
  otherwise.) The row still counts toward the two-locks end condition either
  way. Mirrors Mixx's physical rule that closing a row (by any means) removes
  that row's coloured die from play — an interaction the fixtures don't model
  directly (multiplayer table state, not part of one player's own scoring),
  but which motivates `concede` existing at all: a player must be able to
  close a row when another player locks that colour first.
- **Game over:** manual finish OR ≥2 locked rows OR 4 penalties. Once over,
  every mutation's precondition is `false`.
- **Undo/redo:** strictly LIFO over *applied* actions. Undo exactly reverses
  (including un-locking a row whose lock or concede that action set) and
  pushes onto the redo stack; redo re-applies through the normal mutator; any
  fresh applied move clears the redo stack.
- **Two independent boards, but out of fixture scope.** The real engine holds
  Variant A and Variant B as two independent, separately-persisted `MixxState`
  values (switching `board` operates on a different state). Fixtures only ever
  drive a single freshly-constructed engine/board — cross-board independence
  is a persistence/UI-layer concern (`MixxGame.board`/`stateA`/`stateB` on
  iOS), not a rule the engine-semantics fixtures need to re-prove.
