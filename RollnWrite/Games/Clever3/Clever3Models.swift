//
//  Clever3Models.swift
//  RollnWrite – Clever3
//
//  "Clever Cubed" (Clever hoch Drei) by Wolfgang Warsch / Schmidt Spiele.
//  Layout + scoring transcribed from the official score sheet (all five areas
//  are now auto-scored).
//

import SwiftUI

public enum Clever3Area: String, Codable, CaseIterable, Identifiable {
    case yellow, turquoise, blue, brown, pink

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    public var defaultColor: ThemeColor {
        switch self {
        case .yellow:    return .yellow
        case .turquoise: return .teal
        case .blue:      return .blue
        case .brown:     return .brown
        case .pink:      return .pink
        }
    }
}

public struct Clever3ColorTheme: Codable, Equatable {
    public var yellow: ThemeColor = .yellow
    public var turquoise: ThemeColor = .teal
    public var blue: ThemeColor = .blue
    public var brown: ThemeColor = .brown
    public var pink: ThemeColor = .pink

    public init() {}

    public func value(for area: Clever3Area) -> ThemeColor {
        switch area {
        case .yellow:    return yellow
        case .turquoise: return turquoise
        case .blue:      return blue
        case .brown:     return brown
        case .pink:      return pink
        }
    }

    public mutating func set(_ c: ThemeColor, for area: Clever3Area) {
        switch area {
        case .yellow:    yellow = c
        case .turquoise: turquoise = c
        case .blue:      blue = c
        case .brown:     brown = c
        case .pink:      pink = c
        }
    }
}

public enum Clever3Layout {
    // Yellow: 3 rows × 6 numbers; score per row by crosses.
    public static let yellowRows = 3
    public static let yellowCols = 6
    public static let yellowRowScale = [0, 2, 6, 12, 20, 30, 42]   // max 126

    // Turquoise: 5 rows × 6 numbers; score per row by crosses.
    public static let turquoiseRows = 5
    public static let turquoiseCols = 6
    public static let turquoiseRowScale = [0, 1, 3, 6, 10, 15, 21]  // max 105

    // Blue: a ±1 track around the central 7. 6 cells each side.
    public static let blueSideCells = 6
    /// Point value above each position, from nearest the centre (index 0) outward.
    public static let bluePositionScale = [3, 6, 9, 13, 17, 22]
    public static let blueBonusValues: Set<Int> = [2, 3, 4, 10, 11, 12]  // +4 each

    // Brown: one row of 12; score by total crosses (skips allowed but cost points).
    public static let brownNumbers = [1, 5, 3, 4, 2, 6, 4, 5, 2, 1, 6, 3]
    public static let brownScale = [0, 2, 5, 9, 14, 20, 27, 35, 44, 54, 65, 77, 90]

    // Pink: 11 cells, write die × multiplier (or the halved bonus value); score = sum.
    public static let pinkMultipliers = [1, 2, 2, 1, 2, 2, 1, 3, 2, 2, 3]
    public static var pinkCells: Int { pinkMultipliers.count }

    // MARK: - Bonus maps (transcribed from the official Clever Cubed score sheet)
    //
    // Each entry maps a completion (a grid row, a track cell, a brown/pink cell)
    // to the bonus icon printed there. In Clever Cubed every bonus is a player
    // *choice* (a "?" = choose any value of that colour, a re-roll, a +1, an
    // extra-die, or a fox), so none can be auto-placed deterministically — they
    // all surface as advisory strings. Foxes stay the manual stepper and are NOT
    // listed here (they would double-count against the stepper).

    /// Yellow grid: a bonus earned when a *row* is fully crossed (all 6 cells).
    /// The sheet prints bonuses under rows 0 and 1 (none under row 2's far cells
    /// other than what's shown). Read left-most→right is irrelevant for a row
    /// completion; the icon is granted once the whole row is crossed.
    /// Row 0 under-icons (cols 0–5): reroll, extraDie, ?green, +1, ?blue, fox.
    /// Row 1 under-icons (cols 0–5): extraDie, ?blue, ?purple, ?orange, ?(white), +1.
    /// We grant only the *row-completion* bonuses (one representative per row);
    /// per-cell granting isn't possible because yellow rows are crossed in any
    /// order with no positional bonus boxes — the icons sit on the row divider.
    /// Best reading: treat each yellow row as granting its rightmost icon.
    public static let yellowRowBonus: [Int: C3Bonus] = [
        0: .fox,            // row 0 divider, rightmost = fox  (but fox via stepper)
        1: .plusOne,        // row 1 divider, rightmost = +1
    ]

    /// Turquoise (the 6×6 numbered grid) — row-end bonuses (right of rows 0–4)
    /// and column-foot bonuses (under cols 0–5).
    /// Row ends (rows 0–4): fox, +1, ?orange, ?(white). Bottom (cols 0–5):
    /// ?orange, ?green, ?yellow, extraDie, ?purple, reroll.
    public static let turquoiseRowBonus: [Int: C3Bonus] = [
        1: .plusOne,        // row 1 end = +1
        2: .pick(.brown),   // row 2 end = ? orange-ish → choose a brown value
        3: .pick(.brown),   // row 3 end = ? (white)   → choose any value
    ]
    public static let turquoiseColBonus: [Int: C3Bonus] = [
        0: .pick(.brown),   // ? orange
        1: .pick(.yellow),  // ? green
        2: .pick(.yellow),  // ? yellow
        3: .extraDie,       // dice
        4: .pick(.blue),    // ? purple
        5: .reroll,         // reroll
    ]

    /// Blue ±1 track (the purple band). Position index 0 = innermost (value 3),
    /// 5 = outermost (value 22), per side. Centre 7 grants a reroll.
    /// Left side bonuses (idx→icon): 5:+1, 4:?green, 2:?yellow, 1:extraDie.
    /// Right side bonuses (idx→icon): 1:reroll, 2:?orange, 4:?blue, 5:fox.
    public static let blueLeftBonus: [Int: C3Bonus] = [
        5: .plusOne,
        4: .pick(.yellow),
        2: .pick(.yellow),
        1: .extraDie,
    ]
    public static let blueRightBonus: [Int: C3Bonus] = [
        1: .reroll,
        2: .pick(.brown),
        4: .pick(.blue),
        // idx 5 = fox (manual stepper) → omitted
    ]
    public static let blueCenterBonus: C3Bonus = .reroll

    /// Brown row of 12. Icons sit between adjacent cells; we attach each to the
    /// later cell, so the bonus fires when that cell is crossed (you reach it).
    /// 1:extraDie, 2:?green, 4:reroll, 5:?blue, 7:+1, 8:?purple, 10:?yellow,
    /// 11:fox.
    public static let brownBonus: [Int: C3Bonus] = [
        1: .extraDie,
        2: .pick(.yellow),
        4: .reroll,
        5: .pick(.blue),
        7: .plusOne,
        8: .pick(.blue),
        10: .pick(.yellow),
        // 11 = fox (manual stepper) → omitted
    ]

    /// Pink row of 11. Icons sit between adjacent cells; attach to the later cell.
    /// 1:reroll, 2:?blue, 3:+1, 4:extraDie, 5:?yellow, 6:?orange, 7:reroll,
    /// 8:fox, 9:?purple, 10:?blue.
    public static let pinkBonus: [Int: C3Bonus] = [
        1: .reroll,
        2: .pick(.blue),
        3: .plusOne,
        4: .extraDie,
        5: .pick(.yellow),
        6: .pick(.brown),
        7: .reroll,
        // 8 = fox (manual stepper) → omitted
        9: .pick(.blue),
        10: .pick(.blue),
    ]
}

/// A bonus printed on the Clever Cubed sheet. All are player choices in this
/// game, so each is surfaced as an advisory message (none auto-place).
public enum C3Bonus: Equatable {
    case reroll
    case plusOne
    case extraDie
    case fox
    case pick(Clever3Area)   // "?" → choose any value/cross in that colour

    public var message: String {
        switch self {
        case .reroll:       return "Re-roll a die"
        case .plusOne:      return "+1 to a die"
        case .extraDie:     return "Use an extra die"
        case .fox:          return "🦊 Fox earned!"
        case let .pick(a):  return "Choose any \(a.title.lowercased()) value (?)"
        }
    }
}

public struct Clever3State: Codable, Equatable {
    public var yellow: Set<Int> = []      // crossed indices over 3*6
    public var turquoise: Set<Int> = []   // crossed indices over 5*6
    public var blueLeft: [Int?] = Array(repeating: nil, count: Clever3Layout.blueSideCells)
    public var blueRight: [Int?] = Array(repeating: nil, count: Clever3Layout.blueSideCells)
    public var brown: Set<Int> = []       // crossed indices 0…11
    public var pink: [Int?] = Array(repeating: nil, count: Clever3Layout.pinkCells)
    public var foxes: Int = 0
    public var theme = Clever3ColorTheme()

    public init() {}
}
