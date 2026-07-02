//
//  Clever4Models.swift
//  RollnWrite – Clever4
//
//  "Clever 4ever" by Wolfgang Warsch / Schmidt Spiele (art. 49424).
//
//  Full interactive, auto-scoring scorecard. All grid sizes, column/field
//  values, thresholds and multipliers below were transcribed from the official
//  Clever 4ever score sheet (each constant is commented with what was read).
//  Treat this file as the source of truth; verify against the official sheet
//  before changing.
//

import SwiftUI

public enum Clever4Area: String, Codable, CaseIterable, Identifiable {
    case yellow, blue, grey, green, pink

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    /// The area's STANDARD colour as printed on the official card — the input
    /// to the app-wide `DiceTheme` nearest-colour matching, never shown as-is.
    public var standardColor: Color {
        switch self {
        case .yellow: return Color(red: 0.96, green: 0.80, blue: 0.10)
        case .blue:   return Color(red: 0.16, green: 0.45, blue: 0.82)
        case .grey:   return Color(red: 0.45, green: 0.47, blue: 0.50)
        case .green:  return Color(red: 0.18, green: 0.62, blue: 0.30)
        case .pink:   return Color(red: 0.86, green: 0.28, blue: 0.56)
        }
    }
}

public enum Clever4Layout {

    // MARK: Yellow — 3 rows × 5 columns of free-entry value fields.
    // Row 0 (top): must strictly ascend (closed after a 6). Scores 0 itself.
    // Row 1 (middle): any values; summed and counted as NEGATIVE.
    // Row 2 (bottom): any values; summed as POSITIVE.
    // Each fully-filled column scores the value in the yellow star beneath it.
    public static let yellowRows = 3
    public static let yellowCols = 5
    /// Yellow star values under columns 1…5 (read from the sheet): 10,10,15,15,20.
    public static let yellowColumnStars = [10, 10, 15, 15, 20]

    // MARK: Blue — a 6×6 grid. Blue die = row (1…6), white die = column (1…6).
    public static let blueRows = 6
    public static let blueCols = 6
    /// Point value under each column 1…6 (read from the sheet): 7,8,9,10,11,12.
    /// Scored only when a column has ≥2 crosses.
    public static let blueColumnValues = [7, 8, 9, 10, 11, 12]
    /// The top-right→bottom-left diagonal scores this when it has ≥2 crosses.
    public static let blueDiagonalValue = 6

    // MARK: Grey — 4 rows × 16 columns (polyomino marking modelled as free
    // crossing). Each fully-crossed column scores the value printed above it.
    public static let greyRows = 4
    public static let greyCols = 16
    /// Column values above columns 1…16 (read from the sheet):
    /// 1,2,3,4,5,6,6,7,7,8,8,9,9,10,10,11.
    public static let greyColumnValues = [1, 2, 3, 4, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11]

    // MARK: Green — 11 fields, each split into upper/lower triangle (two values).
    // A field's point box = sum of its two values; doubled from field index 3
    // (0-based) onward — the 4th field's badge onward reads "×2" on the sheet.
    public static let greenFields = 11
    public static let greenDoubleFromIndex = 3

    // MARK: Pink — one bar of 12 fields, filled left→right with no skips.
    /// Cumulative point value printed above each field 1…12 (read from sheet):
    /// 2,4,6,9,12,15,19,23,27,32,37,42. Score = value above the last filled field.
    public static let pinkValues = [2, 4, 6, 9, 12, 15, 19, 23, 27, 32, 37, 42]
    public static var pinkFields: Int { pinkValues.count }
    /// Circled-number bonuses added on top: entered 2 → +2, 4 → +4, 6 → +3.
    public static let pinkBonuses: [Int: Int] = [2: 2, 4: 4, 6: 3]

    // MARK: - Bonus maps (transcribed from the official Clever 4ever score sheet)
    //
    // On the Clever 4ever sheet every printed bonus is a player *choice*: a
    // re-roll, a +1, an extra/white die ("○"), a fox, or a "?" = choose any
    // value/cross in that colour. None can be auto-placed deterministically, so
    // all surface as advisory strings. Foxes stay the manual stepper and are NOT
    // listed here (they would double-count against the stepper).

    /// Yellow: bonuses sit on the dividers under the 3×5 grid. The icons under
    /// the *top* row fire when that column's top cell is filled; the icons under
    /// the *middle* row fire when that column's middle cell is filled.
    /// Top-row dividers (cols 0–4): –, ○extraDie, ?orange, ?green, fox.
    /// Mid-row dividers (cols 0–4): reroll, ?purple, ?blue, +1, ?yellow.
    public static let yellowTopColBonus: [Int: C4Bonus] = [
        1: .extraDie,
        2: .pick(.pink),    // orange "?" — nearest area is pink on this card
        3: .pick(.green),
        // col 4 = fox (manual stepper) → omitted
    ]
    public static let yellowMidColBonus: [Int: C4Bonus] = [
        0: .reroll,
        1: .pick(.pink),    // purple "?"
        2: .pick(.blue),
        3: .plusOne,
        4: .pick(.yellow),
    ]

    /// Blue 6×6 grid — a bonus printed at the right end of each row, earned when
    /// that whole row (all 6) is crossed.
    /// Rows 0–5: ?green, ?purple, ?yellow, +1, ?orange, fox. (The TR→BL diagonal
    /// ends in a re-roll, granted when the diagonal is fully crossed.)
    public static let blueRowBonus: [Int: C4Bonus] = [
        0: .pick(.green),
        1: .pick(.pink),    // purple "?"
        2: .pick(.yellow),
        3: .plusOne,
        4: .pick(.pink),    // orange "?"
        // row 5 = fox (manual stepper) → omitted
    ]
    public static let blueDiagonalBonus: C4Bonus = .reroll

    /// Grey 4×16 grid — bonuses printed inside specific cells; fire when that
    /// exact cell is crossed. Encoded as (row, col) → icon, 0-indexed.
    /// Positions read from the sheet (dense grid; cols are a best reading and
    /// may be ±1 — verify against the official sheet before relying on them).
    public static let greyCellBonus: [GridPos: C4Bonus] = [
        GridPos(0, 0):  .extraDie,    // ○ top-left
        GridPos(0, 5):  .pick(.green),
        GridPos(0, 12): .extraDie,    // ○
        GridPos(1, 7):  .reroll,
        GridPos(1, 15): .pick(.green),
        GridPos(2, 3):  .pick(.pink), // purple "?"
        GridPos(2, 5):  .extraDie,    // ○
        GridPos(2, 9):  .extraDie,    // ○
        GridPos(2, 13): .pick(.blue),
        GridPos(3, 0):  .reroll,
        GridPos(3, 7):  .plusOne,
        GridPos(3, 11): .pick(.yellow),
        GridPos(3, 14): .extraDie,    // ○
    ]

    /// Green 11 split fields — a bonus under each field, earned once both its
    /// triangles are filled.
    /// Fields 0–10: reroll, ?blue, ○extraDie, ?yellow, ?orange, +1, ?purple,
    /// ?blue, ?yellow, fox, +1.
    public static let greenFieldBonus: [Int: C4Bonus] = [
        0: .reroll,
        1: .pick(.blue),
        2: .extraDie,
        3: .pick(.yellow),
        4: .pick(.pink),    // orange "?"
        5: .plusOne,
        6: .pick(.pink),    // purple "?"
        7: .pick(.blue),
        8: .pick(.yellow),
        // field 9 = fox (manual stepper) → omitted
        10: .plusOne,
    ]

    /// Pink 12-field bar — a bonus under some fields, earned once that field is
    /// written. Fields 0–11: ○extraDie, –, ?green, +1, reroll, –, ?orange, fox,
    /// –, ?blue, –, ?yellow.
    public static let pinkFieldBonus: [Int: C4Bonus] = [
        0: .extraDie,
        2: .pick(.green),
        3: .plusOne,
        4: .reroll,
        6: .pick(.pink),    // orange "?"
        // field 7 = fox (manual stepper) → omitted
        9: .pick(.blue),
        11: .pick(.yellow),
    ]
}

/// A 0-indexed grid position, used to key grey-cell bonuses.
public struct GridPos: Hashable {
    public let row: Int
    public let col: Int
    public init(_ row: Int, _ col: Int) { self.row = row; self.col = col }
}

/// A bonus printed on the Clever 4ever sheet. All are player choices, so each is
/// surfaced as an advisory message (none auto-place).
public enum C4Bonus: Equatable {
    case reroll
    case plusOne
    case extraDie
    case fox
    case pick(Clever4Area)   // "?" → choose any value/cross in that colour

    public var message: String {
        switch self {
        case .reroll:      return "Re-roll a die"
        case .plusOne:     return "+1 to a die"
        case .extraDie:    return "Use an extra (white) die"
        case .fox:         return "🦊 Fox earned!"
        case let .pick(a): return "Choose any \(a.title.lowercased()) value (?)"
        }
    }
}

public struct Clever4State: Codable, Equatable {
    // Yellow: three rows of free-entry values (nil = empty), 5 columns each.
    public var yellowTop: [Int?] = Array(repeating: nil, count: Clever4Layout.yellowCols)
    public var yellowMiddle: [Int?] = Array(repeating: nil, count: Clever4Layout.yellowCols)
    public var yellowBottom: [Int?] = Array(repeating: nil, count: Clever4Layout.yellowCols)

    // Blue: crossed cells; index = row * blueCols + col.
    public var blue: Set<Int> = []

    // Grey: crossed cells; index = row * greyCols + col.
    public var grey: Set<Int> = []

    // Green: two values per field (upper / lower triangle).
    public var greenTop: [Int?] = Array(repeating: nil, count: Clever4Layout.greenFields)
    public var greenBottom: [Int?] = Array(repeating: nil, count: Clever4Layout.greenFields)

    // Pink: written values left→right.
    public var pink: [Int?] = Array(repeating: nil, count: Clever4Layout.pinkFields)

    public var foxes: Int = 0
    // Note: older saves carry a per-game `theme` key; the decoder ignores it
    // (dice colours are an app-wide setting now — see `DiceTheme`).

    public init() {}
}
