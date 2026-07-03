//
//  MixxGame.swift
//  RollnWrite – Qwixx Mixx
//
//  The Qwixx "gemixxt" (Mixx) engine: holds the state of BOTH boards (Variant A
//  and Variant B), enforces the per-row rules, and computes the score through an
//  injected `ScoringStrategy`.
//
//  SOLID notes:
//  - SRP: owns rules + state transitions only; scoring math is delegated
//         (`ScoringStrategy`), presentation lives in the view; the printed
//         layout lives in `MixxLayout`.
//  - DIP: the scoring strategy is injected (classic Qwixx cap 12).
//  - LSP: conforms to the generic `Scoreboard` protocol used by host UI.
//
//  Both boards share the classic Qwixx rule set (rows crossed strictly
//  left-to-right; the right-most cell locks the row but only after ≥5 earlier
//  crosses; four −5 penalties; game ends at two locks or the 4th penalty). They
//  differ only in their printed cell layout, so one engine serves both. The two
//  boards keep independent state and persist under separate keys, and `undo`,
//  `reset` and the score apply to the *currently selected* board.
//

import SwiftUI

@MainActor
public final class MixxGame: ObservableObject, Scoreboard {

    /// The board currently shown / acted upon.
    @Published public var board: MixxBoard {
        didSet { saveBoardSelection() }
    }

    @Published private var stateA = MixxState()
    @Published private var stateB = MixxState()

    /// Actions undone via `undo()`, most-recently-undone last, so `redo()` can
    /// re-apply them in LIFO order — one stack per board, mirroring `stateA`/
    /// `stateB`, since undo/redo/reset apply to the *currently selected* board.
    /// Deliberately NOT persisted (`MixxState` / `Codable` is untouched) and
    /// NOT part of either state — redo is an in-memory, per-session
    /// convenience, like most editors. Any new forward move (via
    /// `recordAction`) clears the current board's stack.
    private var redoStackA: [MixxAction] = []
    private var redoStackB: [MixxAction] = []

    /// Redo stack of the board currently in play — mirrors `state`.
    private var redoStack: [MixxAction] {
        get { board == .variantA ? redoStackA : redoStackB }
        set {
            if board == .variantA { redoStackA = newValue } else { redoStackB = newValue }
        }
    }

    private let scoring: ScoringStrategy
    private let persistencePrefix: String

    /// Classic Qwixx scoring: up to 12 valued crosses per row (78 points).
    public init(
        scoring: ScoringStrategy = TriangularScoring(cap: 12),
        persistencePrefix: String = "rollnwrite.qwixx.mixx"
    ) {
        self.scoring = scoring
        self.persistencePrefix = persistencePrefix
        self.board = .variantA
        load()
    }

    // MARK: - Current board state

    /// State of the board currently in play.
    private var state: MixxState {
        get { board == .variantA ? stateA : stateB }
        set {
            if board == .variantA { stateA = newValue } else { stateB = newValue }
        }
    }

    /// The printed layout of the current board.
    public var layout: [MixxRowLayout] { MixxLayout.rows(for: board) }

    // MARK: - Accessors

    public func rowState(_ rowIndex: Int) -> MixxRow {
        state.rows[rowIndex]
    }

    public func rowLayout(_ rowIndex: Int) -> MixxRowLayout {
        layout[rowIndex]
    }

    public var penalties: Int { state.penalties }

    public var lockedRowCount: Int {
        state.rows.filter { $0.locked }.count
    }

    // MARK: - Rule enforcement

    /// Whether crossing `index` in row `rowIndex` is a legal move right now.
    ///
    /// Enforces: game not over · row not locked · cell not already marked ·
    /// left-to-right · the right-most cell needs ≥5 earlier crosses to lock.
    public func canMark(_ rowIndex: Int, _ index: Int) -> Bool {
        guard !isGameOver else { return false }
        let r = state.rows[rowIndex]
        guard !r.locked, !r.marks.contains(index), index > r.maxMarkedIndex else { return false }
        if index == MixxRow.lockIndex {
            return r.marks.count >= 5
        }
        return true
    }

    public func mark(_ rowIndex: Int, _ index: Int) {
        guard canMark(rowIndex, index) else { return }
        var r = state.rows[rowIndex]
        r.marks.insert(index)
        var didLock = false
        if index == MixxRow.lockIndex {
            r.locked = true
            didLock = true
        }
        var s = state
        s.rows[rowIndex] = r
        recordAction(&s, .mark(row: rowIndex, index: index, didLock: didLock))
        state = s
        save()
    }

    // MARK: - Penalties

    public func canAddPenalty() -> Bool {
        !isGameOver && state.penalties < MixxState.maxPenalties
    }

    public func addPenalty() {
        guard canAddPenalty() else { return }
        var s = state
        s.penalties += 1
        recordAction(&s, .penalty)
        state = s
        save()
    }

    // MARK: - Concede a colour / finish manually

    /// You may close (concede) a row whose colour another player locked: the row
    /// closes for you, but you score no lock bonus — you never crossed its final
    /// cell. Allowed on any still-open row while the game is live.
    public func canConcedeRow(_ rowIndex: Int) -> Bool {
        !isGameOver && !state.rows[rowIndex].locked
    }

    public func concedeRow(_ rowIndex: Int) {
        guard canConcedeRow(rowIndex) else { return }
        var s = state
        s.rows[rowIndex].locked = true
        recordAction(&s, .concede(row: rowIndex))
        state = s
        save()
    }

    public func isLastConcede(_ rowIndex: Int) -> Bool {
        if case let .concede(r) = state.history.last { return r == rowIndex }
        return false
    }

    /// End the game by hand — e.g. another player crossed the final lock.
    public var canFinishManually: Bool { !isGameOver }

    public func finishGame() {
        guard canFinishManually else { return }
        var s = state
        s.manuallyFinished = true
        recordAction(&s, .finish)
        state = s
        save()
    }

    // MARK: - Scoreboard

    /// Crosses counted toward a row's score: its own marks plus the lock.
    public func crosses(_ rowIndex: Int) -> Int {
        state.rows[rowIndex].scoringCrosses
    }

    public func points(_ rowIndex: Int) -> Int {
        scoring.points(forCrosses: crosses(rowIndex))
    }

    public var penaltyPoints: Int { state.penalties * 5 }

    public var totalScore: Int {
        (0..<state.rows.count).reduce(0) { $0 + points($1) } - penaltyPoints
    }

    /// Ends when two rows are locked, the 4th penalty is taken, or the player
    /// ends it by hand.
    public var isGameOver: Bool {
        state.manuallyFinished || lockedRowCount >= 2 || state.penalties >= MixxState.maxPenalties
    }

    public var canUndo: Bool { !state.history.isEmpty }

    // MARK: - Tap-to-undo (strictly LIFO: only the most-recent action qualifies)

    /// `true` if the most-recent action is crossing `index` in row `rowIndex`,
    /// so tapping that cell un-checks it (a second way to undo).
    public func isLastMark(_ rowIndex: Int, _ index: Int) -> Bool {
        if case let .mark(r, i, _) = state.history.last { return r == rowIndex && i == index }
        return false
    }

    /// `true` if the most-recent action is the last penalty, so tapping it undoes it.
    public func isLastPenalty() -> Bool {
        if case .penalty = state.history.last { return true }
        return false
    }

    /// Reverse the most recent action on the current board. Strictly LIFO.
    public func undo() {
        var s = state
        guard let last = s.history.popLast() else { return }
        switch last {
        case let .mark(rowIndex, index, didLock):
            var r = s.rows[rowIndex]
            r.marks.remove(index)
            if didLock { r.locked = false }
            s.rows[rowIndex] = r
        case .penalty:
            s.penalties = max(0, s.penalties - 1)
        case let .concede(rowIndex):
            s.rows[rowIndex].locked = false
        case .finish:
            s.manuallyFinished = false
        }
        state = s
        redoStack.append(last)
        save()
    }

    public var canRedo: Bool { !redoStack.isEmpty }

    /// `true` while `redo()` is re-applying an action through its original
    /// mutator, so `recordAction` (called by that mutator) knows NOT to treat
    /// it as a fresh move and clear the rest of the current board's redo stack.
    private var isRedoing = false

    /// Re-apply the most recently undone action (on the current board) through
    /// the SAME mutator a fresh move takes, so scores/locks/derived state stay
    /// exact — never re-implement the effect here.
    public func redo() {
        guard let next = redoStack.popLast() else { return }
        isRedoing = true
        switch next {
        case let .mark(rowIndex, index, _):
            mark(rowIndex, index)
        case .penalty:
            addPenalty()
        case let .concede(rowIndex):
            concedeRow(rowIndex)
        case .finish:
            finishGame()
        }
        isRedoing = false
    }

    /// Clears only the currently selected board.
    public func reset() {
        state = MixxState()
        redoStack = []
        save()
    }

    // MARK: - Mutation helpers

    /// Appends a new action to `s`'s history. Any FORWARD move — i.e. every
    /// call site except `redo()` re-applying an undone one — invalidates the
    /// current board's redo stack (standard editor semantics: making a new
    /// move after undoing forecloses the redone future).
    private func recordAction(_ s: inout MixxState, _ action: MixxAction) {
        s.history.append(action)
        if !isRedoing { redoStack = [] }
    }

    // MARK: - Persistence

    private func stateKey(_ b: MixxBoard) -> String {
        "\(persistencePrefix).\(b.rawValue).state"
    }

    private var boardSelectionKey: String { "\(persistencePrefix).board" }

    private func save() {
        let key = stateKey(board)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func saveBoardSelection() {
        UserDefaults.standard.set(board.rawValue, forKey: boardSelectionKey)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: stateKey(.variantA)),
           let restored = try? JSONDecoder().decode(MixxState.self, from: data) {
            stateA = restored
        }
        if let data = UserDefaults.standard.data(forKey: stateKey(.variantB)),
           let restored = try? JSONDecoder().decode(MixxState.self, from: data) {
            stateB = restored
        }
        if let raw = UserDefaults.standard.string(forKey: boardSelectionKey),
           let restored = MixxBoard(rawValue: raw) {
            board = restored
        }
    }
}
