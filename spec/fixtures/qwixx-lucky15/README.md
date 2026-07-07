# Qwixx Lucky15 fixtures

Golden fixtures for the Qwixx "Lucky 15" variant (White Goblin Games / NSV).
Mirrors the base Qwixx fixture format (`spec/README.md`) but Lucky15 has its
own action vocabulary: the four colour rows are classic Qwixx (cap 12, no
bonus rows) PLUS a single orange "Lucky 15" track with its own progressive
scoring. This directory's fixtures are consumed by BOTH platforms' variant
runners:

- Kotlin: `android/engine/src/test/kotlin/dev/bo3/rollnwrite/engine/lucky15/Lucky15FixtureRunnerTest.kt`
- Swift: `RollnWriteTests/Lucky15FixtureTests.swift`

The Swift engine (`RollnWrite/Games/QwixxLucky15/Lucky15Game.swift` +
`Lucky15Models.swift`) is the rules source of truth. Every expected value in
these fixtures is hand-derived from that source, never copied from a running
engine.

## Fixture file format

One JSON object per file, same envelope as the base format:

```json
{
  "game": "qwixx-lucky15",
  "variant": "lucky15",
  "config": {},
  "name": "kebab-slug",
  "description": "what this case proves",
  "steps": [ ... ]
}
```

- `game` — always `"qwixx-lucky15"` (selects this variant's engine/runner).
- `variant` — always `"lucky15"` (single configuration; no cap/bonus-row
  knobs — the engine hardcodes cap 12, no bonus rows, plus the Lucky15
  track. `config` is present but empty for envelope-shape consistency with
  the base format).
- `name` — kebab-case slug, must match the filename (without `.json`).
- `description` — one sentence: what rule(s) this fixture pins down.
- `steps` — executed in order against ONE fresh engine instance.

### Step forms

```json
{"do":"markColor","color":"red|yellow|green|blue","index":0-10,"expect":true|false}
{"do":"markLucky","expect":true|false}
{"do":"penalty","expect":true|false}
{"do":"concede","color":"red|yellow|green|blue","expect":true|false}
{"do":"finish","expect":true|false}
{"do":"undo","expect":true|false}
{"do":"redo","expect":true|false}

{"assert":{
  "points":        {"red":0,"yellow":0,"green":0,"blue":0},
  "crosses":       {"red":0,"yellow":0,"green":0,"blue":0},
  "luckyCrossed":  0,
  "luckyPoints":   0,
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

- `markLucky` takes no `color`/`row`/`index` — the Lucky 15 track is a single
  strictly-left-to-right sequence of 4 fields, so "which field" is always
  "the next uncrossed one." There is no analogue to `markBonus`'s explicit
  `index` because the track has no independent addressing; state is fully
  described by a crossed-count (`Lucky15Track.crossed`).
- `luckyCrossed` — number of Lucky 15 track fields crossed so far (0…4).
- `luckyPoints` — the Lucky 15 bonus, i.e. the value of the highest crossed
  field (0 if none crossed), from `Lucky15Track.values = [5, 11, 18, 25]`.
- Every other key/action matches the base format's meaning exactly (colour
  rows are classic Qwixx rules: cap 12 scoring, no bonus rows so `crosses`
  for a colour is just its own scoring crosses).
- Every `"do"` step carries an explicit `"expect"`; every `"assert"` key is
  optional. Optional `"note"` string, ignored by runners.

### Runner semantics (normative, mirrors spec/README.md exactly)

For a `"do"` step:

1. Query the can-precondition (`canMarkColor`, `canMarkLucky`, `canAddPenalty`,
   `canConcedeRow`, `canFinishManually`, `canUndo`, `canRedo`) and assert it
   equals `"expect"`. For `undo`/`redo`, `"expect"` is compared against
   `canUndo`/`canRedo` *before* the call.
2. Invoke the mutator (`markColor`, `markLucky`, `addPenalty`, `concedeRow`,
   `finishGame`, `undo`, `redo`) regardless of the expectation.
3. When `"expect"` is `false`, the mutator MUST leave all observable state
   unchanged (illegal attempts are silent no-ops, never recorded in history).

For an `"assert"` step, compare each listed key against engine state per the
table above.

## Lucky15 conventions the fixtures rely on

- **Colour rows are classic Qwixx**: cap 12 scoring (1, 3, 6, 10, 15, 21, 28,
  36, 45, 55, 66, 78 for 1…12 crosses), no bonus rows, same left-to-right and
  locking (index 10, needs ≥5 prior marks) rules as `spec/README.md`
  describes for `"classic"`.
- **The Lucky 15 track** has 4 fields worth 5, 11, 18, 25 (left → right,
  strictly ordered — you cannot skip a field). `markLucky` always targets the
  next uncrossed field; it is legal iff the game is live AND the track has
  room left (`crossed < 4`). It does NOT touch any colour row, does NOT
  consume a penalty slot, and is a fully independent action from `markColor`.
- **Lucky15 bonus scoring**: `luckyPoints` = the value of the *highest*
  crossed field only (not a sum) — crossing field 3 (value 18) after already
  having crossed fields 1-2 makes `luckyPoints` 18, not 5+11+18.
- **Total score**: `totalScore = red + yellow + green + blue + luckyPoints -
  (5 × penalties)` — the Lucky 15 bonus is a fifth additive term absent from
  the base Qwixx formula.
- **Penalties**: −5 each, max 4; the 4th ends the game. Marking a Lucky 15
  field replaces a normal turn's action but is not itself modelled as a
  penalty-avoider here — the fixtures test the track and the penalty counter
  as independent state, exactly as the engine does (there is no
  `canAddPenalty` short-circuit tied to `luckyCrossed`).
- **Concede**: identical semantics to the base format — locks a row WITHOUT
  the lock bonus cross; still counts toward the two-locks end condition.
- **Game over**: manual finish OR ≥2 locked rows OR 4 penalties — identical
  to the base format. `canMarkLucky` becomes `false` the instant the game is
  over, exactly like every other mutator.
- **Undo/redo**: strictly LIFO over applied actions, including `markLucky` —
  undoing a Lucky 15 mark decrements `crossed` by one (never below 0); redo
  re-applies through `markLucky()` (the normal mutator), matching the
  `isRedoing` guard pattern used by every other action.
