//
//  Clever2Models.swift
//  RollnWrite – Clever2
//
//  Value types + exact official layout data for "Twice as Clever"
//  (Doppelt so clever) by Wolfgang Warsch / Schmidt Spiele (art. 88234).
//
//  Areas: Silver, Yellow, Blue, Green, Pink. Display colours come from the
//  app-wide dice palette (`DiceTheme`) via nearest-colour matching.
//

import SwiftUI

/// The five scoring areas of Twice as Clever.
public enum Clever2Area: String, Codable, CaseIterable, Identifiable {
    case silver, yellow, blue, green, pink

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    /// The area's STANDARD colour as printed on the official card — the input
    /// to the app-wide `DiceTheme` nearest-colour matching, never shown as-is.
    public var standardColor: Color {
        switch self {
        case .silver: return Color(red: 0.45, green: 0.47, blue: 0.50)
        case .yellow: return Color(red: 0.96, green: 0.80, blue: 0.10)
        case .blue:   return Color(red: 0.16, green: 0.45, blue: 0.82)
        case .green:  return Color(red: 0.18, green: 0.62, blue: 0.30)
        case .pink:   return Color(red: 0.86, green: 0.28, blue: 0.56)
        }
    }
}

/// Bonus icons printed on the card (reference only; applied manually).
public enum Clever2Bonus: Equatable {
    case reroll
    case returnDie
    case plusOne
    case fox
    case mark(Clever2Area)
    case number(Clever2Area, Int)
}

public enum Clever2Layout {
    // Silver: 4 rows (yellow, blue, green, pink), each numbers 1…6.
    public static let silverRowAreas: [Clever2Area] = [.yellow, .blue, .green, .pink]
    public static let silverCols = 6
    /// Points for the number of marks in a single silver row (index = marks).
    public static let silverRowScale = [0, 2, 4, 7, 11, 16, 22]
    /// Bonus above each column (granted when the whole column is crossed).
    public static let silverColumnBonus: [Clever2Bonus] = [
        .plusOne, .mark(.yellow), .fox, .mark(.blue), .mark(.green), .mark(.pink),
    ]
    public static let silverFoxColumn = 2

    // Yellow: 10 cells in a staggered 4-column layout; circle, then cross.
    public static let yellowColumns: [[Int]] = [[1, 2], [3, 4, 5], [2, 5], [6, 3, 4]]
    public static let yellowCount = 10
    /// Points for the number of *crossed* yellow cells (index = count).
    public static let yellowScale = [0, 3, 10, 21, 36, 55, 75, 96, 118, 141, 165]

    // Blue: 12 cells, write blue+white (2…12); each ≤ the previous.
    public static let blueCount = 12
    /// Points for the number of filled blue cells (index = count).
    public static let blueScale = [0, 1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66, 78]
    public static let blueBonus: [Int: Clever2Bonus] = [
        1: .returnDie, 2: .mark(.yellow), 4: .plusOne, 5: .reroll,
        6: .mark(.pink), 8: .fox, 9: .returnDie, 11: .mark(.green),
    ]

    // Green: 12 cells in 6 pairs; write die × multiplier. Pair scores first−second.
    public static let greenMultipliers = [2, 2, 2, 1, 3, 3, 3, 2, 3, 1, 4, 1]
    public static let greenBonus: [Int: Clever2Bonus] = [
        1: .reroll, 3: .mark(.blue), 4: .returnDie, 6: .fox,
        7: .plusOne, 10: .mark(.pink), 11: .mark(.yellow),
    ]
    public static let greenFoxPair = 3 // fox sits around the 4th pair

    // Pink: 12 cells, write any die value. Thresholds gate the bonus only.
    public static let pinkThresholds: [Int?] = [nil, nil, 2, 3, 4, 5, 6, 2, 3, 4, 5, 6]
    public static let pinkBonus: [Int: Clever2Bonus] = [
        2: .reroll, 3: .returnDie, 4: .plusOne, 5: .mark(.green), 6: .mark(.yellow),
        7: .fox, 9: .reroll, 10: .mark(.blue), 11: .mark(.yellow),
    ]
    public static let pinkFoxIndex = 7

    public static let roundBonuses: [Clever2Bonus?] = [.reroll, .plusOne, .returnDie, nil, nil, nil]
    public static let rerollTrackSlots = 7
    public static let returnTrackSlots = 7
    public static let extraDieTrackSlots = 7
}

/// Yellow cell state.
public enum YellowMark: Int, Codable { case empty = 0, circled = 1, crossed = 2 }

/// Full serialisable snapshot of a Twice as Clever game.
public struct Clever2State: Codable, Equatable {
    public var silver: Set<Int> = []                 // crossed cell indices 0…23
    public var yellow: [Int] = Array(repeating: 0, count: Clever2Layout.yellowCount)
    public var blue: [Int?] = Array(repeating: nil, count: Clever2Layout.blueCount)
    public var green: [Int?] = Array(repeating: nil, count: 12)   // stored die value
    public var pink: [Int?] = Array(repeating: nil, count: 12)
    public var foxes: Int = 0
    public var rerollUsed: Set<Int> = []
    public var returnUsed: Set<Int> = []
    public var extraDieUsed: Set<Int> = []
    public var history: [Clever2Action] = []
    // Note: older saves carry a per-game `theme` key; the decoder ignores it
    // (dice colours are an app-wide setting now — see `DiceTheme`).

    public init() {}
}

public enum Clever2Action: Codable, Equatable {
    case silver(Int)
    case yellow(Int)            // advanced one step (empty→circled→crossed)
    case blue(Int, value: Int)
    case green(Int, value: Int)
    case pink(Int, value: Int)
    case reroll(Int)
    case returnAct(Int)
    case extraDie(Int)
}
