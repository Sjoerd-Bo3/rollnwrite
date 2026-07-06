# Cross-platform golden test fixtures

This directory is the **parity contract** between the platform implementations of
RollnWrite's game engines — today the iOS (Swift) `QwixxGame` and the Android
(Kotlin) port. The Swift engine sources under
`RollnWrite/Games/Qwixx/` are the source of truth for the *rules*; these
fixtures are the executable, language-neutral encoding of those rules.

**Both platforms must pass every fixture.** Each platform ships a small runner
that loads every `*.json` under `spec/fixtures/` and replays it against its
engine. The runners execute in CI, so a rule divergence on either platform
fails that platform's build instead of shipping a scorecard that disagrees with
the other one.

Rules for the fixtures themselves:

- Fixtures are hand-authored and hand-verified. Every expected number is
  computed from the rules, never copied from an engine's output — otherwise a
  bug would be enshrined as the contract.
- A fixture, once merged, changes only when the *rules* change (and then both
  platforms change with it in the same release).
- Fixtures test **engine semantics only** — no UI, no persistence, no
  platform-specific behaviour.

## Directory layout

One directory per game (or per rules-distinct variant family):

```
spec/
├─ README.md                      this document (normative)
└─ fixtures/
   ├─ qwixx-big-points/           Qwixx Big Points (cap 15, bonus rows)
   │  ├─ scoring-basics.json
   │  ├─ left-to-right.json
   │  ├─ locking.json
   │  ├─ bonus-rows.json
   │  ├─ penalties.json
   │  ├─ concede-finish.json
   │  └─ undo-redo.json
   ├─ qwixx-classic/              classic Qwixx (cap 12, no bonus rows)
   │  └─ basic.json
   └─ qwixx-bonus/                Qwixx Bonus, version A (cap 12, bonus bar)
      ├─ scoring-basics.json
      ├─ left-to-right.json
      ├─ locking.json
      ├─ bonus-bar.json
      ├─ penalties.json
      ├─ concede-finish.json
      └─ undo-redo.json
```

To add fixtures for a future game: create `spec/fixtures/<game-slug>/`, define
that game's step vocabulary in this README (a new "do" verb set and "assert"
key set mirroring its engine's mutators and observable state), and wire the
directory into both platforms' runners.

## Fixture file format

One JSON object per file:

```json
{
  "game": "qwixx",
  "variant": "big-points",
  "config": { "scoringCap": 15, "hasBonusRows": true },
  "name": "kebab-slug",
  "description": "what this case proves",
  "steps": [ ... ]
}
```

- `game` — game identifier; selects the engine under test.
- `variant` — `"big-points"` or `"classic"` for Qwixx.
- `config` — engine construction parameters. For Qwixx:
  `scoringCap` (triangular scoring cap: 15 for Big Points, 12 for classic) and
  `hasBonusRows` (`true` for Big Points, `false` for classic).
- `name` — kebab-case slug, must match the filename (without `.json`).
- `description` — one sentence: what rule(s) this fixture pins down.
- `steps` — executed in order against ONE fresh engine instance.

### Step forms

A step is EITHER a `"do"` (mutation attempt) or an `"assert"` (state check).

```json
{"do":"markColor","color":"red|yellow|green|blue","index":0-10,"expect":true|false}
{"do":"markBonus","row":"redYellow|greenBlue","index":0-10,"expect":true|false}
{"do":"penalty","expect":true|false}
{"do":"concede","color":"red|yellow|green|blue","expect":true|false}
{"do":"finish","expect":true|false}
{"do":"undo","expect":true|false}
{"do":"redo","expect":true|false}

{"assert":{
  "points":       {"red":0,"yellow":0,"green":0,"blue":0},
  "crosses":      {"red":0,"yellow":0,"green":0,"blue":0},
  "penalties":    0,
  "penaltyPoints":0,
  "totalScore":   0,
  "isGameOver":   false,
  "lockedRowCount":0,
  "rowLocked":    {"red":false,"yellow":false,"green":false,"blue":false},
  "canUndo":      false,
  "canRedo":      false
}}
```

- Every `"do"` step carries an explicit `"expect"`. There is no default.
- Every key inside `"assert"` is optional — assert any subset. The `points`,
  `crosses` and `rowLocked` maps may themselves list any subset of colours.
- Any step may carry an optional `"note"` string for human readers; runners
  MUST ignore it.

### Runner semantics (normative — both platforms implement exactly this)

For a `"do"` step:

1. Query the engine's **can-precondition** for that action
   (`canMarkColor`, `canMarkBonus`, `canAddPenalty`, `canConcedeRow`,
   `canFinishManually`, `canUndo`, `canRedo`) and assert it equals `"expect"`.
   For `undo`/`redo`, `"expect"` is compared against `canUndo`/`canRedo`
   *before* the call.
2. Invoke the mutator (`markColor`, `markBonus`, `addPenalty`, `concedeRow`,
   `finishGame`, `undo`, `redo`) regardless of the expectation.
3. When `"expect"` is `false`, the mutator MUST leave all observable state
   unchanged (illegal attempts are silent no-ops and are NOT recorded in
   history — a subsequent `undo` never "undoes" a refused move).

For an `"assert"` step, compare each listed key against the engine's
observable state:

| key              | engine observable                                        |
|------------------|----------------------------------------------------------|
| `points`         | `points(for: color)` per colour                          |
| `crosses`        | `crosses(for: color)` per colour                         |
| `penalties`      | penalty count                                            |
| `penaltyPoints`  | `penalties * 5`                                          |
| `totalScore`     | sum of the four colours' points minus `penaltyPoints`    |
| `isGameOver`     | manual finish OR ≥2 locked rows OR 4 penalties           |
| `lockedRowCount` | number of rows with `locked == true` (concessions count) |
| `rowLocked`      | per-colour `locked` flag                                 |
| `canUndo`        | history non-empty                                        |
| `canRedo`        | redo stack non-empty                                     |

Any mismatch fails the fixture with the step index, the key, expected and
actual values.

## Qwixx conventions the fixtures rely on

- **Indices are POSITIONS, not printed numbers.** Every row has 11 cells at
  indices 0…10, left to right as printed. Red and yellow print 2…12 ascending
  (index *i* shows number *i*+2); green and blue print 12…2 descending (index
  *i* shows number 12−*i*). Index 10 is always the lock number (12 for
  red/yellow, 2 for green/blue). The left-to-right rule is therefore identical
  index arithmetic for all four colours.
- **Left-to-right:** a cell is markable only if its index is strictly greater
  than every already-marked index in that row. Skipped cells are forfeited
  forever.
- **Locking:** index 10 additionally requires ≥5 existing marks in the row.
  Marking it sets the row locked AND the mark itself plus a +1 lock bonus both
  count as scoring crosses (a self-locked row of *n* marks scores *n*+1
  crosses).
- **Bonus rows (Big Points only):** `redYellow` sits between red and yellow,
  `greenBlue` between green and blue, aligned by column. A bonus cell at index
  *i* is markable once EITHER adjacent colour row has index *i* marked, and
  the left-to-right rule applies to the bonus row independently. A marked
  bonus cell counts as one scoring cross for BOTH adjacent colours.
- **Scoring:** `points = triangular(clamp(crosses, 0, cap))` with
  `triangular(n) = n(n+1)/2`. Values for n = 1…15:
  1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66, 78, 91, 105, 120.
  Big Points cap 15 (120 max/colour); classic cap 12 (78 max/colour — note a
  classic row maxes out at exactly 12 crosses: 11 marks + lock bonus).
- **Penalties:** −5 each, maximum 4; the 4th ends the game.
- **Concede:** locks a row WITHOUT marking index 10 — no lock bonus cross, but
  the row counts toward the two-locks end condition.
- **Game over:** manual finish OR ≥2 locked rows OR 4 penalties. Once over,
  every mutation's precondition is `false`.
- **Undo/redo:** strictly LIFO over *applied* actions. Undo exactly reverses
  (including un-locking a row whose lock that action set) and pushes onto the
  redo stack; redo re-applies through the normal mutator; any fresh applied
  move clears the redo stack.

## Qwixx Bonus (version A) fixture family

`spec/fixtures/qwixx-bonus/` covers the "Bonus" variant (NSV art. 4105):
classic Qwixx colour rows (cap 12, **no** two-colour bonus rows) plus a
**bonus bar** — twelve coloured fields fed by twelve "boxed" numbers (three
per colour row). Source of truth: `RollnWrite/Games/QwixxBonus/*.swift`
(`BonusGame`, `BonusLayout`, `BonusBar`).

`config` for this family carries no `hasBonusRows` (there are no two-colour
bonus rows in this variant) — just `{ "scoringCap": 12 }`. `variant` is
`"bonus"`.

### Additional/changed step vocabulary

```json
{"do":"markColor","color":"red|yellow|green|blue","index":0-10,"expect":true|false}
{"do":"penalty","expect":true|false}
{"do":"concede","color":"red|yellow|green|blue","expect":true|false}
{"do":"finish","expect":true|false}
{"do":"undo","expect":true|false}
{"do":"redo","expect":true|false}
```

There is no `markBonus` step — the bonus bar is never marked directly by the
player. It is **derived**: every `markColor` on a boxed cell automatically
earns the bar's next earnable field as a side effect (see below), and every
row completion (self-lock via `markColor` at index 10, or `concede`)
automatically forfeits that colour's remaining un-earned bar fields. Runners
MUST NOT expose a way to mark the bar directly — only assert its resulting
state.

```json
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
  "canRedo":       false,
  "barEarned":     [0,1,2],
  "barForfeited":  [3,4],
  "barEarnedCount":3
}}
```

- `barEarned` — the exact SET of bar-field indices (0…11) currently earned.
  Compared as a set (order-independent); assert any subset of indices you
  care about is present by listing exactly the expected full set for that
  key (a partial-membership check is NOT supported — list the whole set).
- `barForfeited` — the exact set of bar-field indices currently forfeited
  (crossed out because their colour was completed, but never earned).
- `barEarnedCount` — convenience for `barEarned.size` (mirrors the engine's
  `BonusBar.earnedCount`), handy when the exact index set isn't the point of
  the fixture.
- `points`/`crosses`/`totalScore` etc. otherwise mean exactly what they mean
  for classic Qwixx (this variant scores identically — the bar awards no
  points of its own). There is no `hasBonusRows` config key and no
  `crosses`-includes-bonus behaviour: `crosses(color) == row(color).scoringCrosses`
  always for this variant.

### Runner semantics unique to this family

For a `"do":"markColor"` step, in addition to the classic Qwixx runner
semantics (query `canMarkColor`, invoke `markColor`, assert no-op on refusal):

- If the marked cell is one of that colour's three **boxed** indices (see the
  index table below) AND the bar still has an earnable field
  (`nextEarnableIndex != nil`), the mark ALSO earns that field as an atomic
  part of the same action — a fixture asserting `barEarned`/`barEarnedCount`
  immediately after such a `markColor` step must include the newly earned
  field.
- If the marked cell is index 10 (locks the row), that same action ALSO
  forfeits every remaining un-earned, non-forfeited bar field of that colour
  — asserted via `barForfeited` immediately after.
- `"do":"concede"` also forfeits that colour's remaining un-earned bar fields
  (same forfeiture rule as a self-lock), even though it never marks index 10
  and earns no lock-bonus cross.
- `"do":"undo"` reverses a `markColor`'s bar effects atomically: un-marks the
  cell, un-locks the row if that action locked it, un-earns the field it
  earned (if any), and un-forfeits every field that action forfeited. Reverses
  a `concede`'s forfeiture the same way.

### Boxed-number indices per colour (bar-earning trigger cells)

Boxed numbers are transcribed from the official score sheet by printed value,
then mapped to column index via each colour's printed order (red/yellow
ascend 2→12, green/blue descend 12→2 — same index arithmetic as the base
game, see above):

| colour | boxed printed values | boxed indices |
|--------|----------------------|---------------|
| red    | 3, 6, 9              | 1, 4, 7       |
| yellow | 5, 8, 11             | 3, 6, 9       |
| green  | 11, 7, 4             | 1, 5, 8       |
| blue   | 10, 8, 5             | 2, 4, 7       |

### The bonus bar (12 fields, left → right, snaking colours)

| bar index | 0   | 1      | 2     | 3    | 4     | 5   | 6    | 7      | 8   | 9      | 10   | 11    |
|-----------|-----|--------|-------|------|-------|-----|------|--------|-----|--------|------|-------|
| colour    | red | yellow | green | blue | green | red | blue | yellow | red | yellow | blue | green |

Exactly three fields per colour (matching that colour's three boxed cells).
`nextEarnableIndex` is the LOWEST index that is neither in `barEarned` nor
`barForfeited` — earning always fills that field, regardless of which
colour's boxed cell triggered it (any colour's boxed mark advances the SAME
shared bar). Forfeiting removes a colour's own remaining fields from
eligibility (they are simply skipped by future earns) without ever earning
them.
