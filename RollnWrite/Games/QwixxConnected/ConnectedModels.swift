//
//  ConnectedModels.swift
//  RollnWrite – Qwixx Connected
//
//  Value types for the Qwixx "Connected" variant — specifically the *Chain*
//  ("Die Kette", Variant B) score sheet, version A (NSV "Qwixx connected",
//  art. 088 19900030). The supplied score sheet (corner marked "A") is this
//  Chain layout.
//
//  Connected (The Chain) plays exactly like classic Qwixx — four colour rows
//  (red/yellow 2→12, green/blue 12→2, lock on the right-most number after ≥5
//  crosses), four penalties — PLUS several printed *chain* fields. Certain
//  spaces are circled and joined in pairs by a printed line (e.g. red 6 ↔
//  yellow 6, yellow 3 ↔ green 11). Whenever a player crosses one circled chain
//  field they MUST automatically also cross its partner. Per the official rules
//  this automatic co-mark "happens always and at any point in the game", does
//  not obey the normal marking rules, and applies even if the partner row is
//  already locked. The four colour rows are scored unchanged — the automatically
//  crossed partner simply counts as one more cross in its own row.
//
//  This module reuses `GameColor` and `ColorRow` from the base Qwixx module but
//  keeps its own engine + state so the base Qwixx engine stays untouched.
//

import Foundation

/// One end of a printed chain: a circled space identified by colour + the
/// 0-based column index (0…10) of the number it sits on.
public struct ChainEnd: Codable, Equatable, Hashable {
    public let color: GameColor
    public let index: Int

    public init(_ color: GameColor, _ index: Int) {
        self.color = color
        self.index = index
    }
}

/// A printed chain links two circled spaces in vertically-adjacent rows.
public struct Chain: Codable, Equatable {
    public let a: ChainEnd
    public let b: ChainEnd

    public init(_ a: ChainEnd, _ b: ChainEnd) {
        self.a = a
        self.b = b
    }

    /// Given one end, return the partner end (or nil if `end` isn't part of it).
    public func partner(of end: ChainEnd) -> ChainEnd? {
        if end == a { return b }
        if end == b { return a }
        return nil
    }

    public func contains(_ end: ChainEnd) -> Bool { end == a || end == b }
}

/// The printed chains of version **A**, transcribed exactly from the official
/// "Qwixx connected" score sheet (Chain variant). Each pair sits in the *same
/// column* — the number indices line up because red/yellow ascend (column *i* →
/// number `i + 2`) and green/blue descend (column *i* → number `12 - i`):
///
///   • red 6  ↔ yellow 6   (column index 4)
///   • red 11 ↔ yellow 11  (column index 9)
///   • yellow 3  ↔ green 11 (column index 1)
///   • yellow 8  ↔ green 6  (column index 6)
///   • green 9 ↔ blue 9    (column index 3)
///   • green 4 ↔ blue 4    (column index 8)
///
/// No space belongs to more than one chain, so an automatic co-mark never
/// cascades into a third field.
public enum ConnectedLayout {
    public static let chains: [Chain] = [
        Chain(ChainEnd(.red, 4),    ChainEnd(.yellow, 4)),   // red 6  ↔ yellow 6
        Chain(ChainEnd(.red, 9),    ChainEnd(.yellow, 9)),   // red 11 ↔ yellow 11
        Chain(ChainEnd(.yellow, 1), ChainEnd(.green, 1)),    // yellow 3 ↔ green 11
        Chain(ChainEnd(.yellow, 6), ChainEnd(.green, 6)),    // yellow 8 ↔ green 6
        Chain(ChainEnd(.green, 3),  ChainEnd(.blue, 3)),     // green 9 ↔ blue 9
        Chain(ChainEnd(.green, 8),  ChainEnd(.blue, 8)),     // green 4 ↔ blue 4
    ]

    /// The chain containing `end`, if any.
    public static func chain(for end: ChainEnd) -> Chain? {
        chains.first { $0.contains(end) }
    }

    /// The partner space of `(color, index)` on its chain, if it is a chain end.
    public static func partner(of color: GameColor, _ index: Int) -> ChainEnd? {
        let end = ChainEnd(color, index)
        return chain(for: end)?.partner(of: end)
    }

    /// Whether the given colour/index is a circled chain space.
    public static func isChainSpace(_ color: GameColor, _ index: Int) -> Bool {
        chain(for: ChainEnd(color, index)) != nil
    }
}

/// A reversible user action, recorded so `undo()` is exact and LIFO.
///
/// When a deliberate colour mark triggers an automatic partner cross, the
/// partner space — and whether marking it was a *new* mark — is recorded inline
/// so a single undo removes both crosses together. (If the partner was already
/// crossed, `auto` is nil so undo leaves it alone.)
public enum ConnectedAction: Codable {
    case color(GameColor, index: Int, didLock: Bool, auto: ChainEnd?)
    case penalty
}

/// Full serialisable snapshot of a Connected game (persisted to `UserDefaults`).
public struct ConnectedState: Codable {
    public var red = ColorRow(color: .red)
    public var yellow = ColorRow(color: .yellow)
    public var green = ColorRow(color: .green)
    public var blue = ColorRow(color: .blue)
    public var penalties = 0
    public var history: [ConnectedAction] = []

    public init() {}

    /// Maximum penalties allowed (the 4th ends the game).
    public static let maxPenalties = 4
}
