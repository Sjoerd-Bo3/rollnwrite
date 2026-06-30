//
//  XChangeModels.swift
//  RollnWrite – Qwixx X-Change
//
//  Value types for the Qwixx "X-Change" variant (NSV / White Goblin Games,
//  art. 4290).
//
//  X-Change plays exactly like classic Qwixx — four colour rows (red/yellow
//  2→12, green/blue 12→2, lock on the right-most number after ≥5 crosses), four
//  −5 penalties — PLUS an extra "X-Change" row of nine diamond fields. Each
//  diamond shows two numbers and a double-arrow: when the active player calls the
//  white-dice sum you may cross the next X-Change field whose TOP number equals
//  that sum and "exchange" it for the field's BOTTOM number (or vice-versa),
//  then use the swapped value as if it were the white-dice sum to mark a colour.
//
//  The X-Change row is crossed strictly left → right; you may skip fields, but
//  skipped fields are lost for the rest of the game (identical to a colour row).
//
//  IMPORTANT — scoring: the X-Change row itself scores NO points. The printed
//  "X / Points" table (1×=1 … 12×=78) is the standard Qwixx colour-row reference;
//  the Total line on the official sheet is red + yellow + green + blue − penalties
//  with no box for the X-Change row. The X-Change diamonds are purely a tool that
//  buys you extra colour marks. (See the assumption note in the game definition.)
//
//  This module reuses `GameColor` and `ColorRow` from the base Qwixx module but
//  keeps its own engine + state so the base Qwixx engine stays untouched.
//

import Foundation

/// The "X-Change" row: nine diamond fields, each a (top, bottom) number pair.
/// Crossed strictly left → right (skipping allowed, skipped fields lost). The row
/// scores no points — it is a swap tool — so its state is just the set of crossed
/// field indices plus the printed pairs (the source of truth, read from the
/// official NSV Qwixx X-Change scoresheet PDF).
public struct XChangeRow: Codable, Equatable {
    /// Printed (top, bottom) number pairs, left → right, from the official NSV
    /// Qwixx X-Change scoresheet (QwixxXChange_EN.pdf).
    public static let pairs: [[Int]] = [
        [8, 5], [9, 7], [11, 3], [7, 4], [10, 3], [8, 6], [10, 5], [11, 9], [6, 4],
    ]

    /// Indices (0…8) of crossed diamond fields.
    public var marks: Set<Int> = []

    public init() {}

    /// How many diamond fields exist.
    public static var count: Int { pairs.count }

    /// Highest crossed index, or -1 if none — used for the left-to-right rule.
    public var maxMarkedIndex: Int { marks.max() ?? -1 }

    /// Number of X-Change fields crossed (informational only — no points).
    public var crossed: Int { marks.count }

    /// The two numbers of field `index` as a convenience tuple.
    public static func pair(_ index: Int) -> (top: Int, bottom: Int) {
        let p = pairs[index]
        return (p[0], p[1])
    }
}

/// A reversible user action, recorded so `undo()` is exact and LIFO.
public enum XChangeAction: Codable {
    case color(GameColor, index: Int, didLock: Bool)
    case xchange(index: Int)
    case penalty
    /// Conceded a colour (closed the row for free after another player locked it).
    case concede(GameColor)
    /// Ended the game manually.
    case finish
}

/// Full serialisable snapshot of an X-Change game (persisted to `UserDefaults`).
public struct XChangeState: Codable {
    public var red = ColorRow(color: .red)
    public var yellow = ColorRow(color: .yellow)
    public var green = ColorRow(color: .green)
    public var blue = ColorRow(color: .blue)
    public var xchange = XChangeRow()
    public var penalties = 0
    /// Set when the player ends the game manually (e.g. another player crossed
    /// the final lock).
    public var manuallyFinished = false
    public var history: [XChangeAction] = []

    public init() {}

    /// Maximum penalties allowed (the 4th ends the game).
    public static let maxPenalties = 4

    private enum CodingKeys: String, CodingKey {
        case red, yellow, green, blue, xchange
        case penalties, manuallyFinished, history
    }

    // Tolerant decode so saved games from earlier builds (which lack newer
    // fields like `manuallyFinished`) still load instead of resetting.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        red = try c.decodeIfPresent(ColorRow.self, forKey: .red) ?? ColorRow(color: .red)
        yellow = try c.decodeIfPresent(ColorRow.self, forKey: .yellow) ?? ColorRow(color: .yellow)
        green = try c.decodeIfPresent(ColorRow.self, forKey: .green) ?? ColorRow(color: .green)
        blue = try c.decodeIfPresent(ColorRow.self, forKey: .blue) ?? ColorRow(color: .blue)
        xchange = try c.decodeIfPresent(XChangeRow.self, forKey: .xchange) ?? XChangeRow()
        penalties = try c.decodeIfPresent(Int.self, forKey: .penalties) ?? 0
        manuallyFinished = try c.decodeIfPresent(Bool.self, forKey: .manuallyFinished) ?? false
        history = try c.decodeIfPresent([XChangeAction].self, forKey: .history) ?? []
    }
}
