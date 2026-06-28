//
//  Clever2Game.swift
//  RollnWrite – Clever2
//
//  Engine for "Twice as Clever". Enforces each area's structure and computes
//  every score. Foxes are tracked manually here (their trigger spots are spread
//  across several area completions), each scoring the lowest area — matching the
//  pure-scorecard model where bonus actions are applied by the player.
//

import SwiftUI

@MainActor
public final class Clever2Game: ObservableObject, Scoreboard {

    @Published public private(set) var state = Clever2State()
    private let persistenceKey: String

    public init(persistenceKey: String = "rollnwrite.clever2.state") {
        self.persistenceKey = persistenceKey
        load()
    }

    // MARK: - Colour theme

    public func color(_ area: Clever2Area) -> ThemeColor { state.theme.value(for: area) }
    public func setColor(_ c: ThemeColor, for area: Clever2Area) { state.theme.set(c, for: area); save() }
    public func resetColors() { state.theme = Clever2ColorTheme(); save() }

    // MARK: - Silver

    public func canCrossSilver(_ index: Int) -> Bool { !state.silver.contains(index) }

    public func crossSilver(_ index: Int) {
        guard canCrossSilver(index) else { return }
        state.silver.insert(index)
        state.history.append(.silver(index))
        save()
    }

    public func silverMarks(inRow row: Int) -> Int {
        (0..<Clever2Layout.silverCols).reduce(0) { $0 + (state.silver.contains(row * Clever2Layout.silverCols + $1) ? 1 : 0) }
    }

    public var silverScore: Int {
        (0..<Clever2Layout.silverRowAreas.count).reduce(0) { $0 + Clever2Layout.silverRowScale[silverMarks(inRow: $1)] }
    }

    // MARK: - Yellow (circle → cross)

    public func yellowState(_ index: Int) -> YellowMark { YellowMark(rawValue: state.yellow[index]) ?? .empty }

    public func canAdvanceYellow(_ index: Int) -> Bool { state.yellow[index] < YellowMark.crossed.rawValue }

    public func advanceYellow(_ index: Int) {
        guard canAdvanceYellow(index) else { return }
        state.yellow[index] += 1
        state.history.append(.yellow(index))
        save()
    }

    public var yellowCrossedCount: Int { state.yellow.filter { $0 == YellowMark.crossed.rawValue }.count }
    public var yellowScore: Int { Clever2Layout.yellowScale[yellowCrossedCount] }

    // MARK: - Blue (descending or equal)

    public var blueNextIndex: Int? { state.blue.firstIndex(where: { $0 == nil }) }

    public func allowedBlueValues() -> [Int] {
        guard let i = blueNextIndex else { return [] }
        guard i > 0, let prev = state.blue[i - 1] else { return Array(2...12) }
        return Array(2...prev)
    }

    public func fillBlue(_ value: Int) {
        guard let i = blueNextIndex, allowedBlueValues().contains(value) else { return }
        state.blue[i] = value
        state.history.append(.blue(i, value: value))
        save()
    }

    public var blueFilledCount: Int { state.blue.compactMap { $0 }.count }
    public var blueScore: Int { Clever2Layout.blueScale[blueFilledCount] }

    // MARK: - Green (write die × multiplier; pairs score first − second)

    public var greenNextIndex: Int? { state.green.firstIndex(where: { $0 == nil }) }
    public func allowedGreenValues() -> [Int] { greenNextIndex == nil ? [] : Array(1...6) }

    public func fillGreen(_ value: Int) {
        guard let i = greenNextIndex, (1...6).contains(value) else { return }
        state.green[i] = value
        state.history.append(.green(i, value: value))
        save()
    }

    /// The number written in a green cell (die × multiplier).
    public func greenWritten(_ index: Int) -> Int? {
        state.green[index].map { $0 * Clever2Layout.greenMultipliers[index] }
    }

    public var greenScore: Int {
        var total = 0
        for pair in 0..<6 {
            if let a = greenWritten(pair * 2), let b = greenWritten(pair * 2 + 1) {
                total += a - b
            }
        }
        return total
    }

    // MARK: - Pink (write die value; sum)

    public var pinkNextIndex: Int? { state.pink.firstIndex(where: { $0 == nil }) }
    public func allowedPinkValues() -> [Int] { pinkNextIndex == nil ? [] : Array(1...6) }

    public func fillPink(_ value: Int) {
        guard let i = pinkNextIndex, (1...6).contains(value) else { return }
        state.pink[i] = value
        state.history.append(.pink(i, value: value))
        save()
    }

    public var pinkScore: Int { state.pink.compactMap { $0 }.reduce(0, +) }

    // MARK: - Foxes (manual)

    public func addFox() { state.foxes += 1; save() }
    public func removeFox() { state.foxes = max(0, state.foxes - 1); save() }

    public func score(for area: Clever2Area) -> Int {
        switch area {
        case .silver: return silverScore
        case .yellow: return yellowScore
        case .blue:   return blueScore
        case .green:  return greenScore
        case .pink:   return pinkScore
        }
    }

    public var lowestAreaScore: Int { Clever2Area.allCases.map { score(for: $0) }.min() ?? 0 }
    public var foxScore: Int { state.foxes * lowestAreaScore }

    // MARK: - Action trackers

    public func toggleReroll(_ s: Int) { toggle(&state.rerollUsed, s, .reroll(s)) }
    public func toggleReturn(_ s: Int) { toggle(&state.returnUsed, s, .returnAct(s)) }
    public func toggleExtraDie(_ s: Int) { toggle(&state.extraDieUsed, s, .extraDie(s)) }

    private func toggle(_ set: inout Set<Int>, _ s: Int, _ action: Clever2Action) {
        if set.contains(s) { set.remove(s) } else { set.insert(s); state.history.append(action) }
        save()
    }

    // MARK: - Scoreboard

    public var totalScore: Int {
        Clever2Area.allCases.reduce(0) { $0 + score(for: $1) } + foxScore
    }

    public var isGameOver: Bool { false }
    public var canUndo: Bool { !state.history.isEmpty }

    public func undo() {
        guard let last = state.history.popLast() else { return }
        switch last {
        case let .silver(i): state.silver.remove(i)
        case let .yellow(i): state.yellow[i] = max(0, state.yellow[i] - 1)
        case let .blue(i, _): state.blue[i] = nil
        case let .green(i, _): state.green[i] = nil
        case let .pink(i, _): state.pink[i] = nil
        case let .reroll(s): state.rerollUsed.remove(s)
        case let .returnAct(s): state.returnUsed.remove(s)
        case let .extraDie(s): state.extraDieUsed.remove(s)
        }
        save()
    }

    public func reset() {
        let theme = state.theme
        var fresh = Clever2State()
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
              let restored = try? JSONDecoder().decode(Clever2State.self, from: data) else { return }
        state = restored
    }
}
