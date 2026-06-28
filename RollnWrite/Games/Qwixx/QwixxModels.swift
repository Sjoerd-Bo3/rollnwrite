//
//  QwixxModels.swift
//  RollnWrite – Qwixx
//
//  Value types describing the state of a Qwixx Big Points scorecard.
//  These are plain `Codable` structs (SRP: state only, no rules, no UI).
//

import Foundation

/// One coloured number row. 11 numbers at indices 0…10; index 10 is the
/// right-most number whose crossing locks the row.
public struct ColorRow: Codable, Equatable {
    public let color: GameColor
    /// Indices (0…10) that have been crossed out.
    public var marks: Set<Int> = []
    /// `true` once the right-most number has been crossed (row + lock).
    public var locked: Bool = false

    /// Index of the right-most number, whose crossing locks the row.
    public static let lockIndex = 10

    public init(color: GameColor) {
        self.color = color
    }

    /// Printed numbers in left-to-right order.
    public var numbers: [Int] { color.numbers }

    /// Highest crossed index, or -1 if none — used for the left-to-right rule.
    public var maxMarkedIndex: Int { marks.max() ?? -1 }

    /// Crosses that count for scoring: marked numbers plus the lock bonus cross.
    public var scoringCrosses: Int { marks.count + (locked ? 1 : 0) }
}

/// Identifies the two two-colour bonus rows of Big Points.
public enum BonusRowID: String, Codable, CaseIterable, Identifiable {
    case redYellow
    case greenBlue

    public var id: String { rawValue }

    /// The two colour rows this bonus row sits between / scores for.
    public var colors: (GameColor, GameColor) {
        switch self {
        case .redYellow: return (.red, .yellow)
        case .greenBlue: return (.green, .blue)
        }
    }
}

/// A bonus row of 11 two-colour spaces, aligned by number with its colour rows.
/// A space may be crossed only after an adjacent same-number colour space is
/// crossed; once crossed it counts for *both* adjacent colour rows.
public struct BonusRow: Codable, Equatable {
    public let id: BonusRowID
    public var marks: Set<Int> = []

    public init(id: BonusRowID) {
        self.id = id
    }

    /// Numbers follow the first adjacent colour's ordering (ascending for
    /// red/yellow, descending for green/blue) so columns line up by number.
    public var numbers: [Int] { id.colors.0.numbers }

    public var maxMarkedIndex: Int { marks.max() ?? -1 }
}

/// A reversible user action, recorded so `undo()` is exact and dependency-safe.
///
/// Undo is strictly LIFO, which guarantees a bonus space is always undone before
/// the colour space that authorised it.
public enum GameAction: Codable {
    case color(GameColor, index: Int, didLock: Bool)
    case bonus(BonusRowID, index: Int)
    case penalty
}

/// Full serialisable snapshot of a game (persisted to `UserDefaults`).
public struct QwixxState: Codable {
    public var red = ColorRow(color: .red)
    public var yellow = ColorRow(color: .yellow)
    public var green = ColorRow(color: .green)
    public var blue = ColorRow(color: .blue)
    public var redYellowBonus = BonusRow(id: .redYellow)
    public var greenBlueBonus = BonusRow(id: .greenBlue)
    public var penalties = 0
    public var history: [GameAction] = []

    public init() {}

    /// Maximum penalties allowed (the 4th ends the game).
    public static let maxPenalties = 4
}
