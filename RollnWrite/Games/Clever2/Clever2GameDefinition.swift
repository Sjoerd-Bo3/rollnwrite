//
//  Clever2GameDefinition.swift
//  RollnWrite – Clever2
//

import SwiftUI

/// The six physical Clever 2 dice: white, silver and the four chromatic area
/// colours. Themed — resolved through the player's app-wide dice palette,
/// like the board areas. Informational roller only; never any rule.
private let clever2Dice: [DieSpec] = [
    .white(themed: true),
    DieSpec(name: "Silver", color: Clever2Area.silver.standardColor, themed: true),
    DieSpec(name: "Yellow", color: Clever2Area.yellow.standardColor, isLight: true, themed: true),
    DieSpec(name: "Blue", color: Clever2Area.blue.standardColor, themed: true),
    DieSpec(name: "Green", color: Clever2Area.green.standardColor, themed: true),
    DieSpec(name: "Pink", color: Clever2Area.pink.standardColor, themed: true),
]

public struct TwiceAsCleverGame: GameDefinition {
    public init() {}

    public let id = "clever-2"
    public let title = "Twice as Clever"
    public let subtitle = "Doppelt so clever · silver, yellow, blue, green, pink"
    public let iconSystemName = "brain.head.profile"
    public let accent = Color(red: 0.86, green: 0.28, blue: 0.56)
    public let availability: GameAvailability = .available

    public var diceSet: [DieSpec]? { clever2Dice }

    public func makeScorecardView() -> AnyView {
        AnyView(Clever2ScorecardView(rules: rules)
            .environment(\.gameDiceSet, diceSet))
    }

    public var rules: RulesDocument {
        RulesDocument(
            title: "Twice as Clever (Doppelt so clever)",
            subtitle: "Official rules — Wolfgang Warsch / Schmidt Spiele",
            sections: [
                RulesSection(heading: "Turn", body: [
                    "Same flow as That's Pretty Clever: roll 6 dice, take up to 3 (setting aside lower dice for others), and record each in its colour area. White is wild.",
                    "This app is a scorecard: it enforces each area's structure and totals your score. Apply re-roll / return / +1 / extra-die bonuses yourself.",
                ]),
                RulesSection(heading: "Silver", body: [
                    "Cross the die value in any of the four colour rows (the colour is free).",
                    "Each row scores by how many marks it has: 2, 4, 7, 11, 16, 22. Add all four rows.",
                ]),
                RulesSection(heading: "Yellow", body: [
                    "Tap once to circle a number, twice to cross it (you may only cross what's circled).",
                    "Only crosses score: 3, 10, 21, 36, 55, 75, 96, 118, 141, 165 for 1–10 crosses. Circles enable bonuses.",
                ]),
                RulesSection(heading: "Blue", body: [
                    "Write blue + white (2–12) left to right; each number must be ≤ the previous one.",
                    "Score the value above the last filled box (up to 78).",
                ]),
                RulesSection(heading: "Green", body: [
                    "Write the die × the printed multiplier, left to right. Cells are grouped in pairs.",
                    "Each completed pair scores (first − second); add all pair results. Put a high number first, a low number second.",
                ]),
                RulesSection(heading: "Pink", body: [
                    "Write the die value left to right (any value). Score the sum of all entries.",
                    "A space's bonus is only earned if the value is ≥ the printed minimum.",
                ]),
                RulesSection(heading: "Foxes & scoring", body: [
                    "Each fox scores your lowest area. Tap the fox stepper when you earn one.",
                    "Final score = silver + yellow + blue + green + pink + (foxes × lowest area).",
                ]),
            ],
            source: "Doppelt so clever by Wolfgang Warsch, Schmidt Spiele (art. 88234); official rulebook & score sheet."
        )
    }
}
