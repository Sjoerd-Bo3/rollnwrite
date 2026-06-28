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

    public var defaultColor: ThemeColor {
        switch self {
        case .yellow: return .yellow
        case .blue:   return .blue
        case .grey:   return .gray
        case .green:  return .green
        case .pink:   return .pink
        }
    }
}

public struct Clever4ColorTheme: Codable, Equatable {
    public var yellow: ThemeColor = .yellow
    public var blue: ThemeColor = .blue
    public var grey: ThemeColor = .gray
    public var green: ThemeColor = .green
    public var pink: ThemeColor = .pink

    public init() {}

    public func value(for area: Clever4Area) -> ThemeColor {
        switch area {
        case .yellow: return yellow
        case .blue:   return blue
        case .grey:   return grey
        case .green:  return green
        case .pink:   return pink
        }
    }

    public mutating func set(_ c: ThemeColor, for area: Clever4Area) {
        switch area {
        case .yellow: yellow = c
        case .blue:   blue = c
        case .grey:   grey = c
        case .green:  green = c
        case .pink:   pink = c
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
    public var theme = Clever4ColorTheme()

    public init() {}
}
