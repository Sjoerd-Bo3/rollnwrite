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
