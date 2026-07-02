//
//  Clever4GameDefinition.swift
//  RollnWrite – Clever4
//

import SwiftUI

/// The six physical Clever 4 dice: white plus the five area colours. Themed —
/// resolved through the player's app-wide dice palette, like the board areas.
/// Informational roller only; never any rule.
private let clever4Dice: [DieSpec] = [
    .white(themed: true),
    DieSpec(name: "Yellow", color: Clever4Area.yellow.standardColor, isLight: true, themed: true),
    DieSpec(name: "Blue", color: Clever4Area.blue.standardColor, themed: true),
    DieSpec(name: "Grey", color: Clever4Area.grey.standardColor, themed: true),
    DieSpec(name: "Green", color: Clever4Area.green.standardColor, themed: true),
    DieSpec(name: "Pink", color: Clever4Area.pink.standardColor, themed: true),
]

public struct Clever4everGame: GameDefinition {
    public init() {}

    public let id = "clever-4"
    public let title = "Clever 4ever"
    public let subtitle = "Clever 4ever · yellow, blue, grey, green, pink"
    public let iconSystemName = "brain.head.profile"
    public let accent = Color(red: 0.20, green: 0.62, blue: 0.30)
    public let availability: GameAvailability = .available

    public var diceSet: [DieSpec]? { clever4Dice }

    public func makeScorecardView() -> AnyView {
        AnyView(Clever4ScorecardView(rules: rules)
            .environment(\.gameDiceSet, diceSet))
    }

    public var rules: RulesDocument {
        RulesDocument(
            title: "Clever 4ever",
            subtitle: "Official rules — Wolfgang Warsch / Schmidt Spiele",
            sections: [
                RulesSection(heading: "Areas", body: [
                    "Five areas: yellow, blue, grey, green and pink. The white die is a joker. The app auto-scores all five.",
                ]),
                RulesSection(heading: "Yellow", body: [
                    "Three rows of five fields. The top row must strictly ascend (it closes after a 6) and scores 0 itself — it only grants bonuses.",
                    "The middle row counts as negative; the bottom row as positive. Each fully-filled column scores its yellow star (10, 10, 15, 15, 20).",
                    "Score = (sum of bottom) − (sum of middle) + completed-column stars.",
                ]),
                RulesSection(heading: "Blue", body: [
                    "A 6×6 grid: cross a cell at (blue die = row, white die = column). A column with two or more crosses scores its value (7, 8, 9, 10, 11, 12).",
                    "The top-right→bottom-left diagonal scores +6 when it has two or more crosses.",
                ]),
                RulesSection(heading: "Grey", body: [
                    "Cross polyomino cells across a 4×16 grid (cross freely here). Each fully-crossed column scores the value printed above it (1…11).",
                ]),
                RulesSection(heading: "Green", body: [
                    "Eleven fields, each split into an upper and a lower triangle; fill both rows left→right. When both triangles of a field are filled, its box = their sum, doubled from the 4th field onward (×2).",
                ]),
                RulesSection(heading: "Pink", body: [
                    "One bar of twelve fields, filled left→right with no skips. Score = the value above the last filled field (up to 42), plus circled bonuses: each 2 → +2, each 4 → +4, each 6 → +3.",
                ]),
                RulesSection(heading: "Foxes & scoring", body: [
                    "Foxes are tracked with the stepper; each scores your lowest area. Total = yellow + blue + grey + green + pink + (foxes × lowest area).",
                ]),
            ],
            source: "Clever 4ever by Wolfgang Warsch, Schmidt Spiele (art. 49424); official rulebook & score sheet."
        )
    }
}
