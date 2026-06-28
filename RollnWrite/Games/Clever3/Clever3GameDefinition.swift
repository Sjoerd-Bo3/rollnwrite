//
//  Clever3GameDefinition.swift
//  RollnWrite – Clever3
//

import SwiftUI

public struct CleverCubedGame: GameDefinition {
    public init() {}

    public let id = "clever-3"
    public let title = "Clever Cubed"
    public let subtitle = "Clever hoch Drei · yellow, turquoise, blue, brown, pink"
    public let iconSystemName = "brain.head.profile"
    public let accent = Color(red: 0.10, green: 0.60, blue: 0.55)
    public let availability: GameAvailability = .available

    public func makeScorecardView() -> AnyView { AnyView(Clever3ScorecardView(rules: rules)) }

    public var rules: RulesDocument {
        RulesDocument(
            title: "Clever Cubed (Clever hoch Drei)",
            subtitle: "Official rules — Wolfgang Warsch / Schmidt Spiele",
            sections: [
                RulesSection(heading: "Areas", body: [
                    "Five areas: yellow, turquoise, brown (cross out) and blue, pink (write numbers). White is wild.",
                    "This scorecard auto-scores yellow, turquoise and pink. Blue and brown use point tables printed only on the physical sheet, so you enter those two totals.",
                ]),
                RulesSection(heading: "Yellow", body: [
                    "Three rows; cross the rolled number (active rows go I→II→III by roll). Each row scores 2, 6, 12, 20, 30, 42 by its number of crosses. Max 126.",
                ]),
                RulesSection(heading: "Turquoise", body: [
                    "Five rows; cross the rolled number — and one extra field per matching die. Each row scores 1, 3, 6, 10, 15, 21 by its crosses. Max 105.",
                ]),
                RulesSection(heading: "Blue", body: [
                    "A ±1 track around the central 7: go left writing exactly one lower, right exactly one higher; a 7 resets the run.",
                    "Score = points above the outermost-left and outermost-right entries, plus 4 per written 2/3/4/10/11/12. Max 68. (Enter your blue total.)",
                ]),
                RulesSection(heading: "Brown", body: [
                    "One row, left to right; you may skip but never go back. Score from the printed crosses→points table (12 crosses = 90). (Enter your brown total.)",
                ]),
                RulesSection(heading: "Pink", body: [
                    "Fill left to right. Take the bonus (halve the die, round up) or the points (die × the printed multiplier). Score = sum of all written numbers.",
                ]),
                RulesSection(heading: "Foxes & scoring", body: [
                    "Each fox scores your lowest area. Total = yellow + turquoise + blue + brown + pink + (foxes × lowest area).",
                ]),
            ],
            source: "Clever hoch Drei by Wolfgang Warsch, Schmidt Spiele; official rulebook. Yellow/turquoise/blue formulas verified against the official scoring."
        )
    }
}
