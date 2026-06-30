//
//  Connect15Models.swift
//  RollnWrite – Qwixx Connect15
//
//  Value types for the Qwixx "Connect 15" variant (White Goblin Games, NSV).
//
//  Connect 15 plays like classic Qwixx — four colour rows (red/yellow 2→12,
//  green/blue 12→2, lock on the right-most number after ≥5 crosses), four
//  penalties — PLUS three extra "connection" fields woven into every colour row.
//  Whenever the dice show a 1 and a 5 (in any colour), every player may cross the
//  next free connection field of one row (which row depends on the dice used).
//
//  Connection fields are crossed strictly left → right, may be skipped (never
//  returned to), and at the end count as ordinary crosses toward that row's
//  total. Because each row gains 3 connection fields on top of the 11 numbers +
//  lock, a row can reach 15 crosses (worth 120) — hence the name.
//
//  This module reuses `GameColor` and `ColorRow` from the base Qwixx module but
//  keeps its own engine + state so the base Qwixx engine stays untouched.
//

import Foundation

/// Positions of the printed "connection" fields, transcribed from the official
/// Connect 15 score sheet. A position is the 0-based number column index *after
/// which* a connection field is printed (red/yellow ascend: column `i` → number
/// `i + 2`; green/blue descend: column `i` → number `12 - i`).
///
/// Verified from the sheet image:
///   • red:    one field, between 3 and 4            → after column 1
///   • yellow: two fields, between 5–6 and 7–8       → after columns 3 and 5
///   • green:  one field, between 10 and 9           → after column 0
///   • blue:   not legible on the supplied photo (the row's right end, where its
///             connection field(s) sit, is occluded by the scoring table)
///
/// NOTE: the supplied sheet shows the connection fields woven between specific
/// numbers and with a *different count per row* — not the uniform three-at-the-
/// end assumption the renderer originally used. Scoring is position-independent
/// (a crossed connection field is just one more cross toward the row's cap of
/// 15), so the engine stays count-based; this table documents the true print
/// layout for the view.
public enum Connect15Layout {
    /// Connection-field positions per colour, as "after this number column".
    public static let connectionColumns: [GameColor: [Int]] = [
        .red:    [1],          // between 3 and 4
        .yellow: [3, 5],       // between 5–6 and 7–8
        .green:  [0],          // between 10 and 9
        .blue:   [],           // TODO verify: blue's connection field(s) are occluded on the photo
    ]
}

/// The "connection" fields woven into a single colour row. Connection
/// fields carry no printed number; they are crossed left → right whenever the
/// dice form a "15" (a 1 and a 5), may be skipped, and add to the row's crosses.
///
/// Because the fields are crossed strictly left → right and may only be skipped
/// forward, a simple count fully describes their state.
public struct ConnectionFields: Codable, Equatable {
    /// How many connection fields each colour row has (3 → 12 + 3 = 15 crosses).
    public static let capacity = 3

    /// Number of connection fields crossed so far (0…`capacity`).
    public var crossed: Int = 0

    public init() {}

    /// Whether another connection field can still be crossed.
    public var hasRoomLeft: Bool { crossed < ConnectionFields.capacity }
}

/// A reversible user action, recorded so `undo()` is exact and LIFO.
public enum Connect15Action: Codable {
    case color(GameColor, index: Int, didLock: Bool)
    case connection(GameColor)
    case penalty
    /// Conceded a colour (closed the row for free after another player locked it).
    case concede(GameColor)
    /// Ended the game manually.
    case finish
}

/// Full serialisable snapshot of a Connect15 game (persisted to `UserDefaults`).
public struct Connect15State: Codable {
    public var red = ColorRow(color: .red)
    public var yellow = ColorRow(color: .yellow)
    public var green = ColorRow(color: .green)
    public var blue = ColorRow(color: .blue)
    public var redConnections = ConnectionFields()
    public var yellowConnections = ConnectionFields()
    public var greenConnections = ConnectionFields()
    public var blueConnections = ConnectionFields()
    public var penalties = 0
    /// Set when the player ends the game manually (e.g. another player crossed
    /// the final lock).
    public var manuallyFinished = false
    public var history: [Connect15Action] = []

    public init() {}

    /// Maximum penalties allowed (the 4th ends the game).
    public static let maxPenalties = 4

    private enum CodingKeys: String, CodingKey {
        case red, yellow, green, blue
        case redConnections, yellowConnections, greenConnections, blueConnections
        case penalties, manuallyFinished, history
    }

    // Tolerant decode so saved games from earlier builds (which lack newer
    // fields like `manuallyFinished`) still load instead of resetting. Swift's
    // synthesized decode throws on a missing key, so every stored field is
    // decoded with `decodeIfPresent(...) ?? default`.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        red = try c.decodeIfPresent(ColorRow.self, forKey: .red) ?? ColorRow(color: .red)
        yellow = try c.decodeIfPresent(ColorRow.self, forKey: .yellow) ?? ColorRow(color: .yellow)
        green = try c.decodeIfPresent(ColorRow.self, forKey: .green) ?? ColorRow(color: .green)
        blue = try c.decodeIfPresent(ColorRow.self, forKey: .blue) ?? ColorRow(color: .blue)
        redConnections = try c.decodeIfPresent(ConnectionFields.self, forKey: .redConnections) ?? ConnectionFields()
        yellowConnections = try c.decodeIfPresent(ConnectionFields.self, forKey: .yellowConnections) ?? ConnectionFields()
        greenConnections = try c.decodeIfPresent(ConnectionFields.self, forKey: .greenConnections) ?? ConnectionFields()
        blueConnections = try c.decodeIfPresent(ConnectionFields.self, forKey: .blueConnections) ?? ConnectionFields()
        penalties = try c.decodeIfPresent(Int.self, forKey: .penalties) ?? 0
        manuallyFinished = try c.decodeIfPresent(Bool.self, forKey: .manuallyFinished) ?? false
        history = try c.decodeIfPresent([Connect15Action].self, forKey: .history) ?? []
    }
}
