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

    /// Printed edge bonuses (reference only; applied manually — pure-scorecard
    /// model, same as every other Clever 2 bonus). Pad photo evidence (crop
    /// "yellow_precise": the staggered grid with dark arrows chaining cells to
    /// coloured badges beyond the grid edges):
    ///
    /// FIVE ROW bonuses on the right edge, one per horizontal chain (each row
    /// reads left→right across two flat-index cells and an arrow into a
    /// badge). Row order top→bottom, by the flat cell indices it connects:
    ///   row0: cells (2,7)   [printed "3","6"] → mark(.blue)   ("?" blue)
    ///   row1: cells (0,5)   [printed "1","2"] → returnDie      (⟲ icon)
    ///   row2: cells (3,8)   [printed "4","3"] → mark(.yellow) ("?" yellow)
    ///   row3: cells (1,6)   [printed "2","5"] → mark(.green)  ("?" green)
    ///   row4: cells (4,9)   [printed "5","4"] → mark(.pink)   ("?" purple)
    /// (Flat indices follow `yellowColumns` concatenated column-major: column
    /// 0 → 0,1; column 1 → 2,3,4; column 2 → 5,6; column 3 → 7,8,9 — matching
    /// `Clever2YellowGrid`'s `columnStarts` accumulation.)
    public static let yellowRowBonus: [Clever2Bonus] = [
        .mark(.blue), .returnDie, .mark(.yellow), .mark(.green), .mark(.pink),
    ]
    /// FOUR COLUMN bonuses on the bottom edge, one per printed column, in
    /// grid order (matching `yellowColumns`):
    ///   col0 ([1,2])   → reroll        (⟳ icon)
    ///   col1 ([3,4,5]) → plusOne       (+1)
    ///   col2 ([2,5])   → mark(.silver) ("?" orange)
    ///   col3 ([6,3,4]) → fox           (🦊)
    public static let yellowColumnBonus: [Clever2Bonus] = [
        .reroll, .plusOne, .mark(.silver), .fox,
    ]

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
    /// Pad photo evidence (crop "green_final_check" / "pair45_wide" /
    /// "pair56_wide" / "green_tail"): reading the 8 printed badges left→right
    /// against the 6 pairs' completing cells (odd indices) gives reroll,
    /// mark(blue), returnDie, fox, mark(silver), plusOne, mark(pink),
    /// mark(yellow) — i.e. the ORIGINAL 7-entry dict (keys 1,3,4,6,7,10,11)
    /// plus ONE missing entry, `9: .mark(.silver)` (the orange "?" printed
    /// between the fox and the +1 — confirmed independently by the owner's
    /// annotation: an arrow + crossed-circle drawn exactly in that gap).
    public static let greenBonus: [Int: Clever2Bonus] = [
        1: .reroll, 3: .mark(.blue), 4: .returnDie, 6: .fox,
        9: .mark(.silver), 7: .plusOne, 10: .mark(.pink), 11: .mark(.yellow),
    ]
    public static let greenFoxPair = 3 // fox sits around the 4th pair

    // Pink: 12 cells, write any die value. Thresholds gate the bonus only.
    public static let pinkThresholds: [Int?] = [nil, nil, 2, 3, 4, 5, 6, 2, 3, 4, 5, 6]
    /// Pad photo evidence (crop "pink_ruler" / "pink_full_wide2" /
    /// "pink_cell9check"): 10 printed badges trail cells 1…10 (boundary
    /// calibrated against the blue row, whose badges were verified to match
    /// this app's EXISTING data exactly at cell-precision). The original
    /// 9-entry dict (keys 2,3,4,5,6,7,9,10,11) is missing ONE entry,
    /// `8: .mark(.silver)` (the orange "?" printed between the fox and the
    /// second reroll badge).
    public static let pinkBonus: [Int: Clever2Bonus] = [
        2: .reroll, 3: .returnDie, 4: .plusOne, 5: .mark(.green), 6: .mark(.yellow),
        7: .fox, 8: .mark(.silver), 9: .reroll, 10: .mark(.blue), 11: .mark(.yellow),
    ]
    public static let pinkFoxIndex = 7

    public static let roundBonuses: [Clever2Bonus?] = [.reroll, .plusOne, .returnDie, nil, nil, nil]
    /// Pad photo evidence (crops "tracks_wide" / "tracks_all3"): each action
    /// track prints SIX plain crossable circles, then a SEVENTH circle that is
    /// a distinct printed end-bonus badge (reroll → 🦊 fox, return → "?" on
    /// pink, +1 → "?" on silver) — not an eighth plain slot, and not an
    /// interactive slot at all. The count here is the CROSSABLE slots only;
    /// the end badge is rendered as separate chrome in `Clever2TracksBlock`.
    public static let rerollTrackSlots = 6
    public static let returnTrackSlots = 6
    public static let extraDieTrackSlots = 6
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
