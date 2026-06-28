//
//  BonusModels.swift
//  RollnWrite – Qwixx Bonus
//
//  Value types for the Qwixx "Bonus" variant, version A (NSV / White Goblin
//  Games, art. 4105).
//
//  Version A plays like classic Qwixx — four colour rows (red/yellow 2→12,
//  green/blue 12→2, lock on the right-most number after ≥5 crosses), four
//  penalties — PLUS a twist: twelve specific numbers across the four rows are
//  printed inside a black "bonus" box. Whenever you cross out one of those boxed
//  numbers you immediately cross off the left-most free field of the BONUS BAR
//  at the bottom of the sheet. Every bonus-bar field shows a colour; crossing it
//  lets you immediately make one extra cross in that colour row (the next legal
//  number). That extra cross may itself land on a boxed number, so chains can
//  form. The bonus bar awards no points of its own — version A scores exactly
//  like classic Qwixx; the bar simply lets you fill rows faster.
//
//  This module reuses `GameColor` and `ColorRow` from the base Qwixx module but
//  keeps its own engine + state so the base Qwixx engine stays untouched.
//

import Foundation

/// Static layout of version A: which numbers are "boxed" (bonus) in each row,
/// and the colour reward of each field on the bonus bar.
///
/// Transcribed from the official score sheet (NSV art. 4105). Boxed numbers are
/// expressed as the *printed value* of the number; the engine maps them to the
/// column index of each colour via `GameColor.numbers`.
public enum BonusLayout {

    /// The three boxed (bonus) numbers in each colour row, by printed value.
    /// Red & yellow ascend 2→12; green & blue descend 12→2 (printed order does
    /// not matter here — these are matched by value).
    public static func boxedNumbers(for color: GameColor) -> [Int] {
        switch color {
        case .red:    return [3, 6, 9]
        case .yellow: return [5, 8, 11]
        case .green:  return [11, 7, 4]
        case .blue:   return [10, 8, 5]
        }
    }

    /// Whether the printed number `value` is a boxed bonus number in `color`.
    public static func isBoxed(_ color: GameColor, value: Int) -> Bool {
        boxedNumbers(for: color).contains(value)
    }

    /// Whether the cell at column `index` of `color` is a boxed bonus number.
    public static func isBoxedIndex(_ color: GameColor, index: Int) -> Bool {
        let value = color.numbers[index]
        return isBoxed(color, value: value)
    }

    /// The colour reward of each bonus-bar field, left → right. There are twelve
    /// fields — one for every boxed number on the sheet — so the bar can be
    /// filled exactly if every bonus number is eventually crossed.
    /// Corrected from the score-sheet image — the bar snakes:
    /// red, yellow, green, blue, green, red, blue, yellow, red, yellow, blue, green.
    public static let barColors: [GameColor] = [
        .red, .yellow, .green, .blue,
        .green, .red, .blue, .yellow,
        .red, .yellow, .blue, .green,
    ]

    /// Number of fields on the bonus bar.
    public static var barCount: Int { barColors.count }
}

/// The bonus bar: a left → right chain of coloured fields. A new field is
/// crossed automatically every time a boxed number is crossed; the colour of the
/// freshly crossed field tells the player which row earns the free extra cross.
public struct BonusBar: Codable, Equatable {
    /// How many fields have been crossed so far (0…`BonusLayout.barCount`).
    public var crossed: Int = 0

    public init() {}

    /// Whether another field can still be crossed.
    public var hasRoomLeft: Bool { crossed < BonusLayout.barCount }

    /// The colour reward of the most recently crossed field, or `nil` if none.
    public var lastRewardColor: GameColor? {
        guard crossed > 0 else { return nil }
        return BonusLayout.barColors[crossed - 1]
    }
}

/// A reversible user action, recorded so `undo()` is exact and strictly LIFO.
///
/// `advancedBar` records whether the colour mark also pushed the bonus bar on,
/// so undo reverses both halves atomically.
public enum BonusAction: Codable {
    case color(GameColor, index: Int, didLock: Bool, advancedBar: Bool)
    case penalty
}

/// Full serialisable snapshot of a Qwixx Bonus (version A) game.
public struct BonusState: Codable {
    public var red = ColorRow(color: .red)
    public var yellow = ColorRow(color: .yellow)
    public var green = ColorRow(color: .green)
    public var blue = ColorRow(color: .blue)
    public var bar = BonusBar()
    public var penalties = 0
    public var history: [BonusAction] = []

    public init() {}

    /// Maximum penalties allowed (the 4th ends the game).
    public static let maxPenalties = 4
}
