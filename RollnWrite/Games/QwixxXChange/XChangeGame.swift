//
//  XChangeGame.swift
//  RollnWrite – Qwixx X-Change
//
//  The Qwixx "X-Change" engine: holds state, enforces the rules, and computes the
//  score through an injected `ScoringStrategy`.
//
//  SOLID notes:
//  - SRP: owns rules + state transitions only; scoring math is delegated
//         (`ScoringStrategy`), presentation lives in the view.
//  - DIP: the scoring strategy is injected (classic Qwixx cap 12).
//  - LSP: conforms to the generic `Scoreboard` protocol used by host UI.
//
//  The colour-row rules are identical to classic Qwixx; the X-Change row is the
//  variant-specific addition. The X-Change row is a swap tool and contributes no
//  points (see XChangeModels.swift / QwixxXChangeGame.swift for the rationale).
//

import SwiftUI

@MainActor
public final class XChangeGame: ObservableObject, Scoreboard {

    @Published public private(set) var state = XChangeState()

    private let scoring: ScoringStrategy
    private let persistenceKey: String

    /// Classic Qwixx scoring: up to 12 valued crosses per colour (78 points).
    public init(
        scoring: ScoringStrategy = TriangularScoring(cap: 12),
        persistenceKey: String = "rollnwrite.qwixx.xchange.state"
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

    public var xchange: XChangeRow { state.xchange }

    public var penalties: Int { state.penalties }

    public var lockedRowCount: Int {
        GameColor.allCases.filter { row(for: $0).locked }.count
    }

    // MARK: - Rule enforcement (colour rows)

    /// Whether crossing `index` in `color` is a legal move right now.
    ///
    /// Enforces: game not over · row not locked · not already marked ·
    /// left-to-right · the right-most number needs ≥5 earlier crosses to lock.
    public func canMarkColor(_ color: GameColor, _ index: Int) -> Bool {
        guard !isGameOver else { return false }
        let r = row(for: color)
        guard !r.locked, !r.marks.contains(index), index > r.maxMarkedIndex else { return false }
        if index == ColorRow.lockIndex {
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
        state.history.append(.color(color, index: index, didLock: didLock))
        save()
    }

    // MARK: - Rule enforcement (X-Change row)

    /// The X-Change row is crossed strictly left → right; a field is legal while
    /// the game is live, the field is not already crossed, and it lies to the
    /// right of every existing cross (skipping is allowed but skipped fields are
    /// then permanently blocked).
    public func canMarkXChange(_ index: Int) -> Bool {
        guard !isGameOver else { return false }
        let row = state.xchange
        guard !row.marks.contains(index), index > row.maxMarkedIndex else { return false }
        return true
    }

    public func markXChange(_ index: Int) {
        guard canMarkXChange(index) else { return }
        state.xchange.marks.insert(index)
        state.history.append(.xchange(index: index))
        save()
    }

    // MARK: - Penalties

    public func canAddPenalty() -> Bool {
        !isGameOver && state.penalties < XChangeState.maxPenalties
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
        if case let .concede(c)? = state.history.last { return c == color }
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

    /// Crosses counted toward a colour's score: its own marks plus the lock.
    public func crosses(for color: GameColor) -> Int {
        row(for: color).scoringCrosses
    }

    public func points(for color: GameColor) -> Int {
        scoring.points(forCrosses: crosses(for: color))
    }

    public var penaltyPoints: Int { state.penalties * 5 }

    /// Total = red + yellow + green + blue − penalties. The X-Change row scores
    /// nothing on its own (it only enables extra colour marks).
    public var totalScore: Int {
        GameColor.allCases.reduce(0) { $0 + points(for: $1) } - penaltyPoints
    }

    /// Ends when two rows are locked, the 4th penalty is taken, or the player
    /// ends it by hand.
    public var isGameOver: Bool {
        state.manuallyFinished || lockedRowCount >= 2 || state.penalties >= XChangeState.maxPenalties
    }

    public var canUndo: Bool { !state.history.isEmpty }

    // MARK: - Tap-to-undo helpers
    //
    // The most-recent action is the only tap-undoable one (undo is strictly
    // LIFO). These let the view ring the last-marked cell and route its tap to
    // `undo()` — see CLAUDE.md → tap-to-undo.

    /// Whether marking `index` in `color` was the most recent action.
    public func isLastColorMark(_ color: GameColor, _ index: Int) -> Bool {
        if case let .color(c, i, _)? = state.history.last { return c == color && i == index }
        return false
    }

    /// Whether crossing X-Change field `index` was the most recent action.
    public func isLastXChangeMark(_ index: Int) -> Bool {
        if case let .xchange(i)? = state.history.last { return i == index }
        return false
    }

    /// Whether the most recent action was taking the last penalty.
    public func isLastPenalty() -> Bool {
        if case .penalty? = state.history.last { return true }
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
        case let .xchange(index):
            state.xchange.marks.remove(index)
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
        state = XChangeState()
        save()
    }

    // MARK: - Mutation helpers

    private func setRow(_ r: ColorRow) {
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
            let restored = try? JSONDecoder().decode(XChangeState.self, from: data)
        else { return }
        state = restored
    }
}
