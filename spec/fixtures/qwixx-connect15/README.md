# Qwixx Connect15 fixtures

Golden fixtures for the Qwixx "Connect 15" variant (White Goblin Games / NSV).
Mirrors the base Qwixx fixture format (`spec/README.md`) but Connect15 has its
own action vocabulary: the four colour rows are classic Qwixx (red/yellow
2→12, green/blue 12→2, lock on the right-most number after ≥5 crossed
numbers) PLUS three "connection" fields woven into every row's own
left-to-right sequence — numbers and connection fields together form ONE
ordered sequence per row, so crossing anything forfeits every skipped space
(number or connection field) to its left forever. This directory's fixtures
are consumed by BOTH platforms' variant runners:

- Kotlin: `android/engine/src/test/kotlin/dev/bo3/rollnwrite/engine/connect15/Connect15FixtureRunnerTest.kt`
- Swift: `RollnWriteTests/Connect15FixtureTests.swift`

The Swift engine (`RollnWrite/Games/QwixxConnect15/Connect15Game.swift` +
`Connect15Models.swift`) is the rules source of truth. Every expected value
in these fixtures is hand-derived from that source, never copied from a
running engine.

## Fixture file format

One JSON object per file, same envelope as the base format:

```json
{
  "game": "qwixx-connect15",
  "variant": "connect15",
  "config": {},
  "name": "kebab-slug",
  "description": "what this case proves",
  "steps": [ ... ]
}
```

- `game` — always `"qwixx-connect15"` (selects this variant's engine/runner).
- `variant` — always `"connect15"` (single configuration; no cap/bonus-row
  knobs — the engine hardcodes cap 15 scoring with three connection fields
  per row. `config` is present but empty for envelope-shape consistency with
  the base format).
- `name` — kebab-case slug, must match the filename (without `.json`).
- `description` — one sentence: what rule(s) this fixture pins down.
- `steps` — executed in order against ONE fresh engine instance.

### Step forms

```json
{"do":"markColor","color":"red|yellow|green|blue","index":0-10,"expect":true|false}
{"do":"markConnection","color":"red|yellow|green|blue","field":0-2,"expect":true|false}
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

- `markConnection` takes a `field` (0-2, left → right ordinal within the
  row's three connection fields — NOT a printed number; connection fields
  carry no number). `Connect15Layout.columns(for:)[field]` gives the number
  column the field sits after.
- Every other key/action matches the base format's meaning exactly (colour
  rows are classic Qwixx rules for numbers/locking; `crosses` for a colour
  additionally includes its crossed connection fields — see below).
- Every `"do"` step carries an explicit `"expect"`; every `"assert"` key is
  optional. Optional `"note"` string, ignored by runners.

### Runner semantics (normative, mirrors spec/README.md exactly)

For a `"do"` step:

1. Query the can-precondition (`canMarkColor`, `canMarkConnection`,
   `canAddPenalty`, `canConcedeRow`, `canFinishManually`, `canUndo`,
   `canRedo`) and assert it equals `"expect"`. For `undo`/`redo`, `"expect"`
   is compared against `canUndo`/`canRedo` *before* the call.
2. Invoke the mutator (`markColor`, `markConnection`, `addPenalty`,
   `concedeRow`, `finishGame`, `undo`, `redo`) regardless of the expectation.
3. When `"expect"` is `false`, the mutator MUST leave all observable state
   unchanged (illegal attempts are silent no-ops, never recorded in history).

For an `"assert"` step, compare each listed key against engine state per the
table above.

## Connect15 conventions the fixtures rely on

- **The interleaved left-to-right sequence** (`Connect15Layout`): a row's 11
  numbers (columns 0…10) and 3 connection fields together form ONE ordered
  sequence. A number at column `j` sits at doubled position `2·j`; a
  connection field printed after column `i` sits at doubled position
  `2·i + 1` ("column `i` + 0.5", doubled to stay integer). A new mark (number
  OR connection field) is legal only if its position is strictly greater
  than the row's current highest marked position across BOTH kinds. This
  means crossing past an unmarked space — number or field — forfeits it
  forever; there is no way to go back and fill a skipped space.
- **Printed connection-field positions** (`Connect15Layout.connectionColumns`,
  transcribed from the official sheet): red `[1, 4, 8]` (between 3–4, 6–7,
  10–11), yellow `[3, 5, 7]` (between 5–6, 7–8, 9–10), green `[2, 6, 8]`
  (between 10–9, 6–5, 4–3), blue `[1, 4, 7]` (between 11–10, 8–7, 5–4). Each
  array's index IS the field's 0-based ordinal (`field` in `markConnection`).
- **`markConnection` legality**: game live, row not locked, field not already
  marked, and the field's doubled position (`2·columns[field] + 1`) strictly
  exceeds the row's current highest marked position (numbers and fields
  combined). Marking a connection field never touches the colour row's own
  `marks` set.
- **Locking a row** (index 10, the right-most number): needs ≥5 crossed
  NUMBERS specifically — `row.marks.count >= 5` — connection fields never
  count toward the five, even if all three are crossed. Crossing it sets
  `locked = true` and adds one scoring cross (the lock bonus).
- **Scoring**: `crosses(for:)` = the row's `scoringCrosses` (marked numbers +
  1 if the lock was crossed) **plus** the count of crossed connection fields.
  This raises each row's ceiling from 12 (classic Qwixx) to 15 (11 numbers +
  lock + 3 connection fields). Scoring uses the standard triangular table for
  1…15 crosses: 1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66, 78, 91, 105, 120 —
  hence "Connect 15" (15 crosses → 120 points, same ceiling as the base
  Qwixx bonus-row variants but reached through connection fields instead).
- **Total score**: `totalScore = red + yellow + green + blue − (5 ×
  penalties)` — identical formula to classic Qwixx; connection fields are
  folded into each colour's own `points`, not a separate additive term (unlike
  e.g. Lucky15's independent bonus track).
- **Penalties**: −5 each, max 4; the 4th ends the game. Independent of
  connection-field marking — there is no penalty short-circuit tied to
  connection fields.
- **Concede**: identical semantics to the base format — locks a row WITHOUT
  the lock bonus cross (no numbers/fields need to be crossed at all); still
  counts toward the two-locks end condition. Once conceded, the row's
  remaining connection fields are permanently closed (its `locked` flag gates
  `canMarkConnection` exactly like `canMarkColor`).
- **Game over**: manual finish OR ≥2 locked rows OR 4 penalties — identical
  to the base format. `canMarkConnection` becomes `false` the instant the
  game is over, exactly like every other mutator.
- **Undo/redo**: strictly LIFO over applied actions, including
  `markConnection` — undoing a connection mark removes it from the row's
  connection-field set (which also lowers the row's highest marked position
  back, potentially re-legalising fields/numbers that were forfeited by
  jumping past them). Redo re-applies through `markConnection()` (the normal
  mutator), matching the `isRedoing` guard pattern used by every other
  action.
