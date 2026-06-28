//
//  CleverGameDefinition.swift
//  RollnWrite – Clever
//
//  Registers "That's Pretty Clever" (Clever 1) and provides its official rules.
//

import SwiftUI

public struct ThatsPrettyCleverGame: GameDefinition {
    public init() {}

    public let id = "clever-1"
    public let title = "That's Pretty Clever"
    public let subtitle = "Ganz schön clever · 5 areas + foxes"
    public let iconSystemName = "brain.head.profile"
    public let accent = Color(red: 0.55, green: 0.28, blue: 0.72)
    public let availability: GameAvailability = .available

    public func makeScorecardView() -> AnyView {
        AnyView(CleverScorecardView(rules: rules))
    }

    public var rules: RulesDocument {
        RulesDocument(
            title: "That's Pretty Clever (Ganz schön clever)",
            subtitle: "Official rules — Wolfgang Warsch / Schmidt Spiele",
            sections: [
                RulesSection(heading: "Turn", body: [
                    "On your turn roll all 6 dice, pick one and mark it in the matching colour area. Set aside all dice showing a lower value (the Silver Platter), then re-roll and pick again — up to 3 dice total.",
                    "The white die is wild: use it as yellow, green, orange or purple, or add it to the blue die for the blue area.",
                    "This app is a scorecard — you roll physical dice and tap to record. It enforces each area's structure and totals everything for you.",
                ]),
                RulesSection(heading: "Yellow", body: [
                    "Cross out the die value anywhere in the 4×4 grid (any order). The anti-diagonal is pre-crossed.",
                    "Each completed column scores the value beneath it (10, 14, 16, 20) — these are added together.",
                    "Completing a row, the main diagonal, or other spots grants the printed bonus.",
                ]),
                RulesSection(heading: "Blue", body: [
                    "Cross the cell equal to blue + white (2–12), any order.",
                    "Score by how many cells you've crossed: 1, 2, 4, 7, 11, 16, 22, 29, 37, 46, 56.",
                ]),
                RulesSection(heading: "Green", body: [
                    "Mark left to right without skipping; each space needs the printed minimum die value.",
                    "Score the value above your last marked space (1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66).",
                ]),
                RulesSection(heading: "Orange", body: [
                    "Write the die value left to right. Some spaces multiply it (×2 or ×3).",
                    "Score the sum of all written numbers.",
                ]),
                RulesSection(heading: "Purple", body: [
                    "Write the die value left to right; each must be higher than the previous — except any value may follow a 6.",
                    "Score the sum of all written numbers.",
                ]),
                RulesSection(heading: "Bonuses & foxes", body: [
                    "Printed bonuses (re-roll, +1, extra cross, a coloured number) are earned as you mark spaces; apply them by tapping the granted space yourself. Bonuses can chain.",
                    "Each fox scores the value of your lowest-scoring area. The app detects foxes automatically and counts them for you.",
                ]),
                RulesSection(heading: "Game end & scoring", body: [
                    "Played over 6 rounds (solo / 2 players), 5 (3 players) or 4 (4 players).",
                    "Final score = yellow + blue + green + orange + purple + (foxes × lowest area). Highest total wins.",
                ]),
            ],
            source: "Ganz schön clever by Wolfgang Warsch, Schmidt Spiele (art. 88198); official rulebook & score sheet."
        )
    }
}
