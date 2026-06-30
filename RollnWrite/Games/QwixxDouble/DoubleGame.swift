//
//  DoubleGame.swift
//  RollnWrite – Qwixx Double
//
//  The Qwixx "Double" (Variant A) engine: holds state, enforces the rules, and
//  computes the score through an injected `ScoringStrategy`.
//
//  SOLID notes:
//  - SRP: owns rules + state transitions only; scoring math is delegated
//         (`ScoringStrategy`), presentation lives in the view.
//  - DIP: the scoring strategy is injected — Qwixx Double caps at 16 valued
//         crosses (136 points).
//  - LSP: conforms to the generic `Scoreboard` protocol used by host UI.
//
//  The variant-specific additions over classic Qwixx are: a second cross on the
//  most-recently crossed space, and a 7-cross (not 5) threshold before a row may
//  be locked.
//

import SwiftUI

@MainActor
public final class DoubleGame: ObservableObject, Scoreboard {

    @Published public private(set) var state = DoubleState()

    private let scoring: ScoringStrategy
    private let persistenceKey: String

    /// Qwixx Double scoring: up to 16 valued crosses per colour (136 points).
    public init(
        scoring: ScoringStrategy = TriangularScoring(cap: DoubleGame.scoringCap),
        persistenceKey: String = "rollnwrite.qwixx.double.state"
    ) {
        self.scoring = scoring
        self.persistenceKey = persistenceKey
        load()
    }

    /// Maximum valued crosses scored per row (16 → 136 points).
    public static let scoringCap = 16

    // MARK: - Accessors

    public func row(for color: GameColor) -> DoubleColorRow {
        switch color {
        case .red:    return state.red
        case .yellow: return state.yellow
        case .green:  return state.green
        case .blue:   return state.blue
        }
    }

    public var penalties: Int { state.penalties }

    public var lockedRowCount: Int {
        GameColor.allCases.filter { row(for: $0).locked }.count
    }

    // MARK: - Rule enforcement (first crosses)

    /// Whether crossing `index` in `color` for the *first* time is legal now.
    ///
    /// Enforces: game not over · row not locked · not already marked ·
    /// strictly left-to-right · the right-most number needs ≥7 earlier crosses.
    public func canMarkColor(_ color: GameColor, _ index: Int) -> Bool {
        guard !isGameOver else { return false }
        let r = row(for: color)
        guard !r.locked, !r.marks.contains(index), index > r.maxMarkedIndex else { return false }
        if index == DoubleColorRow.lockIndex {
            return r.crossCount >= DoubleColorRow.crossesToLock
        }
        return true
    }

    public func markColor(_ color: GameColor, _ index: Int) {
        guard canMarkColor(color, index) else { return }
        var r = row(for: color)
        r.marks.insert(index)
        var didLock = false
        if index == DoubleColorRow.lockIndex {
            r.locked = true
            didLock = true
        }
        setRow(r)
        state.history.append(.mark(color, index: index, didLock: didLock))
        save()
    }

    // MARK: - Rule enforcement (second / double crosses)

    /// Whether a *second* cross on `index` is legal now.
    ///
    /// Only the **most recently crossed** space may be doubled, it must not be
    /// already doubled, the lock space is never doubled, and the game must be
    /// live.
    public func canDoubleColor(_ color: GameColor, _ index: Int) -> Bool {
        guard !isGameOver else { return false }
        let r = row(for: color)
        guard !r.locked else { return false }
        guard r.marks.contains(index), !r.doubles.contains(index) else { return false }
        guard index == r.maxMarkedIndex else { return false }         // most-recent only
        guard index != DoubleColorRow.lockIndex else { return false } // lock isn't doubled
        return true
    }

    public func doubleColor(_ color: GameColor, _ index: Int) {
        guard canDoubleColor(color, index) else { return }
        var r = row(for: color)
        r.doubles.insert(index)
        setRow(r)
        state.history.append(.double(color, index: index))
        save()
    }

    // MARK: - Penalties

    public func canAddPenalty() -> Bool {
        !isGameOver && state.penalties < DoubleState.maxPenalties
    }

    public func addPenalty() {
        guard canAddPenalty() else { return }
        state.penalties += 1
        state.history.append(.penalty)
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
        state.history.append(.concede(color))
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
        state.history.append(.finish)
        save()
    }

    // MARK: - Scoreboard

    /// Crosses counted toward a colour's score: first crosses + second crosses +
    /// the lock bonus cross (before the scoring cap is applied).
    public func crosses(for color: GameColor) -> Int {
        row(for: color).crossCount
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
        state.manuallyFinished || lockedRowCount >= 2 || state.penalties >= DoubleState.maxPenalties
    }

    public var canUndo: Bool { !state.history.isEmpty }

    // MARK: - Tap-to-undo helpers
    //
    // These report whether a given mark is the single most-recent action, so the
    // view can ring it and let a tap un-check it (LIFO undo). Only the very last
    // action is tap-undoable.

    /// Whether the most recent action was a *first* cross on `index` in `color`.
    public func isLastColorMark(_ color: GameColor, _ index: Int) -> Bool {
        if case let .mark(c, i, _) = state.history.last { return c == color && i == index }
        return false
    }

    /// Whether the most recent action was a *second* cross on `index` in `color`.
    public func isLastDoubleMark(_ color: GameColor, _ index: Int) -> Bool {
        if case let .double(c, i) = state.history.last { return c == color && i == index }
        return false
    }

    /// Whether the most recent action was taking a penalty.
    public func isLastPenalty() -> Bool {
        if case .penalty = state.history.last { return true }
        return false
    }

    /// Reverse the most recent action. Strictly LIFO, which guarantees a second
    /// cross is always undone before the first cross that authorised it.
    public func undo() {
        guard let last = state.history.popLast() else { return }
        switch last {
        case let .mark(color, index, didLock):
            var r = row(for: color)
            r.marks.remove(index)
            r.doubles.remove(index)
            if didLock { r.locked = false }
            setRow(r)
        case let .double(color, index):
            var r = row(for: color)
            r.doubles.remove(index)
            setRow(r)
        case .penalty:
            state.penalties = max(0, state.penalties - 1)
        case let .concede(color):
            var r = row(for: color)
            r.locked = false
            setRow(r)
        case .finish:
            state.manuallyFinished = false
        }
        save()
    }

    public func reset() {
        state = DoubleState()
        save()
    }

    // MARK: - Mutation helpers

    private func setRow(_ r: DoubleColorRow) {
        switch r.color {
        case .red:    state.red = r
        case .yellow: state.yellow = r
        case .green:  state.green = r
        case .blue:   state.blue = r
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
            let restored = try? JSONDecoder().decode(DoubleState.self, from: data)
        else { return }
        state = restored
    }
}
