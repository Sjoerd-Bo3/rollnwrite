//
//  BonusGame.swift
//  RollnWrite – Qwixx Bonus
//
//  The Qwixx "Bonus" (version A) engine: holds state, enforces the rules, and
//  computes the score through an injected `ScoringStrategy`.
//
//  SOLID notes:
//  - SRP: owns rules + state transitions only; scoring math is delegated
//         (`ScoringStrategy`), presentation lives in the view.
//  - DIP: the scoring strategy is injected (classic Qwixx cap 12).
//  - LSP: conforms to the generic `Scoreboard` protocol used by host UI.
//
//  The colour-row rules are identical to classic Qwixx. The variant-specific
//  twist is the bonus bar: crossing a boxed number automatically earns the next
//  free bar field, whose colour tells the player which free extra cross to make.
//  When a colour is completed (self-lock or concede) its remaining bar fields
//  are forfeited at once and skipped from then on (official forfeit rule).
//  The bar awards no points itself (version A scores like classic Qwixx).
//

import SwiftUI

@MainActor
public final class BonusGame: ObservableObject, Scoreboard {

    @Published public private(set) var state = BonusState()

    private let scoring: ScoringStrategy
    private let persistenceKey: String

    /// Classic Qwixx scoring: up to 12 valued crosses per colour (78 points).
    public init(
        scoring: ScoringStrategy = TriangularScoring(cap: 12),
        persistenceKey: String = "rollnwrite.qwixx.bonus.state"
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

    public var bar: BonusBar { state.bar }

    public var penalties: Int { state.penalties }

    public var lockedRowCount: Int {
        GameColor.allCases.filter { row(for: $0).locked }.count
    }

    /// Whether the cell at `index` of `color` is a boxed bonus number.
    public func isBoxed(_ color: GameColor, _ index: Int) -> Bool {
        BonusLayout.isBoxedIndex(color, index: index)
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

        // Boxed numbers earn the next bar field: the lowest-index field that is
        // neither earned nor forfeited (forfeited fields are simply skipped).
        // The field's colour drives the reward, so record exactly which one.
        var barAdvance = BarAdvance.none
        if isBoxed(color, index), let field = state.bar.nextEarnableIndex {
            state.bar.earned.insert(field)
            barAdvance = .earned(field)
        }

        // Official rule: once a colour is completed, its remaining bonus-bar
        // fields are immediately crossed out as forfeited — same action.
        var forfeited: [Int] = []
        if didLock {
            forfeited = forfeitBarFields(for: color)
        }

        state.history.append(.color(color, index: index, didLock: didLock,
                                     bar: barAdvance, forfeited: forfeited))
        save()
    }

    // MARK: - Penalties

    public func canAddPenalty() -> Bool {
        !isGameOver && state.penalties < BonusState.maxPenalties
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
        // A conceded colour is completed too, so its remaining bonus-bar fields
        // are forfeited immediately — same as a self-lock.
        let forfeited = forfeitBarFields(for: color)
        state.history.append(.concede(color, forfeited: forfeited))
        save()
    }

    /// Official forfeit rule: cross out every still-unearned bonus-bar field of
    /// a just-completed `color`. Those fields no longer count and are skipped by
    /// future earned crosses. Returns the forfeited indices for exact undo.
    private func forfeitBarFields(for color: GameColor) -> [Int] {
        let indices = BonusLayout.barColors.indices.filter {
            BonusLayout.barColors[$0] == color
                && !state.bar.earned.contains($0)
                && !state.bar.forfeited.contains($0)
        }
        state.bar.forfeited.formUnion(indices)
        return indices
    }

    public func isLastConcede(_ color: GameColor) -> Bool {
        if case let .concede(c, _) = state.history.last { return c == color }
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

    public var totalScore: Int {
        GameColor.allCases.reduce(0) { $0 + points(for: $1) } - penaltyPoints
    }

    /// Ends when two rows are locked, the 4th penalty is taken, or the player
    /// ends it by hand.
    public var isGameOver: Bool {
        state.manuallyFinished || lockedRowCount >= 2 || state.penalties >= BonusState.maxPenalties
    }

    public var canUndo: Bool { !state.history.isEmpty }

    // Tap-to-undo helpers: only the most-recent action is reversible by tapping,
    // so these tell the view which single cell (or penalty box) wears the ring.

    /// Whether the most-recent action was crossing `index` of `color`.
    public func isLastColorMark(_ color: GameColor, _ index: Int) -> Bool {
        if case let .color(c, i, _, _, _) = state.history.last { return c == color && i == index }
        return false
    }

    /// Whether the most-recent action was a penalty.
    public func isLastPenalty() -> Bool {
        if case .penalty = state.history.last { return true }
        return false
    }

    /// Reverse the most recent action. Strictly LIFO.
    public func undo() {
        guard let last = state.history.popLast() else { return }
        switch last {
        case let .color(color, index, didLock, bar, forfeited):
            var r = row(for: color)
            r.marks.remove(index)
            if didLock { r.locked = false }
            setRow(r)
            switch bar {
            case .none:
                break
            case let .earned(field):
                state.bar.earned.remove(field)
            case .legacy:
                // Pre-forfeit saves filled the bar strictly left to right, so
                // the newest cross is the highest earned index.
                if let top = state.bar.earned.max() { state.bar.earned.remove(top) }
            }
            state.bar.forfeited.subtract(forfeited)
        case .penalty:
            state.penalties = max(0, state.penalties - 1)
        case let .concede(color, forfeited):
            var r = row(for: color)
            r.locked = false
            setRow(r)
            state.bar.forfeited.subtract(forfeited)
        case .finish:
            state.manuallyFinished = false
        }
        save()
    }

    public func reset() {
        state = BonusState()
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
            let restored = try? JSONDecoder().decode(BonusState.self, from: data)
        else { return }
        state = restored
    }
}
