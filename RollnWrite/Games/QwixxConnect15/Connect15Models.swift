//
//  Connect15Models.swift
//  RollnWrite – Qwixx Connect15
//
//  Value types for the Qwixx "Connect 15" variant (White Goblin Games, NSV).
//
//  Connect 15 plays like classic Qwixx — four colour rows (red/yellow 2→12,
//  green/blue 12→2, lock on the right-most number after ≥5 crosses), four
//  penalties — PLUS three "connection" fields woven into every colour row.
//  Whenever the dice show a 1 and a 5 (in any colour), every player may cross a
//  connection field of one row (which row depends on the dice used).
//
//  Numbers and connection fields form ONE left-to-right sequence per row:
//  crossing anything to the right of an unmarked space (number OR connection
//  field) forfeits that space — it can never be crossed later. At the end,
//  crossed connection fields count as ordinary crosses toward the row's total.
//  Because each row gains 3 connection fields on top of the 11 numbers + lock,
//  a row can reach 15 crosses (worth 120) — hence the name.
//
//  This module reuses `GameColor` and `ColorRow` from the base Qwixx module but
//  keeps its own engine + state so the base Qwixx engine stays untouched.
//

import Foundation

/// Positions of the printed "connection" fields, transcribed from the official
/// Connect 15 score sheet (corroborated against two published reviews). A
/// position is the 0-based number column index *after which* a connection field
/// is printed (red/yellow ascend: column `i` → number `i + 2`; green/blue
/// descend: column `i` → number `12 - i`). Every row has exactly three fields.
public enum Connect15Layout {
    /// Connection-field positions per colour, as "after this number column",
    /// left → right (so the array index is the field's 0-based ordinal).
    public static let connectionColumns: [GameColor: [Int]] = [
        .red:    [1, 4, 8],   // between 3–4, 6–7 and 10–11
        .yellow: [3, 5, 7],   // between 5–6, 7–8 and 9–10
        .green:  [2, 6, 8],   // between 10–9, 6–5 and 4–3
        .blue:   [1, 4, 7],   // between 11–10, 8–7 and 5–4
    ]

    /// The row's connection-field columns (always three; empty only if a colour
    /// were ever missing from the table).
    public static func columns(for color: GameColor) -> [Int] {
        connectionColumns[color] ?? []
    }

    // MARK: Interleaved left-to-right positions
    //
    // Numbers and connection fields share one sequence: the number at column j
    // sits at position j, the connection field after column i at position
    // i + 0.5. To stay in integer maths both are doubled: number → 2·j,
    // connection field → 2·i + 1. A mark is legal only if its position exceeds
    // the row's highest marked position — forfeiture of skipped spaces
    // (numbers *and* connection fields) then falls out for free.

    /// Interleaved position of the number at `column` (doubled: 2·column).
    public static func numberPosition(column: Int) -> Int { 2 * column }

    /// Interleaved position of the connection field printed after `column`
    /// (doubled: 2·column + 1, i.e. "column + 0.5").
    public static func connectionPosition(afterColumn column: Int) -> Int { 2 * column + 1 }
}

/// The three "connection" fields woven into a single colour row. Connection
/// fields carry no printed number; each sits between two specific adjacent
/// numbers (`Connect15Layout.connectionColumns`) and takes part in the row's
/// single left-to-right sequence, so any individual field may be crossed or
/// forfeited — a per-field marked set is required (a count is not enough).
public struct ConnectionFields: Codable, Equatable {
    /// How many connection fields each colour row has (3 → 12 + 3 = 15 crosses).
    public static let capacity = 3

    /// Marked field ordinals (0…`capacity`-1, left → right). The field's board
    /// position comes from `Connect15Layout.columns(for:)[ordinal]`.
    public var marks: Set<Int> = []

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case marks
        /// Legacy key: earlier builds stored only a left-to-right count.
        case crossed
    }

    // Tolerant decode: current saves store the marked-field set; older saves
    // stored a count `N`, which is migrated to the first N field ordinals (the
    // best approximation — the score is identical, only which printed square
    // shows the ✗ may differ). Never throws on a missing key.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let set = try c.decodeIfPresent(Set<Int>.self, forKey: .marks) {
            marks = Set(set.filter { (0..<ConnectionFields.capacity).contains($0) })
        } else if let legacyCount = try c.decodeIfPresent(Int.self, forKey: .crossed) {
            marks = Set(0..<max(0, min(legacyCount, ConnectionFields.capacity)))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(marks, forKey: .marks)
    }
}

/// A reversible user action, recorded so `undo()` is exact and LIFO.
public enum Connect15Action: Codable {
    case color(GameColor, index: Int, didLock: Bool)
    /// Crossed the connection field with 0-based ordinal `field` in `color`.
    case connection(GameColor, field: Int)
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
        // `try?`: legacy histories encoded `.connection` without a field
        // ordinal and cannot be replayed exactly, so an undecodable history is
        // dropped (undo simply starts empty; the board state itself survives).
        history = (try? c.decodeIfPresent([Connect15Action].self, forKey: .history)) ?? []
    }
}
