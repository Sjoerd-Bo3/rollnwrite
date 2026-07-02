//
//  QwixxClassicGame.swift
//  RollnWrite – Qwixx
//
//  The `GameDefinition` for the original Qwixx. It reuses the Qwixx engine and
//  scorecard view, configured WITHOUT bonus rows and with scoring capped at 12
//  crosses per colour. Adding this variant required no edits to the engine's
//  rules — only a different construction (DIP) and a definition like this one.
//

import SwiftUI

/// The six physical Qwixx dice — two white plus one per colour row — shared by
/// every Qwixx flavour (they all use the same dice). Fixed colours matching
/// the row tints, NOT themed: Qwixx dice are always these, unlike the Clever
/// dice which follow the player's palette. Powers the optional informational
/// dice roller only; never any rule.
let qwixxDice: [DieSpec] = [
    .white(),
    .white(),
    DieSpec(name: "Red", color: GameColor.red.tint),
    DieSpec(name: "Yellow", color: GameColor.yellow.tint, isLight: true),
    DieSpec(name: "Green", color: GameColor.green.tint),
    DieSpec(name: "Blue", color: GameColor.blue.tint),
]

public struct QwixxClassicGame: GameDefinition {
    public init() {}

    public let id = "qwixx-classic"
    public let title = "Qwixx"
    public let subtitle = "The original · cap 12"
    public let iconSystemName = "die.face.4"
    public let accent = Color.orange
    public let availability: GameAvailability = .available

    public var diceSet: [DieSpec]? { qwixxDice }

    public func makeScorecardView() -> AnyView {
        AnyView(QwixxClassicScorecardView(rules: rules)
            .environment(\.gameDiceSet, diceSet))
    }

    public var rules: RulesDocument {
        RulesDocument(
            title: "Qwixx",
            subtitle: "Official rules for the original game",
            sections: [
                RulesSection(heading: "Goal", body: [
                    "Cross out as many numbers as you can in the four colour rows to score points. The more crosses in a colour, the more that colour is worth.",
                ]),
                RulesSection(heading: "The card", body: [
                    "Red and yellow rows run 2 → 12 (left to right). Green and blue rows run 12 → 2.",
                    "There are no bonus rows — only the four colour rows.",
                ]),
                RulesSection(heading: "Crossing out numbers", body: [
                    "Within every row you must cross out from left to right. You may skip numbers, but skipped numbers can never be crossed later.",
                    "On a turn the white dice total may be crossed in any one row; the active player may also add a white die to a colour die and cross that colour.",
                ]),
                RulesSection(heading: "Locking a row", body: [
                    "To cross the right-most number (12 for red/yellow, 2 for green/blue) you must already have at least 5 crosses in that row.",
                    "Crossing it locks the row and adds the lock as one extra cross.",
                ]),
                RulesSection(heading: "Penalties & game end", body: [
                    "If on your turn you cross nothing, take a penalty (−5 points). Four penalties end the game.",
                    "The game also ends the moment two rows are locked.",
                ]),
                RulesSection(heading: "Scoring", body: [
                    "Per colour, count its crosses (its own numbers + the lock, max 12) and score 1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66, 78.",
                    "Total = red + yellow + green + blue − (5 × penalties).",
                ]),
            ],
            source: "Qwixx by Steffen Benndorf, Nürnberger-Spielkarten-Verlag (NSV)."
        )
    }
}
