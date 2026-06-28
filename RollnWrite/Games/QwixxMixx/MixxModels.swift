//
//  MixxModels.swift
//  RollnWrite – Qwixx Mixx
//
//  Value types for the Qwixx "gemixxt" (Mixx) variant (NSV / White Goblin
//  Games, art. 4033). Mixx ships TWO boards:
//
//  • Variante A — the four rows still run ascending (2→12) / descending (12→2)
//    exactly like the original, BUT every row is split into small *colour
//    segments*: each individual number cell belongs to one of the four die
//    colours. You cross a cell with the matching coloured die (or the two white
//    dice). The row's own colour (its lock) determines which coloured die is
//    removed from the game when that row is closed.
//
//  • Variante B — there is still one row per die colour (red/yellow/green/blue),
//    but the eleven numbers inside each row are no longer ordered — they are
//    scattered "wild". You still cross strictly left → right, and to cross a
//    number you must roll it with that row's coloured die (or the white dice).
//
//  Both boards score *identically* to classic Qwixx: per row, the count of
//  crosses (own numbers + lock) maps through the triangular scale capped at 12
//  (1,3,6,…,78); four failed-throw penalties of −5 each; the game ends when two
//  rows are locked or the 4th penalty is taken. The variant-specific element is
//  the printed *layout* (segment colours in A, scrambled numbers in B) and the
//  "closing a row removes that coloured die" interaction. As a single-player
//  scorecard each row is enforced exactly like classic Qwixx (left-to-right,
//  lock only after ≥5 earlier crosses); the removed-die interaction is a
//  multiplayer table rule that does not change one player's own scoring.
//
//  This module reuses `GameColor` and `ColorRow` from the base Qwixx module but
//  keeps its own engine + state so the base Qwixx engine stays untouched.
//
//  Layout data below is transcribed cell-by-cell from the official score sheet.
//

import Foundation

/// Which of the two Mixx boards is in play.
public enum MixxBoard: String, Codable, CaseIterable, Identifiable {
    case variantA
    case variantB

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .variantA: return "A"
        case .variantB: return "B"
        }
    }

    public var displayName: String {
        switch self {
        case .variantA: return "Variant A"
        case .variantB: return "Variant B"
        }
    }
}

/// One printed cell on a Mixx row: the number shown, and the die colour of its
/// little segment (Variant A) — in Variant B every cell carries the row colour.
public struct MixxCell: Equatable {
    /// The number printed in the cell (2…12).
    public let number: Int
    /// The die colour of this cell's segment.
    public let color: GameColor

    public init(number: Int, color: GameColor) {
        self.number = number
        self.color = color
    }
}

/// A printed row of a Mixx board: its 11 cells (left → right) plus the colour of
/// the lock at the right end (the die removed from play when the row is closed).
public struct MixxRowLayout: Equatable {
    /// The lock colour = the die taken out of the game when this row is closed.
    public let lockColor: GameColor
    /// The 11 cells, left → right (index 0…10; index 10 locks the row).
    public let cells: [MixxCell]

    public init(lockColor: GameColor, cells: [MixxCell]) {
        precondition(cells.count == 11, "Mixx rows must have exactly 11 cells")
        self.lockColor = lockColor
        self.cells = cells
    }
}

/// The exact, transcribed-from-the-sheet layout of both Mixx boards.
public enum MixxLayout {

    /// Variante A — numbers ascending/descending like the original, rows split
    /// into colour segments. Lock colour = the row's own band colour.
    ///
    /// Row 1 (red lock, 2→12): yellow 2·3·4 | blue 5·6·7 | green 8·9·10 | red 11·12
    /// Row 2 (yellow lock, 2→12): red 2·3 | green 4·5·6·7 | blue 8·9 | yellow 10·11·12
    /// Row 3 (green lock, 12→2): blue 12·11·10 | yellow 9·8·7 | red 6·5·4 | green 3·2
    /// Row 4 (blue lock, 12→2): green 12·11 | red 10·9·8·7 | yellow 6·5 | blue 4·3·2
    public static let variantA: [MixxRowLayout] = [
        MixxRowLayout(lockColor: .red, cells: [
            MixxCell(number: 2, color: .yellow),
            MixxCell(number: 3, color: .yellow),
            MixxCell(number: 4, color: .yellow),
            MixxCell(number: 5, color: .blue),
            MixxCell(number: 6, color: .blue),
            MixxCell(number: 7, color: .blue),
            MixxCell(number: 8, color: .green),
            MixxCell(number: 9, color: .green),
            MixxCell(number: 10, color: .green),
            MixxCell(number: 11, color: .red),
            MixxCell(number: 12, color: .red),
        ]),
        MixxRowLayout(lockColor: .yellow, cells: [
            MixxCell(number: 2, color: .red),
            MixxCell(number: 3, color: .red),
            MixxCell(number: 4, color: .green),
            MixxCell(number: 5, color: .green),
            MixxCell(number: 6, color: .green),
            MixxCell(number: 7, color: .green),
            MixxCell(number: 8, color: .blue),
            MixxCell(number: 9, color: .blue),
            MixxCell(number: 10, color: .yellow),
            MixxCell(number: 11, color: .yellow),
            MixxCell(number: 12, color: .yellow),
        ]),
        MixxRowLayout(lockColor: .green, cells: [
            MixxCell(number: 12, color: .blue),
            MixxCell(number: 11, color: .blue),
            MixxCell(number: 10, color: .blue),
            MixxCell(number: 9, color: .yellow),
            MixxCell(number: 8, color: .yellow),
            MixxCell(number: 7, color: .yellow),
            MixxCell(number: 6, color: .red),
            MixxCell(number: 5, color: .red),
            MixxCell(number: 4, color: .red),
            MixxCell(number: 3, color: .green),
            MixxCell(number: 2, color: .green),
        ]),
        MixxRowLayout(lockColor: .blue, cells: [
            MixxCell(number: 12, color: .green),
            MixxCell(number: 11, color: .green),
            MixxCell(number: 10, color: .red),
            MixxCell(number: 9, color: .red),
            MixxCell(number: 8, color: .red),
            MixxCell(number: 7, color: .red),
            MixxCell(number: 6, color: .yellow),
            MixxCell(number: 5, color: .yellow),
            MixxCell(number: 4, color: .blue),
            MixxCell(number: 3, color: .blue),
            MixxCell(number: 2, color: .blue),
        ]),
    ]

    /// Variante B — one row per die colour, numbers scrambled. Every cell carries
    /// the row colour; the lock colour is that same colour.
    ///
    /// Red:    10 6 2 8 3 4 12 5 9 7 11
    /// Yellow:  9 12 4 6 7 2 5 8 11 3 10
    /// Green:   8 2 10 12 6 9 7 4 5 11 3
    /// Blue:    5 7 11 9 12 3 8 10 2 6 4
    public static let variantB: [MixxRowLayout] = [
        row(.red, [10, 6, 2, 8, 3, 4, 12, 5, 9, 7, 11]),
        row(.yellow, [9, 12, 4, 6, 7, 2, 5, 8, 11, 3, 10]),
        row(.green, [8, 2, 10, 12, 6, 9, 7, 4, 5, 11, 3]),
        row(.blue, [5, 7, 11, 9, 12, 3, 8, 10, 2, 6, 4]),
    ]

    /// Builds a single-colour row for Variant B.
    private static func row(_ color: GameColor, _ numbers: [Int]) -> MixxRowLayout {
        MixxRowLayout(lockColor: color, cells: numbers.map { MixxCell(number: $0, color: color) })
    }

    /// The four row layouts for a given board.
    public static func rows(for board: MixxBoard) -> [MixxRowLayout] {
        switch board {
        case .variantA: return variantA
        case .variantB: return variantB
        }
    }
}

/// State of one Mixx row. Left-to-right marking; index 10 is the lock cell.
public struct MixxRow: Codable, Equatable {
    /// Crossed cell indices (0…10).
    public var marks: Set<Int> = []
    /// `true` once the right-most cell (index 10) has been crossed.
    public var locked: Bool = false

    /// Index of the lock cell (right-most).
    public static let lockIndex = 10

    public init() {}

    /// Highest crossed index, or -1 if none — used for the left-to-right rule.
    public var maxMarkedIndex: Int { marks.max() ?? -1 }

    /// Crosses that count for scoring: marked numbers plus the lock bonus cross.
    public var scoringCrosses: Int { marks.count + (locked ? 1 : 0) }
}

/// A reversible user action, recorded so `undo()` is exact and strictly LIFO.
public enum MixxAction: Codable {
    case mark(row: Int, index: Int, didLock: Bool)
    case penalty
}

/// Full serialisable snapshot of a Mixx game on one board.
public struct MixxState: Codable {
    /// The four rows, indexed 0…3 in printed top-to-bottom order.
    public var rows: [MixxRow] = [MixxRow(), MixxRow(), MixxRow(), MixxRow()]
    public var penalties = 0
    public var history: [MixxAction] = []

    public init() {}

    /// Maximum penalties allowed (the 4th ends the game).
    public static let maxPenalties = 4
}
