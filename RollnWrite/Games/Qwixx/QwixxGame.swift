//
//  QwixxGame.swift
//  RollnWrite – Qwixx
//
//  The Qwixx Big Points engine: holds state, enforces the official rules, and
//  computes the score through an injected `ScoringStrategy`.
//
//  SOLID notes:
//  - SRP: this owns *rules + state transitions* only. Scoring math is delegated
//         (`ScoringStrategy`); presentation lives in the views.
//  - DIP: the scoring strategy is injected, so Big Points (cap 15) vs. classic
//         Qwixx (cap 12) differ by construction, not by edits here.
//  - LSP: conforms to the generic `Scoreboard` protocol used by host UI.
//

import SwiftUI

@MainActor
public final class QwixxGame: ObservableObject, Scoreboard {

    @Published public private(set) var state = QwixxState()

    private let scoring: ScoringStrategy
    private let persistenceKey: String

    /// Whether this variant has the two two-colour bonus rows (Big Points) or
    /// not (classic Qwixx). When `false`, bonus marking is disallowed and bonus
    /// crosses never contribute to scoring.
    public let hasBonusRows: Bool

    /// Big Points values up to 15 crosses per colour (120 points).
    public init(
        scoring: ScoringStrategy = TriangularScoring(cap: 15),
        persistenceKey: String = "rollnwrite.qwixx.bigpoints.state",
        hasBonusRows: Bool = true
    ) {
        self.scoring = scoring
        self.persistenceKey = persistenceKey
        self.hasBonusRows = hasBonusRows
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

    public func bonus(_ id: BonusRowID) -> BonusRow {
        id == .redYellow ? state.redYellowBonus : state.greenBlueBonus
    }

    public var penalties: Int { state.penalties }

    public var lockedRowCount: Int {
        GameColor.allCases.filter { row(for: $0).locked }.count
    }

    // MARK: - Rule enforcement (colour rows)

    /// Whether crossing `index` in `color` is a legal move right now.
    ///
    /// Enforces: game not over · row not locked · not already marked ·
    /// left-to-right (no marking left of an existing cross) · the right-most
    /// number requires at least 5 earlier crosses before it can lock the row.
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

    // MARK: - Rule enforcement (bonus rows)

    /// A bonus space is legal when the game is live, it isn't already marked,
    /// left-to-right is respected within the bonus row, and an adjacent
    /// same-number colour space is already crossed (the activation rule).
    public func canMarkBonus(_ id: BonusRowID, _ index: Int) -> Bool {
        guard hasBonusRows, !isGameOver else { return false }
        let b = bonus(id)
        guard !b.marks.contains(index), index > b.maxMarkedIndex else { return false }
        let (a, c) = id.colors
        return row(for: a).marks.contains(index) || row(for: c).marks.contains(index)
    }

    public func markBonus(_ id: BonusRowID, _ index: Int) {
        guard canMarkBonus(id, index) else { return }
        var b = bonus(id)
        b.marks.insert(index)
        setBonus(b)
        state.history.append(.bonus(id, index: index))
        save()
    }

    // MARK: - Penalties

    public func canAddPenalty() -> Bool {
        !isGameOver && state.penalties < QwixxState.maxPenalties
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

    /// Crosses counted toward a colour's score: its own marks, the lock bonus,
    /// and every crossed bonus space adjacent to that colour.
    public func crosses(for color: GameColor) -> Int {
        guard hasBonusRows else { return row(for: color).scoringCrosses }
        let bonusID: BonusRowID = (color == .red || color == .yellow) ? .redYellow : .greenBlue
        return row(for: color).scoringCrosses + bonus(bonusID).marks.count
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
        state.manuallyFinished || lockedRowCount >= 2 || state.penalties >= QwixxState.maxPenalties
    }

    public var canUndo: Bool { !state.history.isEmpty }

    // MARK: - Tap-to-undo
    //
    // Tapping your most-recent mark un-checks it. Undo is strictly LIFO, so only
    // the *last* action is reversible this way — these tell the view which cell
    // that is.

    public func isLastColorMark(_ color: GameColor, _ index: Int) -> Bool {
        if case let .color(c, i, _) = state.history.last { return c == color && i == index }
        return false
    }

    public func isLastBonusMark(_ id: BonusRowID, _ index: Int) -> Bool {
        if case let .bonus(b, i) = state.history.last { return b == id && i == index }
        return false
    }

    public func isLastPenalty() -> Bool {
        if case .penalty = state.history.last { return true }
        return false
    }

    /// Reverse the most recent action. Strictly LIFO so a bonus mark is always
    /// undone before the colour mark that authorised it — state stays legal.
    public func undo() {
        guard let last = state.history.popLast() else { return }
        switch last {
        case let .color(color, index, didLock):
            var r = row(for: color)
            r.marks.remove(index)
            if didLock { r.locked = false }
            setRow(r)
        case let .bonus(id, index):
            var b = bonus(id)
            b.marks.remove(index)
            setBonus(b)
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
        state = QwixxState()
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

    private func setBonus(_ b: BonusRow) {
        switch b.id {
        case .redYellow: state.redYellowBonus = b
        case .greenBlue: state.greenBlueBonus = b
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
            let restored = try? JSONDecoder().decode(QwixxState.self, from: data)
        else { return }
        state = restored
    }
}
