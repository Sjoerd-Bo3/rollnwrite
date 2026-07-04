//
//  CleverGame.swift
//  RollnWrite – Clever
//
//  Engine for "That's Pretty Clever". Enforces each area's structure and
//  computes every score, including foxes (= lowest area score). Foxes and the
//  reroll/+1 EARNED counts are derived automatically from the state; spending
//  a reroll/+1 (and applying extra marks) stays a manual player action.
//
//  SRP: rules + transitions + scoring delegation only. DIP/LSP: conforms to the
//  generic `Scoreboard` protocol from Core.
//

import SwiftUI

@MainActor
public final class CleverGame: ObservableObject, Scoreboard, CleverUndoRedo, CleverFoxScoring {

    @Published public private(set) var state = CleverState()

    /// Human-readable advisories for bonuses the player must act on themselves
    /// (dice actions like +1/re-roll, free marks where the box is the player's
    /// choice, foxes earned, or number-bonuses that couldn't be auto-placed).
    /// Auto-applied bonuses (numbers into orange/purple, free green marks) do not
    /// appear here — they are written straight onto the card and pushed to undo.
    @Published public private(set) var earnedBonuses: [String] = []

    /// The round index (0…5) whose summary the UI should present, set right
    /// after `toggleRound` crosses (not un-crosses) a round. The view reads
    /// `roundSnapshot(for:)` for the content and calls `clearRoundSummary()`
    /// to dismiss — same advisory pattern as `earnedBonuses`. `nil` when there
    /// is nothing to show (issue #59; only ever set when round management is
    /// presented by the UI, but harmless if read regardless).
    @Published public private(set) var pendingRoundSummary: Int?

    /// Actions undone via `undo()`, most-recently-undone last, so `redo()` can
    /// re-apply them in LIFO order. Deliberately NOT persisted (`CleverState` /
    /// `Codable` is untouched) and NOT part of `state` — redo is an in-memory,
    /// per-session convenience. Any new forward move (via `recordAction`)
    /// clears it, matching standard undo/redo semantics.
    var redoStack: [CleverAction] = []

    /// `true` while `redo()` is replaying an undone action's raw mutation, so
    /// `recordAction` knows NOT to treat it as a fresh move and clear the rest
    /// of the redo stack.
    var isRedoing = false

    /// The persisted LIFO history, exposed to `CleverUndoRedo` (backed by state).
    var history: [CleverAction] {
        get { state.history }
        set { state.history = newValue }
    }

    private let persistenceKey: String

    /// Whether the "round management" Settings toggle is on (issue #57/#59).
    /// The engine cannot read `@AppStorage` itself, so the hosting view syncs
    /// this in (mirrors how `startNewGame(playerCount:)` already takes the
    /// player-count CHOICE the view derives from that same toggle) — see
    /// `CleverScorecardView`'s `.onAppear`/`.onChange(of: roundManagement)`.
    /// Purely a UI-driven read of a setting, not a game move: NOT persisted
    /// and NOT part of `state`, so it never touches `Codable`/undo.
    @Published public var roundManagementOn = false

    public init(persistenceKey: String = "rollnwrite.clever1.state") {
        self.persistenceKey = persistenceKey
        load()
    }

    // MARK: - Colour theme (app-wide physical dice → areas)

    /// Display colour for an area, resolved from the app-wide dice palette
    /// (`DiceTheme`) by nearest-colour matching against the standard colours.
    /// Presentation only — scoring never touches it.
    public func color(_ area: CleverArea) -> DiceColor {
        let areas = CleverArea.allCases
        return DiceTheme.shared.mapped(standard: areas.map(\.standardColor))[areas.firstIndex(of: area)!]
    }

    // MARK: - Yellow (cross numbers in any order)

    public func isYellowFree(_ index: Int) -> Bool { CleverLayout.yellowGrid[index] == nil }

    public func canMarkYellow(_ index: Int) -> Bool {
        !isYellowFree(index) && !state.yellowCrossed.contains(index)
    }

    public func markYellow(_ index: Int) {
        guard canMarkYellow(index) else { return }
        let before = completedTriggers()
        state.yellowCrossed.insert(index)
        recordAction(.yellow(index))
        applyNewlyEarned(before: before)
        save()
    }

    // MARK: - Blue (cross sums in any order)

    public func canMarkBlue(_ value: Int) -> Bool {
        CleverLayout.blueValues.contains(value) && !state.blueCrossed.contains(value)
    }

    public func markBlue(_ value: Int) {
        guard canMarkBlue(value) else { return }
        let before = completedTriggers()
        state.blueCrossed.insert(value)
        recordAction(.blue(value))
        applyNewlyEarned(before: before)
        save()
    }

    // MARK: - Green (mark left→right)

    public func canMarkGreen() -> Bool { state.greenCount < CleverLayout.rowLength }

    public func markGreen() {
        guard canMarkGreen() else { return }
        let before = completedTriggers()
        state.greenCount += 1
        recordAction(.green)
        applyNewlyEarned(before: before)
        save()
    }

    // MARK: - Orange (write value left→right, × multiplier)

    public var orangeNextIndex: Int? { state.orange.firstIndex(where: { $0 == nil }) }

    /// Orange has no value restriction; any die value 1…6 is allowed.
    public func allowedOrangeValues() -> [Int] { orangeNextIndex == nil ? [] : Array(1...6) }

    public func fillOrange(_ value: Int) {
        guard let i = orangeNextIndex, (1...6).contains(value) else { return }
        let before = completedTriggers()
        state.orange[i] = value
        recordAction(.orange(i, value: value))
        applyNewlyEarned(before: before)
        save()
    }

    // MARK: - Purple (write value left→right, strictly increasing; any after a 6)

    public var purpleNextIndex: Int? { state.purple.firstIndex(where: { $0 == nil }) }

    public func allowedPurpleValues() -> [Int] {
        guard let i = purpleNextIndex else { return [] }
        guard i > 0, let prev = state.purple[i - 1] else { return Array(1...6) }
        if prev == 6 { return Array(1...6) }
        return Array((prev + 1)...6)
    }

    public func fillPurple(_ value: Int) {
        guard let i = purpleNextIndex, allowedPurpleValues().contains(value) else { return }
        let before = completedTriggers()
        state.purple[i] = value
        recordAction(.purple(i, value: value))
        applyNewlyEarned(before: before)
        save()
    }

    // MARK: - Automatic bonuses

    /// Identity of a bonus-granting trigger (a row/column/cell completion).
    /// Used only to compare "completed before" vs "completed after" a mark; never
    /// stored, so undo stays consistent and re-completing re-earns the bonus.
    private enum Trigger: Hashable {
        case yellowRow(Int)
        case yellowDiagonal
        case blueRow(Int)
        case blueColumn(Int)
        case greenCell(Int)
        case orangeCell(Int)
        case purpleCell(Int)
    }

    /// Yellow grid row `r`'s numbered (non-free) cell indices.
    private static let yellowRowCells: [[Int]] = (0..<4).map { r in
        (0..<4).map { r * 4 + $0 }.filter { CleverLayout.yellowGrid[$0] != nil }
    }

    /// Blue values that make up display row `r` (skipping the rule-icon cell).
    private static let blueRowValues: [[Int]] = (0..<3).map { r in
        (0..<4).compactMap { CleverLayout.blueGrid[r * 4 + $0] }
    }

    /// Blue values that make up display column `c` (skipping the rule-icon cell).
    private static let blueColumnValues: [[Int]] = (0..<4).map { c in
        (0..<3).compactMap { CleverLayout.blueGrid[$0 * 4 + c] }
    }

    /// The set of triggers that are currently complete in the present state.
    private func completedTriggers() -> Set<Trigger> {
        var done = Set<Trigger>()
        // Yellow rows.
        for r in CleverGame.yellowRowCells.indices {
            let cells = CleverGame.yellowRowCells[r]
            if !cells.isEmpty, Set(cells).isSubset(of: state.yellowCrossed) {
                done.insert(.yellowRow(r))
            }
        }
        // Yellow main diagonal.
        if Set(CleverLayout.yellowDiagonal).isSubset(of: state.yellowCrossed) {
            done.insert(.yellowDiagonal)
        }
        // Blue rows & columns.
        for r in CleverGame.blueRowValues.indices {
            let vals = CleverGame.blueRowValues[r]
            if !vals.isEmpty, Set(vals).isSubset(of: state.blueCrossed) { done.insert(.blueRow(r)) }
        }
        for c in CleverGame.blueColumnValues.indices {
            let vals = CleverGame.blueColumnValues[c]
            if !vals.isEmpty, Set(vals).isSubset(of: state.blueCrossed) { done.insert(.blueColumn(c)) }
        }
        // Green / orange / purple: a cell with a bonus is "complete" once filled.
        for i in CleverLayout.greenBonus.keys where i < state.greenCount {
            done.insert(.greenCell(i))
        }
        for i in CleverLayout.orangeBonus.keys where state.orange.indices.contains(i) && state.orange[i] != nil {
            done.insert(.orangeCell(i))
        }
        for i in CleverLayout.purpleBonus.keys where state.purple.indices.contains(i) && state.purple[i] != nil {
            done.insert(.purpleCell(i))
        }
        return done
    }

    /// The bonus icon granted by a trigger, if any.
    private func bonus(for trigger: Trigger) -> BonusIcon? {
        switch trigger {
        case let .yellowRow(r): return CleverLayout.yellowRowBonus[r]
        case .yellowDiagonal:   return .plusOne
        case let .blueRow(r):   return CleverLayout.blueRowBonus[r]
        case let .blueColumn(c): return CleverLayout.blueColBonus[c]
        case let .greenCell(i): return CleverLayout.greenBonus[i]
        case let .orangeCell(i): return CleverLayout.orangeBonus[i]
        case let .purpleCell(i): return CleverLayout.purpleBonus[i]
        }
    }

    /// After a mark, detect triggers that went from incomplete → complete and
    /// fire their bonuses. Auto-applied marks may complete further triggers, so
    /// the detection is re-run (chained) up to a safety depth cap.
    private func applyNewlyEarned(before: Set<Trigger>, depth: Int = 0) {
        guard depth < 12 else { return }
        let after = completedTriggers()
        let newlyDone = after.subtracting(before)
        guard !newlyDone.isEmpty else { return }

        // Apply in a stable order so banner messages read consistently.
        for trigger in newlyDone.sorted(by: { triggerOrder($0) < triggerOrder($1) }) {
            guard let icon = bonus(for: trigger) else { continue }
            apply(icon, depth: depth)
        }
    }

    /// A deterministic ordering key for triggers (banner readability only).
    private func triggerOrder(_ t: Trigger) -> Int {
        switch t {
        case let .yellowRow(r): return 0 + r
        case .yellowDiagonal:   return 10
        case let .blueRow(r):   return 20 + r
        case let .blueColumn(c): return 30 + c
        case let .greenCell(i): return 40 + i
        case let .orangeCell(i): return 60 + i
        case let .purpleCell(i): return 80 + i
        }
    }

    /// Apply a single earned bonus. Auto-placeable bonuses are written onto the
    /// card (and pushed to undo, then chained); everything else becomes an
    /// advisory string in `earnedBonuses`.
    private func apply(_ icon: BonusIcon, depth: Int) {
        switch icon {
        case .fox:
            note("🦊 Fox earned!")
        case .reroll:
            note("Re-roll")
        case .plusOne:
            note("+1 to a die")
        case let .mark(area):
            switch area {
            case .green:
                if canMarkGreen() {
                    let before = completedTriggers()
                    state.greenCount += 1
                    recordAction(.green)
                    applyNewlyEarned(before: before, depth: depth + 1)
                } else {
                    note("Green is full — mark skipped")
                }
            case .yellow:
                note("Cross any yellow box")
            case .blue:
                note("Cross any blue box")
            case .orange, .purple:
                // No free-mark bonuses target orange/purple; advisory fallback.
                note("Cross any \(area.title.lowercased()) box")
            }
        case let .number(area, n):
            switch area {
            case .orange:
                if let i = orangeNextIndex {
                    let before = completedTriggers()
                    state.orange[i] = n
                    recordAction(.orange(i, value: n))
                    applyNewlyEarned(before: before, depth: depth + 1)
                } else {
                    note("Orange \(n) earned — row is full")
                }
            case .purple:
                if let i = purpleNextIndex, allowedPurpleValues().contains(n) {
                    let before = completedTriggers()
                    state.purple[i] = n
                    recordAction(.purple(i, value: n))
                    applyNewlyEarned(before: before, depth: depth + 1)
                } else {
                    note("Purple \(n) earned — doesn't fit the sequence")
                }
            case .yellow, .blue, .green:
                // No number-bonuses target these areas; advisory fallback.
                note("Write \(n) in \(area.title.lowercased())")
            }
        case .crossOrSix:
            // Round 4's printed badge only ever reaches `cleverRoundBadge` for
            // DISPLAY (see `CleverLayout.roundFourBonus`) — it is never a
            // member of `roundBonuses` or any area bonus dictionary, so
            // `bonus(for:)` can never route it here. Case kept only for
            // switch exhaustiveness over `BonusIcon`.
            break
        }
    }

    private func note(_ message: String) {
        earnedBonuses.append(message)
    }

    /// Dismiss the earned-bonus banner.
    public func clearEarnedBonuses() {
        earnedBonuses.removeAll()
    }

    // MARK: - Player count & round count (issue #59)

    /// Standard round count for a player count, per the official rules
    /// (matches the sheet's dark round-5/6 tiles for 3–4 players):
    /// 1–2 players → 6 rounds, 3 → 5, 4 → 4.
    public static func roundCount(forPlayers players: Int) -> Int {
        switch players {
        case 3: return 5
        case 4: return 4
        default: return 6 // 1–2 players (and any unexpected value) → 6
        }
    }

    /// The active round count for the CURRENT game, derived from
    /// `state.playerCount`. `nil` (not chosen — round management off, or an
    /// older save) falls back to the historical 6-round bar.
    public var roundCount: Int? {
        state.playerCount.map(CleverGame.roundCount(forPlayers:))
    }

    /// Sets the player count and resets the board — the "New game" flow when
    /// round management is on. Player count is persisted BOOKKEEPING (like
    /// `roundsCrossed`), not a game move, so it is not part of `history`.
    /// `state = CleverState()` also clears `manuallyFinished`.
    public func startNewGame(playerCount: Int) {
        state = CleverState()
        state.playerCount = playerCount
        earnedBonuses.removeAll()
        pendingRoundSummary = nil
        redoStack = []
        save()
    }

    /// Total crossed/written cells across every area — the "marks" figure for
    /// the round-summary delta. Purely derived from state, like `foxCount`.
    public var markCount: Int {
        state.yellowCrossed.count
            + state.blueCrossed.count
            + state.greenCount
            + state.orange.compactMap { $0 }.count
            + state.purple.compactMap { $0 }.count
    }

    /// `SheetRoundsBar`'s `darkFrom` for THIS game: the round count when a
    /// player count was chosen (issue #59), else the historical constant `4`
    /// — i.e. round management off, or a pre-#59 save, look exactly as
    /// before. The bar's total tile count stays 6 either way (the printed
    /// sheet always shows all 6 numbers; fewer players just start the dark
    /// "already past the end" tiles earlier).
    public var roundsBarDarkFrom: Int { roundCount ?? 4 }

    // MARK: - Rounds bar (bookkeeping, not a game move)

    /// Cross / uncross a round tile (index 0…5). This is BOOKKEEPING, not a
    /// move: it never enters the LIFO `history` (so undo skips it entirely)
    /// and is never blocked by game rules. Crossing a round with a printed
    /// start-of-round bonus (rounds 1–3) feeds the reroll/+1 earned counts.
    /// Also captures/removes a `CleverRoundSnapshot` (issue #59) so a
    /// round-summary UI can report the delta vs. the previous round; this is
    /// derived bookkeeping too, so it stays out of `history` just like the
    /// crossed-round set itself. `roundSnapshots` is always kept sorted by
    /// ROUND INDEX (not crossing order), one entry per crossed round, so
    /// un-crossing any round — not just the most recently crossed one — drops
    /// exactly its own snapshot and leaves the rest consistent.
    public func toggleRound(_ index: Int) {
        guard CleverLayout.roundBonuses.indices.contains(index) else { return }
        let sortedCrossed = state.roundsCrossed.sorted()
        if state.roundsCrossed.contains(index) {
            let rank = sortedCrossed.firstIndex(of: index) ?? 0
            state.roundsCrossed.remove(index)
            if state.roundSnapshots.indices.contains(rank) { state.roundSnapshots.remove(at: rank) }
            if pendingRoundSummary == index { pendingRoundSummary = nil }
        } else {
            let rank = sortedCrossed.filter { $0 < index }.count
            state.roundsCrossed.insert(index)
            let snapshot = CleverRoundSnapshot(totalScore: totalScore, markCount: markCount)
            state.roundSnapshots.insert(snapshot, at: min(rank, state.roundSnapshots.count))
            pendingRoundSummary = index
        }
        save()
    }

    /// The previous round's snapshot (the one just before round `index` in
    /// round order), or a zeroed snapshot if `index` is the first crossed
    /// round — the baseline the round-summary delta is computed against.
    public func previousRoundSnapshot(before index: Int) -> CleverRoundSnapshot {
        let rank = state.roundsCrossed.sorted().firstIndex(of: index) ?? 0
        guard rank > 0, state.roundSnapshots.indices.contains(rank - 1) else { return CleverRoundSnapshot() }
        return state.roundSnapshots[rank - 1]
    }

    /// The snapshot captured when round `index` was crossed, if any.
    public func roundSnapshot(for index: Int) -> CleverRoundSnapshot? {
        guard state.roundsCrossed.contains(index) else { return nil }
        let rank = state.roundsCrossed.sorted().firstIndex(of: index) ?? 0
        return state.roundSnapshots.indices.contains(rank) ? state.roundSnapshots[rank] : nil
    }

    /// Dismiss the round-summary sheet/banner.
    public func clearRoundSummary() {
        pendingRoundSummary = nil
    }

    // MARK: - Reroll / +1 tracks (earned counted, spending tracked)

    /// Rerolls earned from completed AREA triggers. DERIVED from the current
    /// state (exactly like `foxCount`) rather than stored: the engine's bonus
    /// model never persists triggers (see `Trigger`), so undoing the mark that
    /// completed a row/column/cell automatically un-earns its reroll/+1, and
    /// re-completing re-earns it — no counter can ever drift from the card.
    public var areaRerollsEarned: Int { earnedBonusCount(.reroll) }

    /// +1s earned from completed AREA triggers (derived; see `areaRerollsEarned`).
    public var areaExtraDiceEarned: Int { earnedBonusCount(.plusOne) }

    private func earnedBonusCount(_ icon: BonusIcon) -> Int {
        completedTriggers().filter { bonus(for: $0) == icon }.count
    }

    /// Rerolls granted by crossed rounds with a printed start-of-round bonus.
    public var roundRerollsEarned: Int { roundGrantCount(.reroll) }
    public var roundExtraDiceEarned: Int { roundGrantCount(.plusOne) }

    private func roundGrantCount(_ icon: BonusIcon) -> Int {
        state.roundsCrossed.filter {
            CleverLayout.roundBonuses.indices.contains($0) && CleverLayout.roundBonuses[$0] == icon
        }.count
    }

    /// Total rerolls the player has EARNED so far (rounds + area bonuses).
    /// Track slots at indices below this are spendable.
    public var rerollsEarned: Int { roundRerollsEarned + areaRerollsEarned }

    /// Total +1s the player has EARNED so far (rounds + area bonuses).
    public var extraDiceEarned: Int { roundExtraDiceEarned + areaExtraDiceEarned }

    /// Spend / unspend a reroll slot. Only earned slots (index < `rerollsEarned`)
    /// can be crossed; uncrossing is always allowed.
    public func toggleReroll(_ slot: Int) {
        if state.rerollUsed.contains(slot) {
            state.rerollUsed.remove(slot)
        } else {
            guard slot < rerollsEarned else { return }
            state.rerollUsed.insert(slot)
            recordAction(.reroll(slot))
        }
        save()
    }

    /// Spend / unspend a +1 slot. Only earned slots (index < `extraDiceEarned`)
    /// can be crossed; uncrossing is always allowed.
    public func toggleExtraDie(_ slot: Int) {
        if state.extraDieUsed.contains(slot) {
            state.extraDieUsed.remove(slot)
        } else {
            guard slot < extraDiceEarned else { return }
            state.extraDieUsed.insert(slot)
            recordAction(.extraDie(slot))
        }
        save()
    }

    // MARK: - Scoring

    public func yellowCompletedColumns() -> [Int] {
        CleverLayout.yellowColumns.indices.filter { col in
            Set(CleverLayout.yellowColumns[col]).isSubset(of: state.yellowCrossed)
        }
    }

    public var yellowScore: Int {
        yellowCompletedColumns().reduce(0) { $0 + CleverLayout.yellowColumnValues[$1] }
    }

    public var blueScore: Int { CleverLayout.bluePointScale[state.blueCrossed.count] }

    public var greenScore: Int {
        state.greenCount == 0 ? 0 : CleverLayout.greenScale[state.greenCount - 1]
    }

    public var orangeScore: Int {
        state.orange.enumerated().reduce(0) { sum, pair in
            guard let v = pair.element else { return sum }
            return sum + v * CleverLayout.orangeMultipliers[pair.offset]
        }
    }

    public var purpleScore: Int { state.purple.compactMap { $0 }.reduce(0, +) }

    public func score(for area: CleverArea) -> Int {
        switch area {
        case .yellow: return yellowScore
        case .blue:   return blueScore
        case .green:  return greenScore
        case .orange: return orangeScore
        case .purple: return purpleScore
        }
    }

    /// Foxes are auto-detected at the printed fox locations (all are row/column
    /// or reach-this-cell completions), since they only affect end scoring.
    public var foxCount: Int {
        var n = 0
        if Set(CleverLayout.yellowFoxCells).isSubset(of: state.yellowCrossed) { n += 1 }
        if Set(CleverLayout.blueFoxValues).isSubset(of: state.blueCrossed) { n += 1 }
        if state.greenCount > CleverLayout.greenFoxIndex { n += 1 }
        if state.orange[CleverLayout.orangeFoxIndex] != nil { n += 1 }
        if state.purple[CleverLayout.purpleFoxIndex] != nil { n += 1 }
        return n
    }

    public var lowestAreaScore: Int {
        CleverArea.allCases.map { score(for: $0) }.min() ?? 0
    }

    // MARK: - Scoreboard

    public var totalScore: Int {
        CleverArea.allCases.reduce(0) { $0 + score(for: $1) } + foxScore
    }

    /// Game over when the player manually finishes (issue #57's header flag),
    /// OR — when round management is ON — every round of the CURRENT game is
    /// crossed. Round management OFF (or an older save with no `playerCount`
    /// chosen, so `roundCount` is `nil`) reproduces the historical pure
    /// scorecard: only a manual finish ends the game; the rounds bar is just a
    /// tally. `roundManagementOn` is the view-synced read of the Settings
    /// toggle (see the property's doc) since the engine can't read
    /// `@AppStorage` itself.
    public var isGameOver: Bool {
        if state.manuallyFinished { return true }
        guard roundManagementOn, let roundCount else { return false }
        return Set(0..<roundCount).isSubset(of: state.roundsCrossed)
    }

    /// Manual finish is available any time the game isn't already over —
    /// mirrors `QwixxGame.canFinishManually`.
    public var canFinishManually: Bool { !isGameOver }

    /// End the game now, independent of round completion (issue #57). This is
    /// a real game-ending move (unlike the bookkeeping `toggleRound`), but it
    /// has no meaningful inverse to `undo()` back onto the LIFO stack — like
    /// Qwixx's `finishGame()`, it is not pushed to `history`.
    public func finishGame() {
        guard canFinishManually else { return }
        state.manuallyFinished = true
        save()
    }

    public var canUndo: Bool { undoAvailable }

    // MARK: - Tap-to-undo helpers
    //
    // The most-recent action is the only tap-undoable one (undo is strictly
    // LIFO). Views ring that cell and route its tap to `undo()`. Note: bonuses
    // that auto-apply extra marks push further actions, so only the *final*
    // resulting mark is tap-undoable — consistent with the undo button.

    public func isLastYellow(_ index: Int) -> Bool {
        if case let .yellow(i) = state.history.last { return i == index }
        return false
    }

    public func isLastBlue(_ value: Int) -> Bool {
        if case let .blue(v) = state.history.last { return v == value }
        return false
    }

    /// The green column index (0-based) that the most recent green mark filled,
    /// or `nil` if the last action wasn't a green mark.
    public var lastGreenIndex: Int? {
        if case .green = state.history.last { return state.greenCount - 1 }
        return nil
    }

    public func isLastOrange(_ index: Int) -> Bool {
        if case let .orange(i, _) = state.history.last { return i == index }
        return false
    }

    public func isLastPurple(_ index: Int) -> Bool {
        if case let .purple(i, _) = state.history.last { return i == index }
        return false
    }

    public func undo() { if performUndo() { save() } }

    public var canRedo: Bool { redoAvailable }

    /// Re-apply the most recently undone action by replaying its RAW state
    /// mutation only — the exact inverse of `undo()`'s reversal for that case.
    /// This deliberately does NOT call the public mutators (`markYellow`,
    /// `fillOrange`, etc.): those funnel through `applyNewlyEarned`, which
    /// auto-marks further cells whenever a row/column/cell completes (e.g. a
    /// finished yellow row auto-crosses a bonus box). Each auto-mark is its own
    /// leaf `history` entry that `undo()` unwinds one leaf at a time, so
    /// replaying through the mutator here would re-trigger `applyNewlyEarned`
    /// and double-chain bonuses that are already sitting on the card. Pushing
    /// the raw mutation back—and re-appending the exact same leaf action to
    /// `state.history`—restores precisely the state `undo()` took away.
    public func redo() { if performRedo() { save() } }

    // MARK: - CleverUndoRedo (raw per-action mutations)

    /// Undo the raw mutation for `action` (called by `performUndo`).
    func reverse(_ action: CleverAction) {
        switch action {
        case let .yellow(i): state.yellowCrossed.remove(i)
        case let .blue(v): state.blueCrossed.remove(v)
        case .green: state.greenCount = max(0, state.greenCount - 1)
        case let .orange(i, _): state.orange[i] = nil
        case let .purple(i, _): state.purple[i] = nil
        case let .reroll(s): state.rerollUsed.remove(s)
        case let .extraDie(s): state.extraDieUsed.remove(s)
        }
    }

    /// Re-apply the raw mutation for `action` (called by `performRedo`). Raw
    /// mutation only — never the public mutators — so already-applied bonus
    /// chains are not re-fired.
    func replay(_ action: CleverAction) {
        switch action {
        case let .yellow(i): state.yellowCrossed.insert(i)
        case let .blue(v): state.blueCrossed.insert(v)
        case .green: state.greenCount += 1
        case let .orange(i, value): state.orange[i] = value
        case let .purple(i, value): state.purple[i] = value
        case let .reroll(s): state.rerollUsed.insert(s)
        case let .extraDie(s): state.extraDieUsed.insert(s)
        }
    }

    /// Resets to a fresh `CleverState()`, which zeroes every field including
    /// `manuallyFinished` — a finished game's flag never survives "New game".
    public func reset() {
        state = CleverState()
        earnedBonuses.removeAll()
        pendingRoundSummary = nil
        redoStack = []
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: persistenceKey),
            let restored = try? JSONDecoder().decode(CleverState.self, from: data)
        else { return }
        state = restored
    }
}
