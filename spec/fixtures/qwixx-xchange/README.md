# Qwixx X-Change fixtures

Rules source of truth: `RollnWrite/Games/QwixxXChange/` (Swift). Mirrors the
top-level `spec/README.md` shape and runner semantics — read that document
first; this file only adds what's specific to the X-Change variant.

X-Change plays exactly like classic Qwixx (four colour rows, cap 12,
NO bonus rows) plus a ninth-field "X-Change" swap row that is crossed
strictly left-to-right, exactly like a colour row's ordering rule, but:

- it has its own independent left-to-right ordering track (not tied to any
  colour row's marks);
- it contributes **zero points** to the score, at any point in the game — the
  official total is red + yellow + green + blue − penalties; the printed
  sheet has no box for the X-Change row (see the assumption note in
  `XChangeModels.swift` / `QwixxXChangeGame.swift`);
- it freezes exactly like every other action once `isGameOver` is true.

## Fixture file format

Same envelope as `spec/README.md`, with:

```json
{
  "game": "qwixx",
  "variant": "xchange",
  "config": { "scoringCap": 12 },
  "name": "kebab-slug",
  "description": "what this case proves",
  "steps": [ ... ]
}
```

- `game` is `"qwixx"` (this variant reuses the same
  `GameColor`/`ColorRow`/`TriangularScoring` machinery as classic Qwixx).
  Discovery is by directory: each runner scans its own `spec/fixtures/<id>/`.
- `config.scoringCap` is always `12` for this variant (classic scoring — no
  Big-Points-style cap-15). There is no `hasBonusRows` key: X-Change has no
  bonus rows at all, so that config key is simply absent (never `false`) to
  keep this variant's config shape distinct at a glance.
- `variant` is always `"xchange"`.

### Step forms

All the base vocabulary from `spec/README.md` applies unchanged for colour
rows (`markColor`), penalties, concede, finish, undo, redo. This variant adds
ONE new "do" verb and extends `assert`:

```json
{"do":"markXChange","index":0-8,"expect":true|false}

{"assert":{
  "points":         {"red":0,"yellow":0,"green":0,"blue":0},
  "crosses":        {"red":0,"yellow":0,"green":0,"blue":0},
  "penalties":      0,
  "penaltyPoints":  0,
  "totalScore":     0,
  "isGameOver":     false,
  "lockedRowCount": 0,
  "rowLocked":      {"red":false,"yellow":false,"green":false,"blue":false},
  "canUndo":        false,
  "canRedo":        false,
  "xchangeCrossed": 0,
  "xchangeMarks":   [0, 2, 5]
}}
```

- `xchangeCrossed` — count of crossed X-Change fields (`XChangeRow.crossed` /
  `xchange.marks.size`). Informational only; never contributes to
  `totalScore`.
- `xchangeMarks` — the exact set of crossed X-Change field indices, as a
  sorted array (order-independent membership check on the runner side).
  Lets a fixture pin down *which* fields got crossed, not just the count,
  which matters for proving the left-to-right/forfeit rule precisely.

There is no `markBonus` step and no `hasBonusRows`/`bonusMarks` assert key
for this variant — X-Change simply has no bonus rows.

### Runner semantics (delta from the base document)

For `"do":"markXChange"`:

1. Query `canMarkXChange(index)` and assert it equals `"expect"`.
2. Invoke `markXChange(index)` regardless of the expectation.
3. When `"expect"` is `false`, the mutator MUST leave all observable state —
   including `xchangeMarks` — unchanged (illegal attempts are silent no-ops,
   never recorded in history).

For the `"assert"` key `xchangeCrossed`, compare against
`xchange.crossed`(`XChangeRow.crossed`, i.e. `marks.count`). For
`xchangeMarks`, compare the full set of crossed indices (`xchange.marks`)
against the given array, ignoring array order.

## Qwixx X-Change conventions the fixtures rely on

- **Colour rows are classic Qwixx** (cap 12, 12-crosses-max scoring: 11 marks
  + lock bonus), NOT Big Points — reuse the base `spec/README.md` colour-row
  rules (left-to-right, locking at index 10 needing ≥5 prior marks, concede,
  penalties, game-over, undo/redo) verbatim. There is no bonus-row activation
  rule at all in this variant.
- **The X-Change row (9 fields, indices 0…8)** has its own independent
  left-to-right rule: a field at index *i* is markable only while the game is
  live, it is not already marked, and *i* is strictly greater than every
  already-crossed X-Change index (`maxMarkedIndex`). Skipped fields are
  forfeited forever, identical in spirit to a colour row but on a completely
  separate track — marking colour rows never unlocks/forfeits X-Change
  fields and vice versa.
- **The X-Change row scores nothing.** `totalScore` is unaffected by
  `xchangeCrossed`/`xchangeMarks` at every point in the game; only the four
  colour rows and penalties contribute.
- **Game-over freezes the X-Change row too**: once `isGameOver` is true (two
  locked rows, 4 penalties, or manual finish), `canMarkXChange` is `false`
  for every index, exactly like `canMarkColor`.
- **Undo/redo is one shared LIFO history** across colour marks, X-Change
  marks, penalties, concede and finish — an X-Change mark is just another
  entry in the same stack, undone/redone through the same strict LIFO
  discipline as everything else (see `XChangeAction` in `XChangeModels.swift`).
