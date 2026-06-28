//
//  Clever4Game.swift
//  RollnWrite – Clever4
//
//  Engine for "Clever 4ever". All five areas are auto-scored from the official
//  score sheet; foxes are a manual stepper (each scores the lowest area).
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

    // MARK: - Colour theme

    public func color(_ area: Clever4Area) -> ThemeColor { state.theme.value(for: area) }
    public func setColor(_ c: ThemeColor, for area: Clever4Area) { state.theme.set(c, for: area); save() }
    public func resetColors() { state.theme = Clever4ColorTheme(); save() }

    // MARK: - Yellow (free-entry values, 3 rows)

    public enum YellowRow { case top, middle, bottom }

    private func yellowArray(_ row: YellowRow) -> [Int?] {
        switch row {
        case .top:    return state.yellowTop
        case .middle: return state.yellowMiddle
        case .bottom: return state.yellowBottom
        }
    }
    private func setYellowArray(_ row: YellowRow, _ values: [Int?]) {
        switch row {
        case .top:    state.yellowTop = values
        case .middle: state.yellowMiddle = values
        case .bottom: state.yellowBottom = values
        }
    }

    /// The next column that may be filled in a row (rows fill left→right).
    public func yellowNext(_ row: YellowRow) -> Int? {
        yellowArray(row).firstIndex(where: { $0 == nil })
    }

    /// Allowed values for the next free cell of a row. The top row must strictly
    /// ascend and is closed after a 6; middle/bottom accept any die value.
    public func allowedYellow(_ row: YellowRow) -> [Int] {
        let cells = yellowArray(row)
        guard let i = cells.firstIndex(where: { $0 == nil }) else { return [] }
        guard row == .top else { return Array(1...6) }
        let prev = i == 0 ? 0 : (cells[i - 1] ?? 0)
        if prev >= 6 { return [] }                 // closed after a 6
        return Array((prev + 1)...6)
    }

    public func fillYellow(_ row: YellowRow, _ value: Int) {
        guard allowedYellow(row).contains(value), let i = yellowNext(row) else { return }
        var arr = yellowArray(row)
        arr[i] = value
        setYellowArray(row, arr)
        save()
    }

    /// Clear the rightmost filled cell of a row (simple, dependency-safe undo).
    public func clearLastYellow(_ row: YellowRow) {
        var arr = yellowArray(row)
        guard let i = arr.lastIndex(where: { $0 != nil }) else { return }
        arr[i] = nil
        setYellowArray(row, arr)
        save()
    }

    private func yellowColumnFilled(_ col: Int) -> Bool {
        state.yellowTop[col] != nil && state.yellowMiddle[col] != nil && state.yellowBottom[col] != nil
    }

    public var yellowScore: Int {
        let bottom = state.yellowBottom.compactMap { $0 }.reduce(0, +)
        let middle = state.yellowMiddle.compactMap { $0 }.reduce(0, +)
        let columns = (0..<Clever4Layout.yellowCols).reduce(0) {
            $0 + (yellowColumnFilled($1) ? Clever4Layout.yellowColumnStars[$1] : 0)
        }
        return bottom - middle + columns
    }

    // MARK: - Blue (6×6 grid)

    public func toggleBlue(_ index: Int) {
        if state.blue.contains(index) { state.blue.remove(index) } else { state.blue.insert(index) }
        save()
    }
    private func blueColumnCount(_ col: Int) -> Int {
        (0..<Clever4Layout.blueRows).reduce(0) { $0 + (state.blue.contains($1 * Clever4Layout.blueCols + col) ? 1 : 0) }
    }
    private var blueDiagonalCount: Int {
        // Top-right → bottom-left: row r uses column (cols-1 - r).
        (0..<min(Clever4Layout.blueRows, Clever4Layout.blueCols)).reduce(0) {
            $0 + (state.blue.contains($1 * Clever4Layout.blueCols + (Clever4Layout.blueCols - 1 - $1)) ? 1 : 0)
        }
    }
    public var blueScore: Int {
        var total = (0..<Clever4Layout.blueCols).reduce(0) {
            $0 + (blueColumnCount($1) >= 2 ? Clever4Layout.blueColumnValues[$1] : 0)
        }
        if blueDiagonalCount >= 2 { total += Clever4Layout.blueDiagonalValue }
        return total
    }

    // MARK: - Grey (4×16 grid; free crossing)

    public func toggleGrey(_ index: Int) {
        if state.grey.contains(index) { state.grey.remove(index) } else { state.grey.insert(index) }
        save()
    }
    private func greyColumnFilled(_ col: Int) -> Bool {
        (0..<Clever4Layout.greyRows).allSatisfy { state.grey.contains($0 * Clever4Layout.greyCols + col) }
    }
    public var greyScore: Int {
        (0..<Clever4Layout.greyCols).reduce(0) {
            $0 + (greyColumnFilled($1) ? Clever4Layout.greyColumnValues[$1] : 0)
        }
    }

    // MARK: - Green (11 split fields, fill left→right)

    public func greenTopNext() -> Int? { state.greenTop.firstIndex(where: { $0 == nil }) }
    public func greenBottomNext() -> Int? { state.greenBottom.firstIndex(where: { $0 == nil }) }

    public func fillGreenTop(_ value: Int) {
        guard (1...6).contains(value), let i = greenTopNext() else { return }
        state.greenTop[i] = value; save()
    }
    public func fillGreenBottom(_ value: Int) {
        guard (1...6).contains(value), let i = greenBottomNext() else { return }
        state.greenBottom[i] = value; save()
    }
    public func clearLastGreenTop() {
        guard let i = state.greenTop.lastIndex(where: { $0 != nil }) else { return }
        state.greenTop[i] = nil; save()
    }
    public func clearLastGreenBottom() {
        guard let i = state.greenBottom.lastIndex(where: { $0 != nil }) else { return }
        state.greenBottom[i] = nil; save()
    }

    public func greenFieldScore(_ i: Int) -> Int {
        guard let t = state.greenTop[i], let b = state.greenBottom[i] else { return 0 }
        let sum = t + b
        return i >= Clever4Layout.greenDoubleFromIndex ? sum * 2 : sum
    }
    public var greenScore: Int {
        (0..<Clever4Layout.greenFields).reduce(0) { $0 + greenFieldScore($1) }
    }

    // MARK: - Pink (12 fields, fill left→right, no skips)

    public func pinkNext() -> Int? { state.pink.firstIndex(where: { $0 == nil }) }

    public func fillPink(_ value: Int) {
        guard (1...6).contains(value), let i = pinkNext() else { return }
        state.pink[i] = value; save()
    }
    public func clearLastPink() {
        guard let i = state.pink.lastIndex(where: { $0 != nil }) else { return }
        state.pink[i] = nil; save()
    }
    public var pinkScore: Int {
        guard let last = state.pink.lastIndex(where: { $0 != nil }) else { return 0 }
        let base = Clever4Layout.pinkValues[last]
        let bonus = state.pink.compactMap { $0 }.reduce(0) { $0 + (Clever4Layout.pinkBonuses[$1] ?? 0) }
        return base + bonus
    }

    // MARK: - Foxes & scoring

    public func addFox() { state.foxes += 1; save() }
    public func removeFox() { state.foxes = max(0, state.foxes - 1); save() }

    public func score(for area: Clever4Area) -> Int {
        switch area {
        case .yellow: return yellowScore
        case .blue:   return blueScore
        case .grey:   return greyScore
        case .green:  return greenScore
        case .pink:   return pinkScore
        }
    }

    public var lowestAreaScore: Int { Clever4Area.allCases.map { score(for: $0) }.min() ?? 0 }
    public var foxScore: Int { state.foxes * lowestAreaScore }

    public var totalScore: Int { Clever4Area.allCases.reduce(0) { $0 + score(for: $1) } + foxScore }
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
