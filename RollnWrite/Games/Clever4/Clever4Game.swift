//
//  Clever4Game.swift
//  RollnWrite – Clever4
//
//  Scorecard-calculator engine for "Clever 4ever": per-area totals entered by
//  the player, with foxes (× lowest area) and the grand total computed.
//

import SwiftUI

@MainActor
public final class Clever4Game: ObservableObject, Scoreboard {

    @Published public private(set) var state = Clever4State()
    private let persistenceKey: String

    public init(persistenceKey: String = "rollnwrite.clever4.state") {
        self.persistenceKey = persistenceKey
        load()
    }

    public func color(_ area: Clever4Area) -> ThemeColor { state.theme.value(for: area) }
    public func setColor(_ c: ThemeColor, for area: Clever4Area) { state.theme.set(c, for: area); save() }
    public func resetColors() { state.theme = Clever4ColorTheme(); save() }

    public func score(for area: Clever4Area) -> Int { state.totals[area.rawValue] ?? 0 }
    public func setScore(_ value: Int, for area: Clever4Area) {
        state.totals[area.rawValue] = max(0, value)
        save()
    }

    public func addFox() { state.foxes += 1; save() }
    public func removeFox() { state.foxes = max(0, state.foxes - 1); save() }

    public var lowestAreaScore: Int { Clever4Area.allCases.map { score(for: $0) }.min() ?? 0 }
    public var foxScore: Int { state.foxes * lowestAreaScore }

    public var totalScore: Int {
        Clever4Area.allCases.reduce(0) { $0 + score(for: $1) } + foxScore
    }
    public var isGameOver: Bool { false }
    public var canUndo: Bool { false }
    public func undo() {}

    public func reset() {
        let theme = state.theme
        var fresh = Clever4State()
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
              let restored = try? JSONDecoder().decode(Clever4State.self, from: data) else { return }
        state = restored
    }
}
