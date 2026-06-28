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
    private let persistenceKey: String

    public init(persistenceKey: String = "rollnwrite.clever3.state") {
        self.persistenceKey = persistenceKey
        load()
    }

    // MARK: - Colour theme

    public func color(_ area: Clever3Area) -> ThemeColor { state.theme.value(for: area) }
    public func setColor(_ c: ThemeColor, for area: Clever3Area) { state.theme.set(c, for: area); save() }
    public func resetColors() { state.theme = Clever3ColorTheme(); save() }

    // MARK: - Yellow / turquoise grids

    public func toggleYellow(_ index: Int) {
        if state.yellow.contains(index) { state.yellow.remove(index) } else { state.yellow.insert(index) }
        save()
    }
    public func toggleTurquoise(_ index: Int) {
        if state.turquoise.contains(index) { state.turquoise.remove(index) } else { state.turquoise.insert(index) }
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
        if left, let i = blueLeftNext { state.blueLeft[i] = value }
        else if !left, let i = blueRightNext { state.blueRight[i] = value }
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
        if state.brown.contains(index) {
            if index == state.brown.max() { state.brown.remove(index) }   // only the rightmost can be undone
        } else if canCrossBrown(index) {
            state.brown.insert(index)
        }
        save()
    }
    public var brownScore: Int { Clever3Layout.brownScale[state.brown.count] }

    // MARK: - Pink (write numbers; sum)

    public func setPink(_ index: Int, _ value: Int?) { state.pink[index] = value; save() }
    public var pinkScore: Int { state.pink.compactMap { $0 }.reduce(0, +) }

    // MARK: - Foxes

    public func addFox() { state.foxes += 1; save() }
    public func removeFox() { state.foxes = max(0, state.foxes - 1); save() }

    public func score(for area: Clever3Area) -> Int {
        switch area {
        case .yellow:    return yellowScore
        case .turquoise: return turquoiseScore
        case .blue:      return blueScore
        case .brown:     return brownScore
        case .pink:      return pinkScore
        }
    }

    public var lowestAreaScore: Int { Clever3Area.allCases.map { score(for: $0) }.min() ?? 0 }
    public var foxScore: Int { state.foxes * lowestAreaScore }

    public var totalScore: Int { Clever3Area.allCases.reduce(0) { $0 + score(for: $1) } + foxScore }
    public var isGameOver: Bool { false }
    public var canUndo: Bool { false }
    public func undo() {}

    public func reset() {
        let theme = state.theme
        var fresh = Clever3State()
        fresh.theme = theme
        state = fresh
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
