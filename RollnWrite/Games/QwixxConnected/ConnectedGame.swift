//
//  ConnectedGame.swift
//  RollnWrite – Qwixx Connected
//
//  The Qwixx "Connected" (The Chain) engine: holds state, enforces the rules,
//  and computes the score through an injected `ScoringStrategy`.
//
//  SOLID notes:
//  - SRP: owns rules + state transitions only; scoring math is delegated
//         (`ScoringStrategy`), presentation lives in the view.
//  - DIP: the scoring strategy is injected (classic Qwixx cap 12).
//  - LSP: conforms to the generic `Scoreboard` protocol used by host UI.
//
//  The colour-row rules are identical to classic Qwixx; the printed *chains* are
//  the variant-specific addition. Crossing one circled chain space automatically
//  crosses its partner space, ignoring the normal left-to-right rule and applying
//  even when the partner row is already locked. The four colour rows are scored
//  unchanged — the auto-crossed partner just counts as one more cross in its row.
//

import SwiftUI

@MainActor
public final class ConnectedGame: ObservableObject, Scoreboard {

    @Published public private(set) var state = ConnectedState()

    private let scoring: ScoringStrategy
    private let persistenceKey: String

    /// Classic Qwixx scoring: up to 12 valued crosses per colour (78 points).
    public init(
        scoring: ScoringStrategy = TriangularScoring(cap: 12),
        persistenceKey: String = "rollnwrite.qwixx.connected.state"
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

    public var penalties: Int { state.penalties }

    public var lockedRowCount: Int {
        GameColor.allCases.filter { row(for: $0).locked }.count
    }

    /// Whether the cell at `(color, index)` is a circled chain space.
    public func isChainSpace(_ color: GameColor, _ index: Int) -> Bool {
        ConnectedLayout.isChainSpace(color, index)
    }

    /// The partner of a chain space, for drawing the connecting link.
    public func chainPartner(_ color: GameColor, _ index: Int) -> ChainEnd? {
        ConnectedLayout.partner(of: color, index)
    }

    /// Whether `(color, index)` is currently crossed in its row.
    public func isMarked(_ color: GameColor, _ index: Int) -> Bool {
        row(for: color).marks.contains(index)
    }

    // MARK: - Rule enforcement (colour rows)

    /// Whether crossing `index` in `color` is a legal *deliberate* move now.
    ///
    /// Enforces: game not over · row not locked · not already marked ·
    /// left-to-right · the right-most number needs ≥5 earlier crosses to lock.
    /// (Automatic partner crosses are NOT gated by this — see `markColor`.)
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

        // Automatic chain co-mark: crossing a circled space forces its partner.
        // This ignores the normal rules and applies even to a locked row. It is
        // recorded only if it was a *new* mark, so undo restores exactly.
        var auto: ChainEnd? = nil
        if let partner = ConnectedLayout.partner(of: color, index) {
            var pr = row(for: partner.color)
            if !pr.marks.contains(partner.index) {
                pr.marks.insert(partner.index)
                // A forced co-mark never locks a row, even on the right-most cell.
                setRow(pr)
                auto = partner
            }
        }

        state.history.append(.color(color, index: index, didLock: didLock, auto: auto))
        save()
    }

    // MARK: - Penalties

    public func canAddPenalty() -> Bool {
        !isGameOver && state.penalties < ConnectedState.maxPenalties
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

    /// Crosses counted toward a colour's score: its own marks plus the lock.
    /// Automatically chained marks live in `marks` and so are already included.
    public func crosses(for color: GameColor) -> Int {
        row(for: color).scoringCrosses
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
        state.manuallyFinished || lockedRowCount >= 2 || state.penalties >= ConnectedState.maxPenalties
    }

    public var canUndo: Bool { !state.history.isEmpty }

    // MARK: - Tap-to-undo
    //
    // Tapping your most-recent mark un-checks it. Undo is strictly LIFO, so only
    // the *last* action is reversible this way. A deliberate chain cross and its
    // forced partner co-mark are ONE action, so only the deliberately-crossed
    // cell is tap-undoable; tapping it reverses both crosses together.

    public func isLastColorMark(_ color: GameColor, _ index: Int) -> Bool {
        if case let .color(c, i, _, _) = state.history.last { return c == color && i == index }
        return false
    }

    public func isLastPenalty() -> Bool {
        if case .penalty = state.history.last { return true }
        return false
    }

    /// Reverse the most recent action. Strictly LIFO so an automatic partner
    /// cross is always undone together with the deliberate mark that caused it.
    public func undo() {
        guard let last = state.history.popLast() else { return }
        switch last {
        case let .color(color, index, didLock, auto):
            var r = row(for: color)
            r.marks.remove(index)
            if didLock { r.locked = false }
            setRow(r)
            if let auto {
                var pr = row(for: auto.color)
                pr.marks.remove(auto.index)
                setRow(pr)
            }
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
        state = ConnectedState()
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
            let restored = try? JSONDecoder().decode(ConnectedState.self, from: data)
        else { return }
        state = restored
    }
}
