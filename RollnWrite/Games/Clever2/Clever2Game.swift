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

    /// Human-readable advisories for bonuses the player must act on themselves
    /// (dice actions like reroll/return/+1, free marks where the box is the
    /// player's choice, or foxes earned). Auto-applied bonuses (numbers written
    /// into blue/green/pink) do not appear here — they are written straight onto
    /// the card and pushed to undo.
    @Published public private(set) var earnedBonuses: [String] = []

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
        let before = completedTriggers()
        state.silver.insert(index)
        state.history.append(.silver(index))
        applyNewlyEarned(before: before)
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
        let before = completedTriggers()
        state.yellow[index] += 1
        state.history.append(.yellow(index))
        applyNewlyEarned(before: before)
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
        let before = completedTriggers()
        state.blue[i] = value
        state.history.append(.blue(i, value: value))
        applyNewlyEarned(before: before)
        save()
    }

    public var blueFilledCount: Int { state.blue.compactMap { $0 }.count }
    public var blueScore: Int { Clever2Layout.blueScale[blueFilledCount] }

    // MARK: - Green (write die × multiplier; pairs score first − second)

    public var greenNextIndex: Int? { state.green.firstIndex(where: { $0 == nil }) }
    public func allowedGreenValues() -> [Int] { greenNextIndex == nil ? [] : Array(1...6) }

    public func fillGreen(_ value: Int) {
        guard let i = greenNextIndex, (1...6).contains(value) else { return }
        let before = completedTriggers()
        state.green[i] = value
        state.history.append(.green(i, value: value))
        applyNewlyEarned(before: before)
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
        let before = completedTriggers()
        state.pink[i] = value
        state.history.append(.pink(i, value: value))
        applyNewlyEarned(before: before)
        save()
    }

    public var pinkScore: Int { state.pink.compactMap { $0 }.reduce(0, +) }

    // MARK: - Automatic bonuses

    /// Identity of a bonus-granting trigger (a column/cell completion). Used only
    /// to compare "completed before" vs "completed after" a mark; never stored, so
    /// undo stays consistent and re-completing re-earns the bonus.
    private enum Trigger: Hashable {
        case silverColumn(Int)
        case blueCell(Int)
        case greenCell(Int)
        case pinkCell(Int)
    }

    /// The set of triggers currently complete in the present state.
    private func completedTriggers() -> Set<Trigger> {
        var done = Set<Trigger>()
        // Silver: a column is complete once all 4 colour rows are crossed.
        for c in 0..<Clever2Layout.silverCols {
            if silverMarks(inColumn: c) == Clever2Layout.silverRowAreas.count {
                done.insert(.silverColumn(c))
            }
        }
        // Blue / green / pink: a cell with a bonus is complete once filled.
        for i in Clever2Layout.blueBonus.keys where state.blue.indices.contains(i) && state.blue[i] != nil {
            done.insert(.blueCell(i))
        }
        for i in Clever2Layout.greenBonus.keys where state.green.indices.contains(i) && state.green[i] != nil {
            done.insert(.greenCell(i))
        }
        for i in Clever2Layout.pinkBonus.keys where state.pink.indices.contains(i) && state.pink[i] != nil {
            done.insert(.pinkCell(i))
        }
        return done
    }

    private func silverMarks(inColumn col: Int) -> Int {
        (0..<Clever2Layout.silverRowAreas.count).reduce(0) {
            $0 + (state.silver.contains($1 * Clever2Layout.silverCols + col) ? 1 : 0)
        }
    }

    /// The bonus granted by a trigger, if any.
    private func bonus(for trigger: Trigger) -> Clever2Bonus? {
        switch trigger {
        case let .silverColumn(c): return Clever2Layout.silverColumnBonus[c]
        case let .blueCell(i):     return Clever2Layout.blueBonus[i]
        case let .greenCell(i):    return Clever2Layout.greenBonus[i]
        case let .pinkCell(i):     return Clever2Layout.pinkBonus[i]
        }
    }

    /// After a mark, detect triggers that went from incomplete → complete and fire
    /// their bonuses. Auto-applied marks may complete further triggers, so the
    /// detection is re-run (chained) up to a safety depth cap.
    private func applyNewlyEarned(before: Set<Trigger>, depth: Int = 0) {
        guard depth < 12 else { return }
        let after = completedTriggers()
        let newlyDone = after.subtracting(before)
        guard !newlyDone.isEmpty else { return }

        for trigger in newlyDone.sorted(by: { triggerOrder($0) < triggerOrder($1) }) {
            guard let bonus = bonus(for: trigger) else { continue }
            apply(bonus, depth: depth)
        }
    }

    /// A deterministic ordering key for triggers (banner readability only).
    private func triggerOrder(_ t: Trigger) -> Int {
        switch t {
        case let .silverColumn(c): return 0 + c
        case let .blueCell(i):     return 10 + i
        case let .greenCell(i):    return 40 + i
        case let .pinkCell(i):     return 70 + i
        }
    }

    /// Apply a single earned bonus. Number-bonuses that fit are written onto the
    /// card (and pushed to undo, then chained); everything else becomes an
    /// advisory string in `earnedBonuses`.
    private func apply(_ bonus: Clever2Bonus, depth: Int) {
        switch bonus {
        case .fox:
            note("🦊 Fox!")
        case .reroll:
            note("Re-roll a die")
        case .returnDie:
            note("Return a die")
        case .plusOne:
            note("+1 to a die")
        case let .mark(area):
            // Silver/yellow marks are the player's free choice; advisory.
            note("Cross any \(area.title.lowercased()) box")
        case let .number(area, n):
            apply(number: n, to: area, depth: depth)
        }
    }

    private func apply(number n: Int, to area: Clever2Area, depth: Int) {
        switch area {
        case .blue:
            // Blue requires the value ≤ the previous; only auto-place if valid.
            if let i = blueNextIndex, allowedBlueValues().contains(n) {
                let before = completedTriggers()
                state.blue[i] = n
                state.history.append(.blue(i, value: n))
                applyNewlyEarned(before: before, depth: depth + 1)
            } else {
                note("Blue \(n) earned — doesn't fit (≤ previous)")
            }
        case .green:
            if let i = greenNextIndex, (1...6).contains(n) {
                let before = completedTriggers()
                state.green[i] = n
                state.history.append(.green(i, value: n))
                applyNewlyEarned(before: before, depth: depth + 1)
            } else {
                note("Green \(n) earned — row is full")
            }
        case .pink:
            if let i = pinkNextIndex, (1...6).contains(n) {
                let before = completedTriggers()
                state.pink[i] = n
                state.history.append(.pink(i, value: n))
                applyNewlyEarned(before: before, depth: depth + 1)
            } else {
                note("Pink \(n) earned — row is full")
            }
        case .silver, .yellow:
            // No number-bonuses target these areas; advisory fallback.
            note("Write \(n) in \(area.title.lowercased())")
        }
    }

    private func note(_ message: String) {
        earnedBonuses.append(message)
    }

    /// Dismiss the earned-bonus banner.
    public func clearEarnedBonuses() {
        earnedBonuses.removeAll()
    }

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

    // MARK: - Tap-to-undo (last action only, strictly LIFO)

    /// The most recent action on the LIFO history, if any.
    private var lastAction: Clever2Action? { state.history.last }

    /// True when crossing this silver cell was the most recent action.
    public func isLastSilver(_ index: Int) -> Bool {
        if case let .silver(i) = lastAction { return i == index }
        return false
    }

    /// True when advancing this yellow cell was the most recent action.
    public func isLastYellow(_ index: Int) -> Bool {
        if case let .yellow(i) = lastAction { return i == index }
        return false
    }

    /// True when filling this blue cell was the most recent action.
    public func isLastBlue(_ index: Int) -> Bool {
        if case let .blue(i, _) = lastAction { return i == index }
        return false
    }

    /// True when filling this green cell was the most recent action.
    public func isLastGreen(_ index: Int) -> Bool {
        if case let .green(i, _) = lastAction { return i == index }
        return false
    }

    /// True when filling this pink cell was the most recent action.
    public func isLastPink(_ index: Int) -> Bool {
        if case let .pink(i, _) = lastAction { return i == index }
        return false
    }

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
        earnedBonuses.removeAll()
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
