//
//  Clever3Game.swift
//  RollnWrite – Clever3
//
//  Engine for "Clever Cubed". All five areas are auto-scored from the official
//  score sheet.
//

import SwiftUI

@MainActor
public final class Clever3Game: ObservableObject, Scoreboard {

    @Published public private(set) var state = Clever3State()

    /// Advisory messages for bonuses the player has just earned. In Clever Cubed
    /// every printed bonus is a player choice (re-roll / +1 / extra-die / "?" =
    /// choose a colour value), so none are auto-placed — they all appear here as
    /// reminders. Foxes stay the manual stepper and are not surfaced here.
    @Published public private(set) var earnedBonuses: [String] = []

    private let persistenceKey: String

    public init(persistenceKey: String = "rollnwrite.clever3.state") {
        self.persistenceKey = persistenceKey
        load()
    }

    // MARK: - Colour theme (app-wide physical dice → areas)

    /// Display colour for an area, resolved from the app-wide dice palette
    /// (`DiceTheme`) by nearest-colour matching. Presentation only.
    public func color(_ area: Clever3Area) -> DiceColor {
        let areas = Clever3Area.allCases
        return DiceTheme.shared.mapped(standard: areas.map(\.standardColor))[areas.firstIndex(of: area)!]
    }

    // MARK: - Yellow / turquoise grids

    public func toggleYellow(_ index: Int) {
        let before = completedTriggers()
        if state.yellow.contains(index) { state.yellow.remove(index) } else { state.yellow.insert(index) }
        applyNewlyEarned(before: before)
        save()
    }
    public func toggleTurquoise(_ index: Int) {
        let before = completedTriggers()
        if state.turquoise.contains(index) { state.turquoise.remove(index) } else { state.turquoise.insert(index) }
        applyNewlyEarned(before: before)
        save()
    }
    public func yellowMarks(inRow row: Int) -> Int {
        (0..<Clever3Layout.yellowCols).reduce(0) { $0 + (state.yellow.contains(row * Clever3Layout.yellowCols + $1) ? 1 : 0) }
    }
    public func turquoiseMarks(inRow row: Int) -> Int {
        (0..<Clever3Layout.turquoiseCols).reduce(0) { $0 + (state.turquoise.contains(row * Clever3Layout.turquoiseCols + $1) ? 1 : 0) }
    }
    public var yellowScore: Int {
        (0..<Clever3Layout.yellowRows).reduce(0) { $0 + Clever3Layout.yellowRowScale[yellowMarks(inRow: $1)] }
    }
    public var turquoiseScore: Int {
        (0..<Clever3Layout.turquoiseRows).reduce(0) { $0 + Clever3Layout.turquoiseRowScale[turquoiseMarks(inRow: $1)] }
    }

    // MARK: - Blue ±1 track

    public var blueLeftNext: Int? { state.blueLeft.firstIndex(where: { $0 == nil }) }
    public var blueRightNext: Int? { state.blueRight.firstIndex(where: { $0 == nil }) }

    /// Allowed values for the next free cell on a side: one step from the inner
    /// neighbour (lower on the left, higher on the right), or a 7 to reset — but
    /// never two 7s in a row, and only valid sums (2–12).
    public func allowedBlue(left: Bool) -> [Int] {
        let cells = left ? state.blueLeft : state.blueRight
        guard let i = cells.firstIndex(where: { $0 == nil }) else { return [] }
        let prev = i == 0 ? 7 : (cells[i - 1] ?? 7)
        var out: [Int] = []
        let step = left ? prev - 1 : prev + 1
        if (2...12).contains(step) { out.append(step) }
        if prev != 7 { out.append(7) }
        return out
    }

    public func fillBlue(left: Bool, _ value: Int) {
        guard allowedBlue(left: left).contains(value) else { return }
        let before = completedTriggers()
        if left, let i = blueLeftNext { state.blueLeft[i] = value }
        else if !left, let i = blueRightNext { state.blueRight[i] = value }
        applyNewlyEarned(before: before)
        save()
    }

    private func outermost(_ cells: [Int?]) -> Int {
        (cells.lastIndex(where: { $0 != nil })).map { Clever3Layout.bluePositionScale[$0] } ?? 0
    }

    public var blueScore: Int {
        let bonus = (state.blueLeft + state.blueRight).compactMap { $0 }
            .filter { Clever3Layout.blueBonusValues.contains($0) }.count
        return outermost(state.blueLeft) + outermost(state.blueRight) + 4 * bonus
    }

    // MARK: - Brown (left→right, skips allowed)

    public func canCrossBrown(_ index: Int) -> Bool { index > (state.brown.max() ?? -1) }
    public func toggleBrown(_ index: Int) {
        let before = completedTriggers()
        if state.brown.contains(index) {
            if index == state.brown.max() { state.brown.remove(index) }   // only the rightmost can be undone
        } else if canCrossBrown(index) {
            state.brown.insert(index)
        }
        applyNewlyEarned(before: before)
        save()
    }
    public var brownScore: Int { Clever3Layout.brownScale[state.brown.count] }

    // MARK: - Pink (write numbers; sum)

    public func setPink(_ index: Int, _ value: Int?) {
        let before = completedTriggers()
        state.pink[index] = value
        applyNewlyEarned(before: before)
        save()
    }
    public var pinkScore: Int { state.pink.compactMap { $0 }.reduce(0, +) }

    // MARK: - Automatic bonuses (advisory only)

    /// Identity of a bonus-granting completion. Compared "before" vs "after" each
    /// mark; never persisted, so undo (clearing a cell) re-arms it for next time.
    private enum Trigger: Hashable {
        case yellowCell(row: Int, col: Int)
        case turquoiseRow(Int)
        case turquoiseCol(Int)
        case blueLeft(Int)
        case blueRight(Int)
        case brownCell(Int)
        case pinkCell(Int)
    }

    private func completedTriggers() -> Set<Trigger> {
        var done = Set<Trigger>()
        // Yellow cells: each numbered cell fires its own bonus once crossed.
        for i in state.yellow {
            let row = i / Clever3Layout.yellowCols
            let col = i % Clever3Layout.yellowCols
            done.insert(.yellowCell(row: row, col: col))
        }
        // Turquoise rows & columns fully crossed.
        for r in 0..<Clever3Layout.turquoiseRows where turquoiseMarks(inRow: r) == Clever3Layout.turquoiseCols {
            done.insert(.turquoiseRow(r))
        }
        for c in 0..<Clever3Layout.turquoiseCols {
            let full = (0..<Clever3Layout.turquoiseRows).allSatisfy {
                state.turquoise.contains($0 * Clever3Layout.turquoiseCols + c)
            }
            if full { done.insert(.turquoiseCol(c)) }
        }
        // Blue track cells: a position is "reached" once written.
        for i in state.blueLeft.indices where state.blueLeft[i] != nil { done.insert(.blueLeft(i)) }
        for i in state.blueRight.indices where state.blueRight[i] != nil { done.insert(.blueRight(i)) }
        // Brown cells crossed.
        for i in state.brown { done.insert(.brownCell(i)) }
        // Pink cells written.
        for i in state.pink.indices where state.pink[i] != nil { done.insert(.pinkCell(i)) }
        return done
    }

    private func bonus(for t: Trigger) -> C3Bonus? {
        switch t {
        case let .yellowCell(row, col): return Clever3Layout.yellowCellBonus[row]?[col]
        case let .turquoiseRow(r): return Clever3Layout.turquoiseRowBonus[r]
        case let .turquoiseCol(c): return Clever3Layout.turquoiseColBonus[c]
        case let .blueLeft(i):     return Clever3Layout.blueLeftBonus[i]
        case let .blueRight(i):    return Clever3Layout.blueRightBonus[i]
        case let .brownCell(i):    return Clever3Layout.brownBonus[i]
        case let .pinkCell(i):     return Clever3Layout.pinkBonus[i]
        }
    }

    /// Detect completions that flipped incomplete → complete and surface their
    /// (advisory) bonuses. None auto-place, so there is no chaining to do here.
    private func applyNewlyEarned(before: Set<Trigger>) {
        let newly = completedTriggers().subtracting(before)
        guard !newly.isEmpty else { return }
        for t in newly.sorted(by: { order($0) < order($1) }) {
            if let b = bonus(for: t) { earnedBonuses.append(b.message) }
        }
    }

    private func order(_ t: Trigger) -> Int {
        switch t {
        case let .yellowCell(row, col): return row * Clever3Layout.yellowCols + col
        case let .turquoiseRow(r): return 100 + r
        case let .turquoiseCol(c): return 110 + c
        case let .blueLeft(i):     return 120 + i
        case let .blueRight(i):    return 130 + i
        case let .brownCell(i):    return 140 + i
        case let .pinkCell(i):     return 150 + i
        }
    }

    public func clearEarnedBonuses() { earnedBonuses.removeAll() }

    // MARK: - Foxes

    public func addFox() { state.foxes += 1; save() }
    public func removeFox() { state.foxes = max(0, state.foxes - 1); save() }

    public func score(for area: Clever3Area) -> Int {
        switch area {
        case .yellow: return yellowScore
        case .blue:   return turquoiseScore
        case .purple: return blueScore
        case .orange: return brownScore
        case .green:  return pinkScore
        }
    }

    public var lowestAreaScore: Int { Clever3Area.allCases.map { score(for: $0) }.min() ?? 0 }
    public var foxScore: Int { state.foxes * lowestAreaScore }

    public var totalScore: Int { Clever3Area.allCases.reduce(0) { $0 + score(for: $1) } + foxScore }
    public var isGameOver: Bool { false }
    public var canUndo: Bool { false }
    public func undo() {}

    public func reset() {
        state = Clever3State()
        earnedBonuses.removeAll()
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let restored = try? JSONDecoder().decode(Clever3State.self, from: data) else { return }
        state = restored
    }
}
