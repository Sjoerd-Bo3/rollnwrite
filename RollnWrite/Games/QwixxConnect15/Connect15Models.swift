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

/// The three "connection" fields woven into a single colour row. Connection
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
    public var history: [Connect15Action] = []

    public init() {}

    /// Maximum penalties allowed (the 4th ends the game).
    public static let maxPenalties = 4
}
