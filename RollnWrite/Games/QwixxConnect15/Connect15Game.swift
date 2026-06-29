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
//  The colour-row rules are identical to classic Qwixx; the three connection
//  fields per row are the variant-specific addition. They count as extra crosses
//  toward each row's total (raising the cap from 12 to 15).
//

import SwiftUI

@MainActor
public final class Connect15Game: ObservableObject, Scoreboard {

    @Published public private(set) var state = Connect15State()

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

    // MARK: - Rule enforcement (connection fields)

    /// A connection field of `color` is legal while the game is live, that row is
    /// not locked, and the row still has a free connection field. (Locking a row
    /// ends marking in it, including its connection fields.)
    public func canMarkConnection(_ color: GameColor) -> Bool {
        guard !isGameOver else { return false }
        guard !row(for: color).locked else { return false }
        return connections(for: color).hasRoomLeft
    }

    public func markConnection(_ color: GameColor) {
        guard canMarkConnection(color) else { return }
        setConnections(for: color, connections(for: color).crossed + 1)
        state.history.append(.connection(color))
        save()
    }

    // MARK: - Penalties

    public func canAddPenalty() -> Bool {
        !isGameOver && state.penalties < Connect15State.maxPenalties
    }

    public func addPenalty() {
        guard canAddPenalty() else { return }
        state.penalties += 1
        state.history.append(.penalty)
        save()
    }

    // MARK: - Scoreboard

    /// Crosses counted toward a colour's score: its number marks, the lock cross,
    /// plus any crossed connection fields. Capped by the scoring strategy (15).
    public func crosses(for color: GameColor) -> Int {
        row(for: color).scoringCrosses + connections(for: color).crossed
    }

    public func points(for color: GameColor) -> Int {
        scoring.points(forCrosses: crosses(for: color))
    }

    public var penaltyPoints: Int { state.penalties * 5 }

    public var totalScore: Int {
        GameColor.allCases.reduce(0) { $0 + points(for: $1) } - penaltyPoints
    }

    /// Ends when two rows are locked, or the 4th penalty is taken.
    public var isGameOver: Bool {
        lockedRowCount >= 2 || state.penalties >= Connect15State.maxPenalties
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

    public func isLastConnectionMark(_ color: GameColor) -> Bool {
        if case let .connection(c) = state.history.last { return c == color }
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
        case let .connection(color):
            setConnections(for: color, max(0, connections(for: color).crossed - 1))
        case .penalty:
            state.penalties = max(0, state.penalties - 1)
        }
        save()
    }

    public func reset() {
        state = Connect15State()
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

    private func setConnections(for color: GameColor, _ crossed: Int) {
        switch color {
        case .red:    state.redConnections.crossed = crossed
        case .yellow: state.yellowConnections.crossed = crossed
        case .green:  state.greenConnections.crossed = crossed
        case .blue:   state.blueConnections.crossed = crossed
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
