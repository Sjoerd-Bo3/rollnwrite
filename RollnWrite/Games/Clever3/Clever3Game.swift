//
//  Clever3Game.swift
//  RollnWrite – Clever3
//
//  Engine for "Clever Cubed". Yellow, turquoise and pink are auto-scored from
//  the official tables; blue and brown totals are entered by the player because
//  their exact point tables are not published outside the physical sheet.
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

    // MARK: - Yellow / turquoise grids (toggle a cross)

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

    // MARK: - Pink (write numbers; sum). Order doesn't matter for the sum.

    public func setPink(_ index: Int, _ value: Int?) { state.pink[index] = value; save() }
    public var pinkScore: Int { state.pink.compactMap { $0 }.reduce(0, +) }

    // MARK: - Blue / brown (manual totals)

    public func setBlueTotal(_ v: Int) { state.blueTotal = min(max(0, v), Clever3Layout.blueMax); save() }
    public func setBrownTotal(_ v: Int) { state.brownTotal = min(max(0, v), Clever3Layout.brownMax); save() }

    // MARK: - Foxes

    public func addFox() { state.foxes += 1; save() }
    public func removeFox() { state.foxes = max(0, state.foxes - 1); save() }

    public func score(for area: Clever3Area) -> Int {
        switch area {
        case .yellow:    return yellowScore
        case .turquoise: return turquoiseScore
        case .blue:      return state.blueTotal
        case .brown:     return state.brownTotal
        case .pink:      return pinkScore
        }
    }

    public var lowestAreaScore: Int { Clever3Area.allCases.map { score(for: $0) }.min() ?? 0 }
    public var foxScore: Int { state.foxes * lowestAreaScore }

    // MARK: - Scoreboard

    public var totalScore: Int {
        Clever3Area.allCases.reduce(0) { $0 + score(for: $1) } + foxScore
    }
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

    // MARK: - Persistence

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
