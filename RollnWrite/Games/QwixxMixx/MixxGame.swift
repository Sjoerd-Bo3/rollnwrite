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
        s.history.append(.mark(row: rowIndex, index: index, didLock: didLock))
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
        s.history.append(.penalty)
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

    /// Ends when two rows are locked, or the 4th penalty is taken.
    public var isGameOver: Bool {
        lockedRowCount >= 2 || state.penalties >= MixxState.maxPenalties
    }

    public var canUndo: Bool { !state.history.isEmpty }

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
        }
        state = s
        save()
    }

    /// Clears only the currently selected board.
    public func reset() {
        state = MixxState()
        save()
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
