//
//  Lucky15Models.swift
//  RollnWrite – Qwixx Lucky15
//
//  Value types for the Qwixx "Lucky 15" variant (White Goblin Games, NSV).
//
//  Lucky15 plays like classic Qwixx — four colour rows (red/yellow 2→12,
//  green/blue 12→2, lock on the right-most number after ≥5 crosses), four
//  penalties — PLUS an extra orange "Lucky 15" track. Whenever you would roll
//  exactly 15 with both white dice + one coloured die, instead of marking a
//  colour you may cross the next field of the Lucky 15 track. The track's fields
//  are scored progressively: your Lucky 15 bonus equals the value of the
//  *highest* (right-most) field you have crossed.
//
//  This module reuses `GameColor` and `ColorRow` from the base Qwixx module but
//  keeps its own engine + state so the base Qwixx engine stays untouched.
//

import Foundation

/// The orange "Lucky 15" track: four diamond fields, crossed left → right, each
/// worth more than the last. Values verified against a photo of the physical
/// scorepad (5, 11, 18, 25) — a published review claiming 36 was wrong.
public struct Lucky15Track: Codable, Equatable {
    /// Printed point values of the diamond fields, left → right.
    public static let values = [5, 11, 18, 25]

    /// Number of fields crossed so far (0…`values.count`). Because the track is
    /// strictly left-to-right, a simple count fully describes its state.
    public var crossed: Int = 0

    public init() {}

    /// How many fields exist on the track.
    public var capacity: Int { Lucky15Track.values.count }

    /// Whether another field can still be crossed.
    public var hasRoomLeft: Bool { crossed < capacity }

    /// The Lucky 15 bonus = the value of the highest crossed field, or 0 if none.
    public var points: Int {
        guard crossed > 0 else { return 0 }
        return Lucky15Track.values[crossed - 1]
    }
}

/// A reversible user action, recorded so `undo()` is exact and LIFO.
public enum Lucky15Action: Codable {
    case color(GameColor, index: Int, didLock: Bool)
    case lucky15
    case penalty
    /// Conceded a colour (closed the row for free after another player locked it).
    case concede(GameColor)
    /// Ended the game manually.
    case finish
}

/// Full serialisable snapshot of a Lucky15 game (persisted to `UserDefaults`).
public struct Lucky15State: Codable {
    public var red = ColorRow(color: .red)
    public var yellow = ColorRow(color: .yellow)
    public var green = ColorRow(color: .green)
    public var blue = ColorRow(color: .blue)
    public var lucky = Lucky15Track()
    public var penalties = 0
    /// Set when the player ends the game manually (e.g. another player crossed
    /// the final lock).
    public var manuallyFinished = false
    public var history: [Lucky15Action] = []

    public init() {}

    /// Maximum penalties allowed (the 4th ends the game).
    public static let maxPenalties = 4

    private enum CodingKeys: String, CodingKey {
        case red, yellow, green, blue, lucky
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
        lucky = try c.decodeIfPresent(Lucky15Track.self, forKey: .lucky) ?? Lucky15Track()
        penalties = try c.decodeIfPresent(Int.self, forKey: .penalties) ?? 0
        manuallyFinished = try c.decodeIfPresent(Bool.self, forKey: .manuallyFinished) ?? false
        history = try c.decodeIfPresent([Lucky15Action].self, forKey: .history) ?? []
    }
}
