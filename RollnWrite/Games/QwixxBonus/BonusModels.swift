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

/// The bonus bar: a left → right chain of coloured fields. A field is *earned*
/// automatically every time a boxed number is crossed; the colour of the freshly
/// earned field tells the player which row gets the free extra cross.
///
/// Official forfeit rule: once a colour has been completed (locked), all its
/// remaining fields in the bonus bar are immediately crossed out as *forfeited*.
/// They no longer count and are simply skipped — future earned crosses land on
/// the next non-forfeited free field, so every field is one of three states:
/// unearned, earned, or forfeited (modelled as two disjoint index sets).
public struct BonusBar: Codable, Equatable {
    /// Indices of fields crossed as earned rewards (each granted an extra cross).
    public var earned: Set<Int> = []
    /// Indices crossed out as forfeited because their colour row was completed.
    public var forfeited: Set<Int> = []

    public init() {}

    /// How many fields have been earned so far (drives reward/score bookkeeping).
    public var earnedCount: Int { earned.count }

    /// The lowest-index field that is neither earned nor forfeited — the field
    /// the next boxed cross will earn — or `nil` if the bar is used up.
    public var nextEarnableIndex: Int? {
        (0..<BonusLayout.barCount).first { !earned.contains($0) && !forfeited.contains($0) }
    }

    /// Whether another field can still be earned.
    public var hasRoomLeft: Bool { nextEarnableIndex != nil }

    private enum CodingKeys: String, CodingKey {
        case earned, forfeited
        /// Legacy key: earlier builds stored the bar as a bare left-to-right count.
        case crossed
    }

    // Tolerant decode + migration: old saves encode `crossed: Int`. If the new
    // per-field sets are absent, the first N fields become earned (exactly what
    // a pure left-to-right count meant). Never throws on missing keys.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let e = try c.decodeIfPresent(Set<Int>.self, forKey: .earned) {
            earned = e
            forfeited = try c.decodeIfPresent(Set<Int>.self, forKey: .forfeited) ?? []
        } else if let count = try c.decodeIfPresent(Int.self, forKey: .crossed) {
            earned = Set(0..<min(max(count, 0), BonusLayout.barCount))
            forfeited = []
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(earned, forKey: .earned)
        try c.encode(forfeited, forKey: .forfeited)
    }
}

/// How a colour mark advanced the bonus bar, recorded in history for exact undo.
public enum BarAdvance: Codable, Equatable {
    /// The mark was not boxed (or the bar was used up) — nothing earned.
    case none
    /// The mark earned exactly this bar field (forfeited fields were skipped).
    case earned(Int)
    /// Decoded from a pre-forfeit save that only stored "the bar advanced".
    /// Back then the bar filled strictly left to right, so undo removes the
    /// highest earned index — exact for any state such a save can reach.
    case legacy
}

/// A reversible user action, recorded so `undo()` is exact and strictly LIFO.
///
/// The `bar` payload records which field the mark earned, and `forfeited` which
/// bar indices a locking action crossed out, so undo reverses the colour mark,
/// the bar advance and any forfeiture atomically.
///
/// Custom Codable: the wire format mirrors Swift's synthesized enum encoding
/// (case-name key + nested payload keys) so histories written by earlier builds
/// — which had an `advancedBar: Bool` instead of `bar`/`forfeited` — still
/// decode, and the format stays stable for future builds.
public enum BonusAction: Codable {
    case color(GameColor, index: Int, didLock: Bool, bar: BarAdvance, forfeited: [Int])
    case penalty
    /// Conceded a colour (closed the row for free after another player locked it).
    case concede(GameColor, forfeited: [Int])
    /// Ended the game manually.
    case finish

    private enum CodingKeys: String, CodingKey { case color, penalty, concede, finish }
    private enum ColorKeys: String, CodingKey {
        case color = "_0", index, didLock, bar, forfeited
        /// Legacy key from pre-forfeit builds.
        case advancedBar
    }
    private enum ConcedeKeys: String, CodingKey { case color = "_0", forfeited }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.color) {
            let n = try c.nestedContainer(keyedBy: ColorKeys.self, forKey: .color)
            let color = try n.decode(GameColor.self, forKey: .color)
            let index = try n.decodeIfPresent(Int.self, forKey: .index) ?? 0
            let didLock = try n.decodeIfPresent(Bool.self, forKey: .didLock) ?? false
            let bar: BarAdvance
            if let advance = try n.decodeIfPresent(BarAdvance.self, forKey: .bar) {
                bar = advance
            } else if try n.decodeIfPresent(Bool.self, forKey: .advancedBar) == true {
                bar = .legacy
            } else {
                bar = .none
            }
            let forfeited = try n.decodeIfPresent([Int].self, forKey: .forfeited) ?? []
            self = .color(color, index: index, didLock: didLock, bar: bar, forfeited: forfeited)
        } else if c.contains(.concede) {
            let n = try c.nestedContainer(keyedBy: ConcedeKeys.self, forKey: .concede)
            let color = try n.decode(GameColor.self, forKey: .color)
            let forfeited = try n.decodeIfPresent([Int].self, forKey: .forfeited) ?? []
            self = .concede(color, forfeited: forfeited)
        } else if c.contains(.penalty) {
            self = .penalty
        } else if c.contains(.finish) {
            self = .finish
        } else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Unknown BonusAction case"
            ))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .color(color, index, didLock, bar, forfeited):
            var n = c.nestedContainer(keyedBy: ColorKeys.self, forKey: .color)
            try n.encode(color, forKey: .color)
            try n.encode(index, forKey: .index)
            try n.encode(didLock, forKey: .didLock)
            try n.encode(bar, forKey: .bar)
            try n.encode(forfeited, forKey: .forfeited)
        case .penalty:
            _ = c.nestedContainer(keyedBy: ColorKeys.self, forKey: .penalty)
        case let .concede(color, forfeited):
            var n = c.nestedContainer(keyedBy: ConcedeKeys.self, forKey: .concede)
            try n.encode(color, forKey: .color)
            try n.encode(forfeited, forKey: .forfeited)
        case .finish:
            _ = c.nestedContainer(keyedBy: ColorKeys.self, forKey: .finish)
        }
    }
}

/// Full serialisable snapshot of a Qwixx Bonus (version A) game.
public struct BonusState: Codable {
    public var red = ColorRow(color: .red)
    public var yellow = ColorRow(color: .yellow)
    public var green = ColorRow(color: .green)
    public var blue = ColorRow(color: .blue)
    public var bar = BonusBar()
    public var penalties = 0
    /// Set when the player ends the game manually (e.g. another player crossed
    /// the final lock).
    public var manuallyFinished = false
    public var history: [BonusAction] = []

    public init() {}

    /// Maximum penalties allowed (the 4th ends the game).
    public static let maxPenalties = 4

    private enum CodingKeys: String, CodingKey {
        case red, yellow, green, blue, bar
        case penalties, manuallyFinished, history
    }

    // Tolerant decode so saved games from earlier builds (which lack newer
    // fields like `manuallyFinished`) still load instead of resetting. Swift's
    // synthesized decode throws on any missing key, so every stored field is
    // decoded with `decodeIfPresent(...) ?? default`.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        red = try c.decodeIfPresent(ColorRow.self, forKey: .red) ?? ColorRow(color: .red)
        yellow = try c.decodeIfPresent(ColorRow.self, forKey: .yellow) ?? ColorRow(color: .yellow)
        green = try c.decodeIfPresent(ColorRow.self, forKey: .green) ?? ColorRow(color: .green)
        blue = try c.decodeIfPresent(ColorRow.self, forKey: .blue) ?? ColorRow(color: .blue)
        bar = try c.decodeIfPresent(BonusBar.self, forKey: .bar) ?? BonusBar()
        penalties = try c.decodeIfPresent(Int.self, forKey: .penalties) ?? 0
        manuallyFinished = try c.decodeIfPresent(Bool.self, forKey: .manuallyFinished) ?? false
        history = try c.decodeIfPresent([BonusAction].self, forKey: .history) ?? []
    }
}
