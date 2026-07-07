# Qwixx Bonus (version A) — fixture vocabulary

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
