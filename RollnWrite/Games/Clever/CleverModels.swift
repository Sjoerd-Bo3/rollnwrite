//
//  CleverModels.swift
//  RollnWrite – Clever
//
//  Value types + exact official layout data for "That's Pretty Clever"
//  (Ganz schön clever) by Wolfgang Warsch / Schmidt Spiele.
//
//  All layout constants below were transcribed from the official rulebook &
//  score sheet (Schmidt Spiele art. 88198). SRP: pure data + state, no rules.
//

import SwiftUI

// MARK: - Areas & colours

/// The five scoring areas. These are fixed *roles* (their scoring logic never
/// changes); the colour shown for each is resolved from the app-wide dice
/// palette (`DiceTheme`) by nearest-colour matching against `standardColor`.
public enum CleverArea: String, Codable, CaseIterable, Identifiable {
    case yellow, blue, green, orange, purple

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    /// The area's STANDARD colour as printed on the official card — the input
    /// to the app-wide `DiceTheme` nearest-colour matching, never shown as-is.
    public var standardColor: Color {
        switch self {
        case .yellow: return Color(red: 0.96, green: 0.80, blue: 0.10)
        case .blue:   return Color(red: 0.16, green: 0.45, blue: 0.82)
        case .green:  return Color(red: 0.18, green: 0.62, blue: 0.30)
        case .orange: return Color(red: 0.95, green: 0.52, blue: 0.10)
        case .purple: return Color(red: 0.55, green: 0.28, blue: 0.72)
        }
    }
}

// MARK: - Bonus icons (display-only reference; applied manually by the player)

/// Icons printed on the card for bonuses you earn. In the smart-scorecard model
/// the player applies these by tapping the granted box themselves, so these are
/// shown for reference and are not auto-redeemed (foxes are the exception and are
/// detected automatically — see `CleverGame`).
public enum BonusIcon: Equatable {
    case reroll
    case plusOne
    case mark(CleverArea)      // "X" → cross a box in this area
    case number(CleverArea, Int) // coloured number → write this number in that area
    case fox
    /// Round 4's printed badge: a generic (non-area) "✗ | 6" choice — cross
    /// any box OR write a 6, player's choice. Printed as two small circles
    /// side by side (both black, unlike `.mark`/`.number` which tint to an
    /// area), split by a thin divider. Layout/print data only — like every
    /// other `BonusIcon` case, it is a manual-apply bonus (see `CleverGame`
    /// and `CleverLayout.roundBonuses`, which still map round 4 to `nil` for
    /// the reroll/+1 derivations — this case never appears in that array).
    case crossOrSix
}

// MARK: - Fly-to-banner bonus events (presentation only; issue #54)

/// Identity of the printed bonus badge that fired — mirrors the positions of
/// `CleverGame`'s private `Trigger` so a view can locate the source badge on
/// the sheet for the "fly to banner" animation (issue #54). Presentation only.
public enum CleverBonusSource: Hashable {
    case yellowRow(Int)
    case yellowDiagonal
    case blueRow(Int)
    case blueColumn(Int)
    case greenCell(Int)
    case orangeCell(Int)
    case purpleCell(Int)
}

/// A bonus that was just earned — the payload of the fly-to-banner animation
/// (issue #54). Transient and presentation-only: NEVER persisted, NEVER part of
/// undo/redo. Emitted the moment a trigger completes; the view consumes and
/// clears it once the animation finishes.
public struct CleverBonusEvent: Identifiable, Equatable {
    public let id: UUID
    public let source: CleverBonusSource
    public let icon: BonusIcon
    /// Automatic bonuses (re-roll, +1, fox, auto green mark, auto orange/purple
    /// number) reach their destination with no player action; MANUAL ones — the
    /// free choice marks (`.mark(.yellow)` / `.mark(.blue)`) — need the player
    /// to pick a board target. Drives increment 3 (auto-fill vs highlight).
    public let isAutomatic: Bool

    public init(id: UUID = UUID(), source: CleverBonusSource, icon: BonusIcon, isAutomatic: Bool) {
        self.id = id
        self.source = source
        self.icon = icon
        self.isAutomatic = isAutomatic
    }
}

// MARK: - Exact official layout

public enum CleverLayout {
    // Yellow: 4×4 grid. nil = pre-printed free cross (the anti-diagonal).
    public static let yellowGrid: [Int?] = [
        3, 6, 5, nil,
        2, 1, nil, 5,
        1, nil, 2, 4,
        nil, 3, 4, 6,
    ]
    /// Numbered cell indices that make up each column (the free cell is excluded).
    public static let yellowColumns: [[Int]] = [
        [0, 4, 8],   // value 10
        [1, 5, 13],  // value 14
        [2, 10, 14], // value 16
        [7, 11, 15], // value 20
    ]
    public static let yellowColumnValues = [10, 14, 16, 20]
    /// Main-diagonal numbered cells (3,1,2,6) → +1 bonus when all crossed.
    public static let yellowDiagonal = [0, 5, 10, 15]
    /// Bottom row numbered cells (3,4,6) → fox when all crossed.
    public static let yellowFoxCells = [13, 14, 15]
    /// Row-end bonus per grid row (right of the grid).
    public static let yellowRowBonus: [BonusIcon] = [
        .mark(.blue), .number(.orange, 4), .mark(.green), .fox,
    ]

    // Blue: numbers 2…12 (11 cells). Grid display order (nil = the rule icon cell).
    public static let blueGrid: [Int?] = [
        nil, 2, 3, 4,
        5, 6, 7, 8,
        9, 10, 11, 12,
    ]
    public static let blueValues = Array(2...12)
    /// Points for the number of crossed blue cells (index = count).
    public static let bluePointScale = [0, 1, 2, 4, 7, 11, 16, 22, 29, 37, 46, 56]
    public static let blueFoxValues = [9, 10, 11, 12] // bottom row → fox
    public static let blueRowBonus: [BonusIcon] = [.number(.orange, 5), .mark(.yellow), .fox]
    public static let blueColBonus: [BonusIcon] = [.reroll, .mark(.green), .number(.purple, 6), .plusOne]

    // Green: 11 cells, marked left→right. Minimum die value shown per cell.
    public static let greenThresholds = [1, 2, 3, 4, 5, 1, 2, 3, 4, 5, 6]
    /// Points for the number of marked green cells (index = count - 1).
    public static let greenScale = [1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66]
    public static let greenFoxIndex = 6
    public static let greenBonus: [Int: BonusIcon] = [
        3: .plusOne, 5: .mark(.blue), 6: .fox, 8: .number(.purple, 6), 9: .reroll,
    ]

    // Orange: 11 cells, write die value (× multiplier).
    public static let orangeMultipliers = [1, 1, 1, 2, 1, 1, 2, 1, 2, 1, 3]
    public static let orangeFoxIndex = 7
    public static let orangeBonus: [Int: BonusIcon] = [
        2: .reroll, 4: .mark(.yellow), 5: .plusOne, 7: .fox, 9: .number(.purple, 6),
    ]

    // Purple: 11 cells, each value must exceed the previous (any value after a 6).
    public static let purpleFoxIndex = 5
    public static let purpleBonus: [Int: BonusIcon] = [
        1: .reroll, 2: .mark(.blue), 3: .plusOne, 4: .mark(.yellow), 5: .fox,
        6: .reroll, 7: .mark(.green), 8: .number(.orange, 6), 9: .plusOne,
    ]

    public static let rowLength = 11

    /// Start-of-round bonuses that feed the reroll/+1 earned counts (rounds
    /// 1–3 only; round 4's printed badge is `roundFourBonus` below — it is
    /// NEITHER a reroll NOR a +1, so it must stay `nil` here, or
    /// `CleverGame.roundGrantCount` would start counting it as one).
    public static let roundBonuses: [BonusIcon?] = [.reroll, .plusOne, .reroll, nil, nil, nil]
    /// Round 4's printed "✗ | 6" badge — a manual-apply choice bonus, kept
    /// OUT of `roundBonuses` on purpose (see above). Display-only, wired up by
    /// `cleverRoundBadge`.
    public static let roundFourBonus: BonusIcon = .crossOrSix
    public static let rerollTrackSlots = 7
    public static let extraDieTrackSlots = 7
}

// MARK: - State

/// Full serialisable snapshot of a Clever game.
public struct CleverState: Codable, Equatable {
    public var yellowCrossed: Set<Int> = []        // grid indices
    public var blueCrossed: Set<Int> = []          // values 2…12
    public var greenCount: Int = 0                  // 0…11
    public var orange: [Int?] = Array(repeating: nil, count: CleverLayout.rowLength)
    public var purple: [Int?] = Array(repeating: nil, count: CleverLayout.rowLength)
    public var rerollUsed: Set<Int> = []
    public var extraDieUsed: Set<Int> = []
    /// Rounds crossed off on the 1–6 bar (indices 0…5). Pure BOOKKEEPING, not
    /// a game move: it never enters `history` (see `CleverGame.toggleRound`).
    /// Crossing a round with a printed bonus feeds the reroll/+1 earned counts.
    public var roundsCrossed: Set<Int> = []
    /// Number of players chosen on "New game" when round management is on
    /// (issue #59). Drives the round count (1–2 → 6, 3 → 5, 4 → 4). `nil`
    /// means "not chosen" (round management off, or a pre-#59 save) — the
    /// rounds bar then falls back to the historical 6-round look.
    public var playerCount: Int?
    /// One snapshot captured each time a round is crossed on the bar (issue
    /// #59), in round order, so the UI can show what changed THAT round
    /// (delta vs. the previous snapshot). Pure derived BOOKKEEPING like
    /// `roundsCrossed` itself — never enters `history` — so un-crossing a
    /// round simply drops its snapshot (see `CleverGame.toggleRound`).
    public var roundSnapshots: [CleverRoundSnapshot] = []
    public var history: [CleverAction] = []
    /// Set by `CleverGame.finishGame()` (issue #57): the player has ended the
    /// game manually via the header's finish flag, independent of round
    /// management. Pure bookkeeping like `roundsCrossed` in spirit, but it
    /// DOES gate `isGameOver`, so it is a real stored field (not history).
    public var manuallyFinished = false
    // Note: older saves carry a per-game `theme` key; the decoder ignores it
    // (dice colours are an app-wide setting now — see `DiceTheme`).

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case yellowCrossed, blueCrossed, greenCount, orange, purple
        case rerollUsed, extraDieUsed, roundsCrossed, playerCount, roundSnapshots, history
        case manuallyFinished
    }

    // Tolerant decode so saved games from earlier builds (which lack newer
    // fields like `roundsCrossed`) still load instead of resetting. Swift's
    // synthesized decode throws on any missing key, so every stored field is
    // decoded with `decodeIfPresent(...) ?? default`.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        yellowCrossed = try c.decodeIfPresent(Set<Int>.self, forKey: .yellowCrossed) ?? []
        blueCrossed = try c.decodeIfPresent(Set<Int>.self, forKey: .blueCrossed) ?? []
        greenCount = try c.decodeIfPresent(Int.self, forKey: .greenCount) ?? 0
        orange = try c.decodeIfPresent([Int?].self, forKey: .orange)
            ?? Array(repeating: nil, count: CleverLayout.rowLength)
        purple = try c.decodeIfPresent([Int?].self, forKey: .purple)
            ?? Array(repeating: nil, count: CleverLayout.rowLength)
        rerollUsed = try c.decodeIfPresent(Set<Int>.self, forKey: .rerollUsed) ?? []
        extraDieUsed = try c.decodeIfPresent(Set<Int>.self, forKey: .extraDieUsed) ?? []
        roundsCrossed = try c.decodeIfPresent(Set<Int>.self, forKey: .roundsCrossed) ?? []
        playerCount = try c.decodeIfPresent(Int.self, forKey: .playerCount) ?? nil
        roundSnapshots = try c.decodeIfPresent([CleverRoundSnapshot].self, forKey: .roundSnapshots) ?? []
        history = try c.decodeIfPresent([CleverAction].self, forKey: .history) ?? []
        manuallyFinished = try c.decodeIfPresent(Bool.self, forKey: .manuallyFinished) ?? false
    }
}

/// A small snapshot of board totals captured when a round is crossed on the
/// rounds bar (issue #59), so the round-summary UI can report the delta vs.
/// the previous round. Value type with defaults for every field, so it
/// decodes tolerantly even if future fields are added without a custom
/// `init(from:)` (missing keys just fall back to `0`).
public struct CleverRoundSnapshot: Codable, Equatable {
    public var totalScore: Int = 0
    public var markCount: Int = 0

    public init(totalScore: Int = 0, markCount: Int = 0) {
        self.totalScore = totalScore
        self.markCount = markCount
    }

    private enum CodingKeys: String, CodingKey {
        case totalScore, markCount
    }

    // Tolerant decode, same discipline as `CleverState`: any future field
    // added to this struct must go through `decodeIfPresent(...) ?? default`
    // too, so snapshots saved by older builds keep loading.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalScore = try c.decodeIfPresent(Int.self, forKey: .totalScore) ?? 0
        markCount = try c.decodeIfPresent(Int.self, forKey: .markCount) ?? 0
    }
}

/// Reversible action for exact LIFO undo.
public enum CleverAction: Codable, Equatable {
    case yellow(Int)
    case blue(Int)
    case green
    case orange(Int, value: Int)
    case purple(Int, value: Int)
    case reroll(Int)
    case extraDie(Int)
}
