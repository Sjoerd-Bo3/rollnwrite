# Qwixx Connected fixtures

Rules source of truth: `RollnWrite/Games/QwixxConnected/` (Swift). Mirrors the
top-level `spec/README.md` shape and runner semantics — read that document
first; this file only adds what's specific to the Connected ("The Chain")
variant.

Connected plays exactly like classic Qwixx (four colour rows, cap 12,
NO bonus rows, NO extra row on the board) plus six printed **chains**: pairs
of circled spaces in vertically-adjacent rows, joined on the sheet by a
printed line. Whenever a player crosses one circled chain space they MUST
automatically also cross its linked partner space — this happens always and
at any point in the game, ignoring the normal left-to-right rule and even
reaching into an already-locked partner row. The four colour rows score
unchanged; an automatically-crossed partner simply counts as one more cross
in its own row.

## Fixture file format

Same envelope as `spec/README.md`, with:

```json
{
  "game": "qwixx",
  "variant": "connected",
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
  Big-Points-style cap-15). There is no `hasBonusRows` key: Connected has no
  two-colour bonus rows at all.
- `variant` is always `"connected"`.

### Step forms

All the base vocabulary from `spec/README.md` applies **unchanged** for
colour rows (`markColor`), penalties, concede, finish, undo, redo. This
variant adds **no new "do" verb** — chain co-marks are never triggered
directly, only as an automatic side effect of `markColor` on a circled chain
space (see below). `assert` gains no new keys either: a chain co-mark is
just another entry in the same `crosses`/`points`/`rowLocked` state, so the
base assertion vocabulary is sufficient to pin down every chain effect.

```json
{"do":"markColor","color":"red|yellow|green|blue","index":0-10,"expect":true|false}
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

### Runner semantics unique to this family

For a `"do":"markColor"` step, in addition to the classic Qwixx runner
semantics (query `canMarkColor`, invoke `markColor`, assert no-op on
refusal):

- If the marked cell is one end of a printed **chain** (see the index table
  below) AND its linked partner cell is not already marked, the SAME action
  atomically also crosses the partner cell in the partner's row — a fixture
  asserting `crosses`/`points` immediately after such a `markColor` step must
  include the partner's freshly gained cross.
- The forced co-mark **ignores the partner row's own left-to-right rule**
  (it may land to the left of that row's `maxMarkedIndex`) and **ignores
  whether the partner row is locked** — it applies unconditionally.
- The forced co-mark **never locks a row itself**, even though it changes
  `marks`: no chain pairs with index 10 (the lock cell), so `rowLocked`
  never flips as a side effect of a chain co-mark.
- If the partner cell is already marked (whether from an earlier direct
  mark or an earlier chain co-mark), nothing further happens — no double
  mark, and the action carries no partner effect to undo.
- `"do":"undo"` reverses a `markColor`'s chain effect atomically: un-marks
  the deliberately-crossed cell (and un-locks the row if that action locked
  it) AND un-marks the forced partner cross in the same step, if there was
  one. `"do":"redo"` re-applies through the same mutator, which re-derives
  the chain partner deterministically from the (now-restored) marks and the
  static chain table, reproducing the identical co-mark — the runner never
  needs a separate "chain" replay path.
- `"do":"concede"` and `"do":"finish"` behave exactly as in classic Qwixx;
  neither ever touches a chain (chains are only ever triggered by
  `markColor`).

### The six printed chains (index-based, sheet "A" / "Kette" version B)

Indices are POSITIONS as defined in the base `spec/README.md` (0…10, left to
right as printed; red/yellow ascend 2→12, green/blue descend 12→2). Both
ends of every chain sit in the **same column index** — that's how the
printed line always runs a short, straight vertical segment between two
adjacent rows.

| # | end A            | end B               | printed values     |
|---|-------------------|---------------------|---------------------|
| 1 | red index 4       | yellow index 4      | red 6 ↔ yellow 6     |
| 2 | red index 9       | yellow index 9      | red 11 ↔ yellow 11   |
| 3 | yellow index 1    | green index 1       | yellow 3 ↔ green 11  |
| 4 | yellow index 6    | green index 6       | yellow 8 ↔ green 6   |
| 5 | green index 3     | blue index 3        | green 9 ↔ blue 9     |
| 6 | green index 8     | blue index 8        | green 4 ↔ blue 4     |

No cell belongs to more than one chain, so an automatic co-mark never
cascades into a third field — the partner cross is always exactly one
additional mark, never a chain reaction.

## Qwixx Connected conventions the fixtures rely on

- **Colour rows are classic Qwixx** (cap 12, 12-crosses-max scoring: 11
  marks + lock bonus), NOT Big Points — reuse the base `spec/README.md`
  colour-row rules (left-to-right, locking at index 10 needing ≥5 prior
  marks, concede, penalties, game-over, undo/redo) verbatim.
- **Chains never score separately.** `totalScore` is always the sum of the
  four colours' triangular points minus penalty points; a chain co-mark
  simply adds one ordinary cross to the partner row's count, exactly as if
  the player had crossed it directly (which — per the rule — they are not
  otherwise allowed to do out of order).
- **Chains apply unconditionally**, at any point in the game, including
  into an already-locked or already-conceded partner row — the fixture
  `chains.json` pins this down directly by conceding a row and then legally
  crossing its chain partner in a still-open row.
- **Forfeiture is otherwise identical to classic Qwixx**: skipping a cell
  (whether the skip happens because of a direct mark or because a chain
  co-mark jumped past it) forfeits every earlier index in that row forever.
- **Game-over freezes chains too**: once `isGameOver` is true (two locked
  rows, four penalties, or manual finish), `canMarkColor` is `false` for
  every cell, chain space or not, so no chain can fire after the game ends.
- **Undo/redo is one shared LIFO history** across colour marks (with their
  chain effects folded in as part of the SAME history entry), penalties,
  concede and finish — see `ConnectedAction.color(_:index:didLock:auto:)` in
  `ConnectedModels.swift`, which records the auto-crossed partner (or `nil`
  if none) inline so a single undo/redo always keeps a deliberate cross and
  its forced co-mark atomic.
