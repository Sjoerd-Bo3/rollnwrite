//
//  CleverGame.swift
//  RollnWrite – Clever
//
//  Engine for "That's Pretty Clever". Enforces each area's structure and
//  computes every score, including foxes (= lowest area score). Bonus actions
//  (reroll / +1 / extra marks) are applied manually by the player; foxes are the
//  one bonus detected automatically because they only matter at scoring time.
//
//  SRP: rules + transitions + scoring delegation only. DIP/LSP: conforms to the
//  generic `Scoreboard` protocol from Core.
//

import SwiftUI

@MainActor
public final class CleverGame: ObservableObject, Scoreboard {

    @Published public private(set) var state = CleverState()

    private let persistenceKey: String

    public init(persistenceKey: String = "rollnwrite.clever1.state") {
        self.persistenceKey = persistenceKey
        load()
    }

    // MARK: - Colour theme (map physical dice → areas)

    public func color(_ area: CleverArea) -> ThemeColor { state.theme.value(for: area) }

    public func setColor(_ color: ThemeColor, for area: CleverArea) {
        state.theme.set(color, for: area)
        save()
    }

    public func resetColors() {
        state.theme = CleverColorTheme()
        save()
    }

    // MARK: - Yellow (cross numbers in any order)

    public func isYellowFree(_ index: Int) -> Bool { CleverLayout.yellowGrid[index] == nil }

    public func canMarkYellow(_ index: Int) -> Bool {
        !isYellowFree(index) && !state.yellowCrossed.contains(index)
    }

    public func markYellow(_ index: Int) {
        guard canMarkYellow(index) else { return }
        state.yellowCrossed.insert(index)
        state.history.append(.yellow(index))
        save()
    }

    // MARK: - Blue (cross sums in any order)

    public func canMarkBlue(_ value: Int) -> Bool {
        CleverLayout.blueValues.contains(value) && !state.blueCrossed.contains(value)
    }

    public func markBlue(_ value: Int) {
        guard canMarkBlue(value) else { return }
        state.blueCrossed.insert(value)
        state.history.append(.blue(value))
        save()
    }

    // MARK: - Green (mark left→right)

    public func canMarkGreen() -> Bool { state.greenCount < CleverLayout.rowLength }

    public func markGreen() {
        guard canMarkGreen() else { return }
        state.greenCount += 1
        state.history.append(.green)
        save()
    }

    // MARK: - Orange (write value left→right, × multiplier)

    public var orangeNextIndex: Int? { state.orange.firstIndex(where: { $0 == nil }) }

    /// Orange has no value restriction; any die value 1…6 is allowed.
    public func allowedOrangeValues() -> [Int] { orangeNextIndex == nil ? [] : Array(1...6) }

    public func fillOrange(_ value: Int) {
        guard let i = orangeNextIndex, (1...6).contains(value) else { return }
        state.orange[i] = value
        state.history.append(.orange(i, value: value))
        save()
    }

    // MARK: - Purple (write value left→right, strictly increasing; any after a 6)

    public var purpleNextIndex: Int? { state.purple.firstIndex(where: { $0 == nil }) }

    public func allowedPurpleValues() -> [Int] {
        guard let i = purpleNextIndex else { return [] }
        guard i > 0, let prev = state.purple[i - 1] else { return Array(1...6) }
        if prev == 6 { return Array(1...6) }
        return Array((prev + 1)...6)
    }

    public func fillPurple(_ value: Int) {
        guard let i = purpleNextIndex, allowedPurpleValues().contains(value) else { return }
        state.purple[i] = value
        state.history.append(.purple(i, value: value))
        save()
    }

    // MARK: - Action trackers (reference only; not scored)

    public func toggleReroll(_ slot: Int) {
        if state.rerollUsed.contains(slot) { state.rerollUsed.remove(slot) }
        else { state.rerollUsed.insert(slot); state.history.append(.reroll(slot)) }
        save()
    }

    public func toggleExtraDie(_ slot: Int) {
        if state.extraDieUsed.contains(slot) { state.extraDieUsed.remove(slot) }
        else { state.extraDieUsed.insert(slot); state.history.append(.extraDie(slot)) }
        save()
    }

    // MARK: - Scoring

    public func yellowCompletedColumns() -> [Int] {
        CleverLayout.yellowColumns.indices.filter { col in
            Set(CleverLayout.yellowColumns[col]).isSubset(of: state.yellowCrossed)
        }
    }

    public var yellowScore: Int {
        yellowCompletedColumns().reduce(0) { $0 + CleverLayout.yellowColumnValues[$1] }
    }

    public var blueScore: Int { CleverLayout.bluePointScale[state.blueCrossed.count] }

    public var greenScore: Int {
        state.greenCount == 0 ? 0 : CleverLayout.greenScale[state.greenCount - 1]
    }

    public var orangeScore: Int {
        state.orange.enumerated().reduce(0) { sum, pair in
            guard let v = pair.element else { return sum }
            return sum + v * CleverLayout.orangeMultipliers[pair.offset]
        }
    }

    public var purpleScore: Int { state.purple.compactMap { $0 }.reduce(0, +) }

    public func score(for area: CleverArea) -> Int {
        switch area {
        case .yellow: return yellowScore
        case .blue:   return blueScore
        case .green:  return greenScore
        case .orange: return orangeScore
        case .purple: return purpleScore
        }
    }

    /// Foxes are auto-detected at the printed fox locations (all are row/column
    /// or reach-this-cell completions), since they only affect end scoring.
    public var foxCount: Int {
        var n = 0
        if Set(CleverLayout.yellowFoxCells).isSubset(of: state.yellowCrossed) { n += 1 }
        if Set(CleverLayout.blueFoxValues).isSubset(of: state.blueCrossed) { n += 1 }
        if state.greenCount > CleverLayout.greenFoxIndex { n += 1 }
        if state.orange[CleverLayout.orangeFoxIndex] != nil { n += 1 }
        if state.purple[CleverLayout.purpleFoxIndex] != nil { n += 1 }
        return n
    }

    public var lowestAreaScore: Int {
        CleverArea.allCases.map { score(for: $0) }.min() ?? 0
    }

    public var foxScore: Int { foxCount * lowestAreaScore }

    // MARK: - Scoreboard

    public var totalScore: Int {
        CleverArea.allCases.reduce(0) { $0 + score(for: $1) } + foxScore
    }

    /// A pure scorecard has no enforced end; the player fills it as they play.
    public var isGameOver: Bool { false }

    public var canUndo: Bool { !state.history.isEmpty }

    public func undo() {
        guard let last = state.history.popLast() else { return }
        switch last {
        case let .yellow(i): state.yellowCrossed.remove(i)
        case let .blue(v): state.blueCrossed.remove(v)
        case .green: state.greenCount = max(0, state.greenCount - 1)
        case let .orange(i, _): state.orange[i] = nil
        case let .purple(i, _): state.purple[i] = nil
        case let .reroll(s): state.rerollUsed.remove(s)
        case let .extraDie(s): state.extraDieUsed.remove(s)
        }
        save()
    }

    public func reset() {
        let theme = state.theme // keep the player's colour mapping across games
        var fresh = CleverState()
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
        guard
            let data = UserDefaults.standard.data(forKey: persistenceKey),
            let restored = try? JSONDecoder().decode(CleverState.self, from: data)
        else { return }
        state = restored
    }
}
