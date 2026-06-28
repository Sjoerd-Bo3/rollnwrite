//
//  Clever3Models.swift
//  RollnWrite – Clever3
//
//  "Clever Cubed" (Clever hoch Drei) by Wolfgang Warsch / Schmidt Spiele.
//
//  Scoring transcribed from the official rulebook. Yellow, turquoise, pink and
//  foxes are scored exactly. Blue and brown use the official per-position / row
//  point tables which are not published outside the physical score sheet, so the
//  player enters those two area totals (matching the official online calculator)
//  until the sheet is available — see Clever3Game.
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
    // Yellow: 3 rows × 6 numbers; score per row by number of crosses.
    public static let yellowRows = 3
    public static let yellowCols = 6
    public static let yellowRowScale = [0, 2, 6, 12, 20, 30, 42]   // max 126

    // Turquoise: 5 rows × 6 numbers; score per row by number of crosses.
    public static let turquoiseRows = 5
    public static let turquoiseCols = 6
    public static let turquoiseRowScale = [0, 1, 3, 6, 10, 15, 21]  // max 105

    // Pink: write numbers; score = sum. (Cells are generous; sum is exact.)
    public static let pinkCells = 10

    public static let blueMax = 68
    public static let brownMax = 90
}

public struct Clever3State: Codable, Equatable {
    public var yellow: Set<Int> = []     // crossed indices over rows*cols (3*6)
    public var turquoise: Set<Int> = []  // crossed indices over 5*6
    public var pink: [Int?] = Array(repeating: nil, count: Clever3Layout.pinkCells)
    public var blueTotal: Int = 0        // entered manually (see notes)
    public var brownTotal: Int = 0       // entered manually
    public var foxes: Int = 0
    public var theme = Clever3ColorTheme()

    public init() {}
}
