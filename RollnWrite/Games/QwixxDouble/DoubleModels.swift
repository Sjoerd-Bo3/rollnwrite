//
//  DoubleModels.swift
//  RollnWrite – Qwixx Double
//
//  Value types for the Qwixx "Double" variant (NSV / White Goblin Games),
//  implementing the printed **Variant A — "double crosses"** of the official
//  Qwixx Double rules sheet.
//
//  Qwixx Double plays exactly like classic Qwixx — four colour rows
//  (red/yellow 2→12, green/blue 12→2), four penalties — with two changes:
//
//    1. The space you **most recently crossed off** in a colour row can be
//       crossed off *again* (a second cross is drawn beneath it) whenever the
//       matching number comes up — whether you are the active player or not.
//       Only the single most-recent space is eligible; once you cross a *new*
//       number further to the right, the previous space can no longer be
//       doubled.
//    2. To cross one of the right-most numbers (12 for red/yellow, 2 for
//       green/blue) — which locks the row — you must already have at least
//       **7 crosses** in that row (versus 5 in classic Qwixx).
//
//  Up to 22 crosses are physically possible in a row (11 numbers × 2), but a row
//  scores a **maximum of 16 crosses** (triangular → 136 points). The cap is
//  enforced by the injected `TriangularScoring(cap: 16)`.
//
//  This module reuses `GameColor` from the base Qwixx module but keeps its own
//  state + engine so the base Qwixx engine stays untouched. (The base `ColorRow`
//  cannot represent a second cross, so rows are modelled here.)
//

import Foundation

/// One Qwixx Double colour row. 11 numbers at indices 0…10; index 10 is the
/// right-most number whose crossing locks the row.
///
/// Each number can be crossed **once or twice**. `marks` holds every index
/// crossed at least once (left-to-right, like classic Qwixx); `doubles` holds
/// indices crossed a *second* time. The variant only lets you double the
/// most-recently crossed space, so in practice only the current right-most mark
/// is ever doubled — but the full set is stored so undo and scoring stay exact.
public struct DoubleColorRow: Codable, Equatable {
    public let color: GameColor
    /// Indices (0…10) crossed at least once.
    public var marks: Set<Int> = []
    /// Indices (0…10) crossed a *second* time (always a subset of `marks`).
    public var doubles: Set<Int> = []
    /// `true` once the right-most number has been crossed (row + lock).
    public var locked: Bool = false

    /// Index of the right-most number, whose crossing locks the row.
    public static let lockIndex = 10
    /// Crosses required in the row before the right-most number may be crossed.
    public static let crossesToLock = 7

    public init(color: GameColor) {
        self.color = color
    }

    /// Printed numbers in left-to-right order.
    public var numbers: [Int] { color.numbers }

    /// Highest crossed index, or -1 if none — used both for the left-to-right
    /// rule and to identify the "most recently crossed" (right-most) space.
    public var maxMarkedIndex: Int { marks.max() ?? -1 }

    /// Total crosses written in the row: first crosses + second crosses, plus
    /// the lock bonus cross — but the lock bonus is earned only if YOU crossed
    /// the right-most number. A conceded row (closed because another player
    /// locked the colour) is `locked` yet scores no bonus, because its lock
    /// number was never crossed.
    public var crossCount: Int {
        marks.count + doubles.count + (marks.contains(DoubleColorRow.lockIndex) ? 1 : 0)
    }
}

/// A reversible user action, recorded so `undo()` is exact and strictly LIFO.
public enum DoubleAction: Codable {
    /// A *first* cross on `index` (may have locked the row).
    case mark(GameColor, index: Int, didLock: Bool)
    /// A *second* cross on the most-recent space `index`.
    case double(GameColor, index: Int)
    case penalty
    /// Conceded a colour (closed the row for free after another player locked it).
    case concede(GameColor)
    /// Ended the game manually.
    case finish
}

/// Full serialisable snapshot of a Qwixx Double game (persisted to `UserDefaults`).
public struct DoubleState: Codable {
    public var red = DoubleColorRow(color: .red)
    public var yellow = DoubleColorRow(color: .yellow)
    public var green = DoubleColorRow(color: .green)
    public var blue = DoubleColorRow(color: .blue)
    public var penalties = 0
    /// Set when the player ends the game manually (e.g. another player crossed
    /// the final lock).
    public var manuallyFinished = false
    public var history: [DoubleAction] = []

    public init() {}

    /// Maximum penalties allowed (the 4th ends the game).
    public static let maxPenalties = 4

    private enum CodingKeys: String, CodingKey {
        case red, yellow, green, blue
        case penalties, manuallyFinished, history
    }

    // Tolerant decode so saved games from earlier builds (which lack newer
    // fields like `manuallyFinished`) still load instead of resetting.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        red = try c.decodeIfPresent(DoubleColorRow.self, forKey: .red) ?? DoubleColorRow(color: .red)
        yellow = try c.decodeIfPresent(DoubleColorRow.self, forKey: .yellow) ?? DoubleColorRow(color: .yellow)
        green = try c.decodeIfPresent(DoubleColorRow.self, forKey: .green) ?? DoubleColorRow(color: .green)
        blue = try c.decodeIfPresent(DoubleColorRow.self, forKey: .blue) ?? DoubleColorRow(color: .blue)
        penalties = try c.decodeIfPresent(Int.self, forKey: .penalties) ?? 0
        manuallyFinished = try c.decodeIfPresent(Bool.self, forKey: .manuallyFinished) ?? false
        history = try c.decodeIfPresent([DoubleAction].self, forKey: .history) ?? []
    }
}
