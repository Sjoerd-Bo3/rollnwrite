//
//  Connect15Game.swift
//  RollnWrite – Qwixx Connect15
//
//  The Qwixx "Connect 15" engine: holds state, enforces the rules, and computes
//  the score through an injected `ScoringStrategy`.
//
//  SOLID notes:
//  - SRP: owns rules + state transitions only; scoring math is delegated
//         (`ScoringStrategy`), presentation lives in the view.
//  - DIP: the scoring strategy is injected (Connect 15 cap 15 → up to 120).
//  - LSP: conforms to the generic `Scoreboard` protocol used by host UI.
//
//  The colour-row rules are classic Qwixx; the variant twist is that each row's
//  three connection fields join the row's ONE left-to-right sequence. Legality
//  of every mark — number or connection field — is "its interleaved position is
//  right of the row's highest marked position" (`Connect15Layout` positions:
//  number → 2·column, connection field → 2·column + 1). Skipped spaces of
//  either kind are forfeited implicitly. Crossed connection fields count as
//  extra crosses toward the row's total (raising the cap from 12 to 15).
//

import SwiftUI

@MainActor
public final class Connect15Game: ObservableObject, Scoreboard {

    @Published public private(set) var state = Connect15State()

    /// Actions undone via `undo()`, most-recently-undone last, so `redo()` can
    /// re-apply them in LIFO order. Deliberately NOT persisted
    /// (`Connect15State` / `Codable` is untouched) and NOT part of `state` —
    /// redo is an in-memory, per-session convenience, like most editors. Any
    /// new forward move (via `recordAction`) clears it, matching standard
    /// undo/redo semantics.
    private var redoStack: [Connect15Action] = []

    private let scoring: ScoringStrategy
    private let persistenceKey: String

    /// Connect 15 scoring: up to 15 valued crosses per colour (120 points), the
    /// 12 base crosses (11 numbers + lock) plus up to 3 connection fields.
    public init(
        scoring: ScoringStrategy = TriangularScoring(cap: 15),
        persistenceKey: String = "rollnwrite.qwixx.connect15.state"
    ) {
        self.scoring = scoring
        self.persistenceKey = persistenceKey
        load()
    }

    // MARK: - Accessors

    public func row(for color: GameColor) -> ColorRow {
        switch color {
        case .red:    return state.red
        case .yellow: return state.yellow
        case .green:  return state.green
        case .blue:   return state.blue
        }
    }

    public func connections(for color: GameColor) -> ConnectionFields {
        switch color {
        case .red:    return state.redConnections
        case .yellow: return state.yellowConnections
        case .green:  return state.greenConnections
        case .blue:   return state.blueConnections
        }
    }

    public var penalties: Int { state.penalties }

    public var lockedRowCount: Int {
        GameColor.allCases.filter { row(for: $0).locked }.count
    }

    // MARK: - The interleaved left-to-right rule

    /// The row's highest marked interleaved position — numbers AND connection
    /// fields combined (`Connect15Layout` doubled positions), or -1 if the row
    /// is empty. Any new mark must sit strictly right of this.
    public func maxMarkedPosition(_ color: GameColor) -> Int {
        let numberMax = row(for: color).marks
            .map { Connect15Layout.numberPosition(column: $0) }
            .max() ?? -1
        let columns = Connect15Layout.columns(for: color)
        let fieldMax = connections(for: color).marks
            .compactMap { field in
                field < columns.count
                    ? Connect15Layout.connectionPosition(afterColumn: columns[field])
                    : nil
            }
            .max() ?? -1
        return max(numberMax, fieldMax)
    }

    // MARK: - Rule enforcement (colour rows)

    /// Whether crossing number `index` in `color` is a legal move right now.
    ///
    /// Enforces: game not over · row not locked · strictly right of the row's
    /// highest marked position (numbers and connection fields form one
    /// left-to-right sequence, so this also rejects already-marked numbers and
    /// implicitly forfeits skipped connection fields) · the right-most number
    /// needs ≥5 earlier number crosses to lock.
    public func canMarkColor(_ color: GameColor, _ index: Int) -> Bool {
        guard !isGameOver else { return false }
        let r = row(for: color)
        guard !r.locked,
              Connect15Layout.numberPosition(column: index) > maxMarkedPosition(color)
        else { return false }
        if index == ColorRow.lockIndex {
            // Confirmed by the game's owner against the paper rules: locking
            // needs at least 5 crossed NUMBERS in the row — connection fields
            // do not count toward the five ("just count normally").
            return r.marks.count >= 5
        }
        return true
    }

    public func markColor(_ color: GameColor, _ index: Int) {
        guard canMarkColor(color, index) else { return }
        var r = row(for: color)
        r.marks.insert(index)
        var didLock = false
        if index == ColorRow.lockIndex {
            r.locked = true
            didLock = true
        }
        setRow(r)
        recordAction(.color(color, index: index, didLock: didLock))
        save()
    }

    // MARK: - Rule enforcement (connection fields)

    /// Whether crossing connection field `field` (0-based ordinal, left → right)
    /// of `color` is legal: game live, row not locked (locking or conceding a
    /// row closes its remaining connection fields), field not already marked,
    /// and its interleaved position strictly right of the row's highest marked
    /// position — crossing it forfeits every skipped space to its left, and any
    /// field left of an existing mark is itself forfeited.
    public func canMarkConnection(_ color: GameColor, field: Int) -> Bool {
        guard !isGameOver else { return false }
        let columns = Connect15Layout.columns(for: color)
        guard field >= 0, field < columns.count else { return false }
        guard !row(for: color).locked,
              !connections(for: color).marks.contains(field)
        else { return false }
        return Connect15Layout.connectionPosition(afterColumn: columns[field]) > maxMarkedPosition(color)
    }

    public func markConnection(_ color: GameColor, field: Int) {
        guard canMarkConnection(color, field: field) else { return }
        var f = connections(for: color)
        f.marks.insert(field)
        setConnections(f, for: color)
        recordAction(.connection(color, field: field))
        save()
    }

    // MARK: - Penalties

    public func canAddPenalty() -> Bool {
        !isGameOver && state.penalties < Connect15State.maxPenalties
    }

    public func addPenalty() {
        guard canAddPenalty() else { return }
        state.penalties += 1
        recordAction(.penalty)
        save()
    }

    // MARK: - Concede a colour / finish manually

    /// You may close (concede) a colour that another player locked: the row
    /// closes for you, but you score no lock bonus — you never crossed its final
    /// number. Allowed on any still-open row while the game is live.
    public func canConcedeRow(_ color: GameColor) -> Bool {
        !isGameOver && !row(for: color).locked
    }

    public func concedeRow(_ color: GameColor) {
        guard canConcedeRow(color) else { return }
        var r = row(for: color)
        r.locked = true
        setRow(r)
        recordAction(.concede(color))
        save()
    }

    public func isLastConcede(_ color: GameColor) -> Bool {
        if case let .concede(c) = state.history.last { return c == color }
        return false
    }

    /// End the game by hand — e.g. another player crossed the final lock.
    public var canFinishManually: Bool { !isGameOver }

    public func finishGame() {
        guard canFinishManually else { return }
        state.manuallyFinished = true
        recordAction(.finish)
        save()
    }

    // MARK: - Scoreboard

    /// Crosses counted toward a colour's score: its number marks, the lock cross,
    /// plus any crossed connection fields. Capped by the scoring strategy (15).
    public func crosses(for color: GameColor) -> Int {
        row(for: color).scoringCrosses + connections(for: color).marks.count
    }

    public func points(for color: GameColor) -> Int {
        scoring.points(forCrosses: crosses(for: color))
    }

    public var penaltyPoints: Int { state.penalties * 5 }

    public var totalScore: Int {
        GameColor.allCases.reduce(0) { $0 + points(for: $1) } - penaltyPoints
    }

    /// Ends when two rows are locked, the 4th penalty is taken, or the player
    /// ends it by hand.
    public var isGameOver: Bool {
        state.manuallyFinished || lockedRowCount >= 2 || state.penalties >= Connect15State.maxPenalties
    }

    public var canUndo: Bool { !state.history.isEmpty }

    // MARK: - Tap-to-undo helpers
    //
    // Mirror `QwixxGame`: report whether a given mark is the single most-recent
    // action, so the view can ring it and let a tap un-check it (strictly LIFO).

    public func isLastColorMark(_ color: GameColor, _ index: Int) -> Bool {
        if case let .color(c, i, _) = state.history.last { return c == color && i == index }
        return false
    }

    public func isLastConnectionMark(_ color: GameColor, _ field: Int) -> Bool {
        if case let .connection(c, f) = state.history.last { return c == color && f == field }
        return false
    }

    public func isLastPenalty() -> Bool {
        if case .penalty = state.history.last { return true }
        return false
    }

    /// Reverse the most recent action. Strictly LIFO.
    public func undo() {
        guard let last = state.history.popLast() else { return }
        switch last {
        case let .color(color, index, didLock):
            var r = row(for: color)
            r.marks.remove(index)
            if didLock { r.locked = false }
            setRow(r)
        case let .connection(color, field):
            var f = connections(for: color)
            f.marks.remove(field)
            setConnections(f, for: color)
        case .penalty:
            state.penalties = max(0, state.penalties - 1)
        case let .concede(color):
            var r = row(for: color)
            r.locked = false
            setRow(r)
        case .finish:
            state.manuallyFinished = false
        }
        redoStack.append(last)
        save()
    }

    public var canRedo: Bool { !redoStack.isEmpty }

    /// `true` while `redo()` is re-applying an action through its original
    /// mutator, so `recordAction` (called by that mutator) knows NOT to treat
    /// it as a fresh move and clear the rest of the redo stack.
    private var isRedoing = false

    /// Re-apply the most recently undone action through the SAME mutator a
    /// fresh move takes, so scores/locks/derived state stay exact — never
    /// re-implement the effect here.
    public func redo() {
        guard let next = redoStack.popLast() else { return }
        isRedoing = true
        switch next {
        case let .color(color, index, _):
            markColor(color, index)
        case let .connection(color, field):
            markConnection(color, field: field)
        case .penalty:
            addPenalty()
        case let .concede(color):
            concedeRow(color)
        case .finish:
            finishGame()
        }
        isRedoing = false
    }

    public func reset() {
        state = Connect15State()
        redoStack = []
        save()
    }

    // MARK: - Mutation helpers

    /// Appends a new action to the history. Any FORWARD move — i.e. every call
    /// site except `redo()` re-applying an undone one — invalidates the redo
    /// stack (standard editor semantics: making a new move after undoing
    /// forecloses the redone future).
    private func recordAction(_ action: Connect15Action) {
        state.history.append(action)
        if !isRedoing { redoStack = [] }
    }

    private func setRow(_ r: ColorRow) {
        switch r.color {
        case .red:    state.red = r
        case .yellow: state.yellow = r
        case .green:  state.green = r
        case .blue:   state.blue = r
        }
    }

    private func setConnections(_ f: ConnectionFields, for color: GameColor) {
        switch color {
        case .red:    state.redConnections = f
        case .yellow: state.yellowConnections = f
        case .green:  state.greenConnections = f
        case .blue:   state.blueConnections = f
        }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: persistenceKey),
            let restored = try? JSONDecoder().decode(Connect15State.self, from: data)
        else { return }
        state = restored
    }
}
