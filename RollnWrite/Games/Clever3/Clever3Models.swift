//
//  Clever3Models.swift
//  RollnWrite – Clever3
//
//  "Clever Cubed" (Clever hoch Drei) by Wolfgang Warsch / Schmidt Spiele.
//  Layout + scoring transcribed from the official score sheet (all five areas
//  are now auto-scored).
//

import SwiftUI

public enum Clever3Area: String, Codable, CaseIterable, Identifiable {
    // NB: these case NAMES are legacy opaque identifiers (kept because the
    // rawValue is persisted in saved games and ~90 call sites reference them).
    // They do NOT match the areas' real colours — the official sheet's five
    // areas are yellow / BLUE / PURPLE / ORANGE / GREEN. The true colour is the
    // single source of truth in `standardColor` and `title` below; treat the
    // case name as just an ID. (A proper rename is tracked as a follow-up.)
    case yellow, turquoise, blue, brown, pink

    public var id: String { rawValue }

    /// User-facing colour name — the area's TRUE printed colour (see the note
    /// on the case names). Also used as a localisation key.
    public var title: String {
        switch self {
        case .yellow:    return "Yellow"
        case .turquoise: return "Blue"    // the sheet's blue 5×6 grid
        case .blue:      return "Purple"  // the sheet's purple ±1 track
        case .brown:     return "Orange"  // the sheet's orange 12-cell row
        case .pink:      return "Green"   // the sheet's green 11-cell row
        }
    }

    /// The area's STANDARD colour as printed on the official card — the input
    /// to the app-wide `DiceTheme` nearest-colour matching, never shown as-is.
    ///
    /// Re-verified against the official "Pretty Clever III" sheet (pixel-
    /// sampled from a clean render): the five printed areas are actually
    /// YELLOW / BLUE / PURPLE / ORANGE / GREEN — not the turquoise/blue/
    /// brown/pink hues previously declared here. This case's NAME is kept
    /// (renaming touches ~90 call sites and the read-only engine; tracked as
    /// a follow-up), but the RGB values below are now the true print colours
    /// so `DiceTheme`'s nearest-colour mapping starts from the right input:
    /// `.turquoise` (really the sheet's "blue" 5×6 grid) → rgb(0,118,188);
    /// `.blue` (really the sheet's "purple" ±1 track) → rgb(95,36,121);
    /// `.brown` (really the sheet's "orange" 12-cell row) → rgb(238,123,0);
    /// `.pink` (really the sheet's "green" 11-cell row) → rgb(0,161,56).
    public var standardColor: Color {
        switch self {
        case .yellow:    return Color(red: 254/255, green: 212/255, blue: 0)
        case .turquoise: return Color(red: 0, green: 118/255, blue: 188/255)
        case .blue:      return Color(red: 95/255, green: 36/255, blue: 121/255)
        case .brown:     return Color(red: 238/255, green: 123/255, blue: 0)
        case .pink:      return Color(red: 0, green: 161/255, blue: 56/255)
        }
    }
}

public enum Clever3Layout {
    // Yellow: 3 rows × 6 numbers; score per row by crosses.
    public static let yellowRows = 3
    public static let yellowCols = 6
    public static let yellowRowScale = [0, 2, 6, 12, 20, 30, 42]   // max 126

    // Turquoise: 5 rows × 6 numbers; score per row by crosses.
    public static let turquoiseRows = 5
    public static let turquoiseCols = 6
    public static let turquoiseRowScale = [0, 1, 3, 6, 10, 15, 21]  // max 105

    // Blue: a ±1 track around the central 7. 6 cells each side.
    public static let blueSideCells = 6
    /// Point value above each position, from nearest the centre (index 0) outward.
    public static let bluePositionScale = [3, 6, 9, 13, 17, 22]
    public static let blueBonusValues: Set<Int> = [2, 3, 4, 10, 11, 12]  // +4 each

    // Brown: one row of 12; score by total crosses (skips allowed but cost points).
    public static let brownNumbers = [1, 5, 3, 4, 2, 6, 4, 5, 2, 1, 6, 3]
    public static let brownScale = [0, 2, 5, 9, 14, 20, 27, 35, 44, 54, 65, 77, 90]

    // Pink: 11 cells, write die × multiplier (or the halved bonus value); score = sum.
    public static let pinkMultipliers = [1, 2, 2, 1, 2, 2, 1, 3, 2, 2, 3]
    public static var pinkCells: Int { pinkMultipliers.count }

    // MARK: - Bonus maps (transcribed from the official Clever Cubed score sheet)
    //
    // Each entry maps a completion (a grid row, a track cell, a brown/pink cell)
    // to the bonus icon printed there. In Clever Cubed every bonus is a player
    // *choice* (a "?" = choose any value of that colour, a re-roll, a +1, an
    // extra-die, or a fox), so none can be auto-placed deterministically — they
    // all surface as advisory strings. Foxes stay the manual stepper and are NOT
    // listed here (they would double-count against the stepper).

    /// Yellow grid: KNOWN TRIGGER-GRANULARITY GAP (flagged, not fixed here —
    /// `Clever3Game.swift` is read-only). The official sheet prints ONE badge
    /// under EACH of the 6 numbered cells on rows I/II's divider (confirmed
    /// against the sheet: row I = reroll, joker, ?green, +1, ?blue, fox; row
    /// II = joker, ?blue, ?purple, ?orange, wild-?, +1) — i.e. each bonus
    /// should fire the moment THAT specific numbered cell is crossed
    /// (per-cell), the same idiom already used correctly for the blue track/
    /// brown/pink cells below. The engine instead only fires `.yellowRow(r)`
    /// once the ENTIRE row (all 6 cells) is crossed, collapsing 6 badges into
    /// 1 "representative" (its rightmost icon) per row. This under-reports
    /// bonuses whenever a row is completed by crossing its cells out of
    /// numeric order, or is never fully completed at all. See the follow-up
    /// issue for a per-cell fix (would need a `[row][col]` bonus map here and
    /// a per-cell trigger in `Clever3Game.completedTriggers()`).
    public static let yellowRowBonus: [Int: C3Bonus] = [
        0: .fox,            // row 0 divider, rightmost = fox  (but fox via stepper)
        1: .plusOne,        // row 1 divider, rightmost = +1
    ]

    /// Turquoise (the 6×6 numbered grid) — row-end bonuses (right of rows 0–4)
    /// and column-foot bonuses (under cols 0–5).
    /// Row ends (rows 0–4): fox, +1, ?orange, ?(white). Bottom (cols 0–5):
    /// ?orange, ?green, ?yellow, extraDie, ?purple, reroll.
    public static let turquoiseRowBonus: [Int: C3Bonus] = [
        1: .plusOne,        // row 1 end = +1
        2: .pick(.brown),   // row 2 end = ? orange → choose a brown value
        3: .wild,           // row 3 end = ? (unfilled ring) → choose any value, any colour
    ]
    public static let turquoiseColBonus: [Int: C3Bonus] = [
        0: .pick(.brown),   // ? orange
        1: .pick(.pink),    // ? green
        2: .pick(.yellow),  // ? yellow
        3: .extraDie,       // dice (joker — closest available C3Bonus case)
        4: .pick(.blue),    // ? purple
        5: .reroll,         // reroll
    ]

    /// Blue ±1 track (the purple band). Position index 0 = innermost (value 3),
    /// 5 = outermost (value 22), per side. Centre 7 grants a reroll.
    /// Left side bonuses (idx→icon): 5:+1, 4:?green, 2:?yellow, 1:joker.
    /// Right side bonuses (idx→icon): 1:reroll, 2:?orange, 4:?blue, 5:fox.
    public static let blueLeftBonus: [Int: C3Bonus] = [
        5: .plusOne,
        4: .pick(.pink),
        2: .pick(.yellow),
        1: .extraDie,       // joker — closest available C3Bonus case
    ]
    public static let blueRightBonus: [Int: C3Bonus] = [
        1: .reroll,
        2: .pick(.brown),
        4: .pick(.turquoise),
        // idx 5 = fox (manual stepper) → omitted
    ]
    public static let blueCenterBonus: C3Bonus = .reroll

    /// Brown row of 12. Icons sit between adjacent cells; we attach each to the
    /// later cell, so the bonus fires when that cell is crossed (you reach it).
    /// 1:joker, 2:?green, 4:reroll, 5:?blue, 7:+1, 8:?purple, 10:?yellow,
    /// 11:fox.
    public static let brownBonus: [Int: C3Bonus] = [
        1: .extraDie,       // joker — closest available C3Bonus case
        2: .pick(.pink),
        4: .reroll,
        5: .pick(.turquoise),
        7: .plusOne,
        8: .pick(.blue),
        10: .pick(.yellow),
        // 11 = fox (manual stepper) → omitted
    ]

    /// Pink row of 11. Icons sit between adjacent cells; attach to the later cell.
    /// 1:reroll, 2:?blue(turquoise official), 3:+1, 4:joker, 5:?yellow,
    /// 6:?orange, 7:reroll, 8:fox, 9:?purple, 10:?blue(turquoise official).
    public static let pinkBonus: [Int: C3Bonus] = [
        1: .reroll,
        2: .pick(.turquoise),
        3: .plusOne,
        4: .extraDie,       // joker — closest available C3Bonus case
        5: .pick(.yellow),
        6: .pick(.brown),
        7: .reroll,
        // 8 = fox (manual stepper) → omitted
        9: .pick(.blue),
        10: .pick(.turquoise),
    ]
}

/// A bonus printed on the Clever Cubed sheet. All are player choices in this
/// game, so each is surfaced as an advisory message (none auto-place).
public enum C3Bonus: Equatable {
    case reroll
    case plusOne
    case extraDie
    case fox
    case pick(Clever3Area)   // "?" → choose any value/cross in that colour
    /// The unfilled-ring "?" printed a few times on the sheet (yellow row II,
    /// turquoise row 4): choose any value in ANY colour, not one fixed area —
    /// distinct from `pick(area)`. See `C3BonusIcon.wild` (the matching
    /// printed-art glyph in Clever3ScorecardView.swift).
    case wild

    public var message: String {
        switch self {
        case .reroll:       return "Re-roll a die"
        case .plusOne:      return "+1 to a die"
        case .extraDie:     return "Use an extra die"
        case .fox:          return "🦊 Fox earned!"
        case let .pick(a):  return "Choose any \(a.title.lowercased()) value (?)"
        case .wild:         return "Choose any value, any colour (?)"
        }
    }
}

public struct Clever3State: Codable, Equatable {
    public var yellow: Set<Int> = []      // crossed indices over 3*6
    public var turquoise: Set<Int> = []   // crossed indices over 5*6
    public var blueLeft: [Int?] = Array(repeating: nil, count: Clever3Layout.blueSideCells)
    public var blueRight: [Int?] = Array(repeating: nil, count: Clever3Layout.blueSideCells)
    public var brown: Set<Int> = []       // crossed indices 0…11
    public var pink: [Int?] = Array(repeating: nil, count: Clever3Layout.pinkCells)
    public var foxes: Int = 0
    // Note: older saves carry a per-game `theme` key; the decoder ignores it
    // (dice colours are an app-wide setting now — see `DiceTheme`).

    public init() {}
}
