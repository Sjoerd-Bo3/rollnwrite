# Qwixx Double (Variant A — "double crosses") fixtures

Mirrors the shape of `spec/README.md` (normative for the base Qwixx family).
This file documents the **variant-specific** additions: Qwixx Double reuses
classic Qwixx's four colour rows and penalties, but replaces bonus rows with a
**second cross** on the most-recently marked space, and raises the lock
threshold from 5 to 7 marks. Engine source of truth:
`RollnWrite/Games/QwixxDouble/DoubleGame.swift` (iOS) /
`android/engine/.../qwixxdouble/DoubleGame.kt` (Android).

## Fixture file format

Same envelope as the base format:

```json
{
  "game": "qwixx-double",
  "variant": "double-a",
  "config": { "scoringCap": 16 },
  "name": "kebab-slug",
  "description": "what this case proves",
  "steps": [ ... ]
}
```

- `game` — always `"qwixx-double"`; selects the Qwixx Double engine (distinct
  from `"qwixx"`, so a single runner can filter fixtures by game id without
  ambiguity).
- `variant` — always `"double-a"` (the printed sheet's "Variant A").
- `config` — `scoringCap` (16 for Qwixx Double; triangular(16) = 136).
- `name` — kebab-case slug, must match the filename (without `.json`).
- `description` — one sentence: what rule(s) this fixture pins down.
- `steps` — executed in order against ONE fresh engine instance.

### Step forms

```json
{"do":"markColor","color":"red|yellow|green|blue","index":0-10,"expect":true|false}
{"do":"doubleColor","color":"red|yellow|green|blue","index":0-10,"expect":true|false}
{"do":"penalty","expect":true|false}
{"do":"concede","color":"red|yellow|green|blue","expect":true|false}
{"do":"finish","expect":true|false}
{"do":"undo","expect":true|false}
{"do":"redo","expect":true|false}

{"assert":{
  "points":        {"red":0,"yellow":0,"green":0,"blue":0},
  "crosses":       {"red":0,"yellow":0,"green":0,"blue":0},
  "penalties":     0,
  "penaltyPoints": 0,
  "totalScore":    0,
  "isGameOver":    false,
  "lockedRowCount":0,
  "rowLocked":     {"red":false,"yellow":false,"green":false,"blue":false},
  "canUndo":       false,
  "canRedo":       false
}}
```

`markColor` is the *first* cross on a space (identical semantics to base
Qwixx, but the lock threshold is 7 marks, not 5). `doubleColor` is the new verb:
a *second* cross on a space — legal ONLY on the single most-recently-marked
index of that row, never on the lock index, and never once a `doubleColor` on
that same index has already succeeded (each space can be doubled at most
once). There is no `markBonus` — Qwixx Double has no bonus rows.

- Every `"do"` step carries an explicit `"expect"`. There is no default.
- Every key inside `"assert"` is optional — assert any subset. The `points`,
  `crosses` and `rowLocked` maps may themselves list any subset of colours.
- Any step may carry an optional `"note"` string for human readers; runners
  MUST ignore it.

### Runner semantics (normative — both platforms implement exactly this)

For a `"do"` step:

1. Query the engine's can-precondition for that action (`canMarkColor`,
   `canDoubleColor`, `canAddPenalty`, `canConcedeRow`, `canFinishManually`,
   `canUndo`, `canRedo`) and assert it equals `"expect"`. For `undo`/`redo`,
   `"expect"` is compared against `canUndo`/`canRedo` *before* the call.
2. Invoke the mutator (`markColor`, `doubleColor`, `addPenalty`, `concedeRow`,
   `finishGame`, `undo`, `redo`) regardless of the expectation.
3. When `"expect"` is `false`, the mutator MUST leave all observable state
   unchanged (illegal attempts are silent no-ops and are NOT recorded in
   history — a subsequent `undo` never "undoes" a refused move).

For an `"assert"` step, compare each listed key against the engine's
observable state — same table as `spec/README.md`, with one addition:

| key              | engine observable                                        |
|------------------|-----------------------------------------------------------|
| `points`         | `points(for: color)`                                      |
| `crosses`        | `crosses(for: color)` — first crosses + doubles + lock bonus |
| `penalties`      | penalty count                                              |
| `penaltyPoints`  | `penalties * 5`                                             |
| `totalScore`     | sum of the four colours' points minus `penaltyPoints`      |
| `isGameOver`     | manual finish OR ≥2 locked rows OR 4 penalties              |
| `lockedRowCount` | number of rows with `locked == true` (concessions count)    |
| `rowLocked`      | per-colour `locked` flag                                     |
| `canUndo`        | history non-empty                                            |
| `canRedo`        | redo stack non-empty                                         |

Any mismatch fails the fixture with the step index, the key, expected and
actual values.

## Qwixx Double conventions the fixtures rely on

- **Indices are POSITIONS, not printed numbers** — identical convention to
  base Qwixx: 11 cells at indices 0…10 per row, red/yellow ascending
  (index *i* → number *i*+2), green/blue descending (index *i* → number
  12−*i*). Index 10 is always the lock number.
- **Left-to-right (first crosses):** `markColor` is legal only if `index` is
  strictly greater than every already-marked index in that row (same rule as
  base Qwixx).
- **Locking needs 7, not 5:** index 10 additionally requires the row's
  `crossCount` (marks + doubles + lock bonus so far, i.e. BEFORE the lock
  mark itself) to be ≥ 7 (vs. ≥5 marks in base Qwixx — note base Qwixx counts
  *marks*, Double counts the richer `crossCount` since doubles also count).
  Marking index 10 sets the row locked AND scores +1 lock bonus cross.
- **Double crosses (`doubleColor`):** legal only when ALL of:
  - the game is live (`!isGameOver`);
  - the row is not locked;
  - `index` is already in `marks` (a first cross exists there);
  - `index` is NOT already in `doubles` (can't double twice);
  - `index` equals the row's `maxMarkedIndex` (the single most-recently-marked
    space — not just "any marked space"; marking a new index to the right
    permanently forecloses doubling the previous one);
  - `index` is not the lock index (the lock cross is never doubled).

  A successful `doubleColor` adds one to `crossCount` (hence to `points`) but
  does NOT change `maxMarkedIndex` (that is driven by `marks`, not
  `doubles`) — so at most one `doubleColor` is ever legal at a time per row
  (on the current `maxMarkedIndex`), until the next `markColor` moves the
  frontier and forfeits the old space's doubling eligibility forever.
- **Scoring:** `crosses = marks.count + doubles.count + (1 if lock index in
  marks else 0)`. `points = triangular(clamp(crosses, 0, 16))`. Triangular
  values for n = 1…16: 1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66, 78, 91, 105,
  120, 136.
- **Penalties:** −5 each, maximum 4; the 4th ends the game (identical to base
  Qwixx).
- **Concede:** locks a row WITHOUT marking index 10 — no lock bonus cross, but
  the row counts toward the two-locks end condition. A conceded row also
  makes any pending double on its `maxMarkedIndex` moot (the row is closed to
  new marks either way; concede does not remove existing `doubles`).
- **Game over:** manual finish OR ≥2 locked rows OR 4 penalties. Once over,
  every mutation's precondition is `false`.
- **Undo/redo:** strictly LIFO over *applied* actions, exactly mirroring base
  Qwixx. Undoing a `mark` action also removes any `double` that was later
  recorded on top of it — but that can never happen out of order because
  undo is strictly LIFO: the `double` action (necessarily recorded AFTER its
  `mark`, since doubling requires an existing mark) is always popped and
  undone first. Undoing a `mark` that both had a double AND set the lock
  restores: mark removed, and if `didLock` was true, `locked` reset to
  `false`; a `double` action's undo only removes that one index from
  `doubles`.

## Fixture files

| file                  | proves |
|-----------------------|--------|
| `scoring-basics.json` | crosses/points arithmetic for plain first crosses, no doubles, no lock. |
| `double-cross.json`   | the core "double the most-recent mark" mechanic: legality, most-recent-only restriction, forfeiting a stale double opportunity by moving the frontier. |
| `locking.json`        | the 7-cross threshold (vs. base Qwixx's 5), the lock scoring bonus, and the second-lock game-over transition. |
| `penalties.json`      | 4-penalty cap and its game-over transition, interacting with doubles/marks unaffected by penalties. |
| `concede-finish.json` | conceding a locked-elsewhere colour for no bonus, and manual finish, as alternate game-over paths. |
| `undo-redo.json`      | LIFO undo/redo across interleaved `markColor`/`doubleColor`/`penalty` actions, including redo re-deriving `crossCount`-based lock eligibility exactly. |
