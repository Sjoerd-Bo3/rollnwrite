//
//  QwixxXChangeGame.swift
//  RollnWrite – Qwixx X-Change
//
//  The `GameDefinition` that registers Qwixx "X-Change" in the catalogue and
//  wires up its rules and scorecard. Adding a game means adding a file like this
//  plus one line in `GameRegistry` (OCP).
//

import SwiftUI

public struct QwixxXChangeGame: GameDefinition {
    public init() {}

    public let id = "qwixx-xchange"
    public let title = "Qwixx X-Change"
    public let subtitle = "Classic rows · X-Change swap row"
    public let iconSystemName = "arrow.triangle.2.circlepath"
    public let accent = Color(red: 0.55, green: 0.10, blue: 0.42)
    public let availability: GameAvailability = .available

    public func makeScorecardView() -> AnyView {
        AnyView(QwixxXChangeScorecardView(rules: rules))
    }

    public var rules: RulesDocument {
        RulesDocument(
            title: "Qwixx — X-Change",
            subtitle: "Official rules for the X-Change variant",
            sections: [
                RulesSection(heading: "Goal", body: [
                    "Play classic Qwixx, but a new X-Change row of nine diamond fields lets you swap the white-dice sum for a more useful number before crossing out a colour.",
                ]),
                RulesSection(heading: "The card", body: [
                    "Red and yellow rows run 2 → 12 (left to right). Green and blue rows run 12 → 2.",
                    "Below the colour rows sits the X-Change row: nine diamonds, each showing two numbers with a swap arrow (8/5, 9/7, 11/3, 7/4, 10/3, 8/6, 10/5, 11/9, 6/4).",
                ]),
                RulesSection(heading: "Crossing out numbers", body: [
                    "Within every row you must cross out from left to right. You may skip numbers, but skipped numbers can never be crossed later.",
                    "On a turn the white-dice total may be crossed in any one row; the active player may also add a white die to a colour die and cross that colour.",
                ]),
                RulesSection(heading: "The X-Change row", body: [
                    "When the white-dice sum is announced you may instead cross the next available X-Change diamond whose number matches that sum, then EXCHANGE it for the diamond's other number.",
                    "Use the exchanged value exactly as if it were the white-dice sum: cross it in any one colour row (following that row's left-to-right rule).",
                    "The swap works in either direction — top to bottom or bottom to top (the diamond's double arrow).",
                    "The X-Change row is crossed strictly left to right. You may skip diamonds to reach the one you want, but every skipped diamond is then lost for the rest of the game.",
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
                    "The X-Change row scores no points on its own — its value is the extra colour crosses the swaps let you make.",
                    "Total = red + yellow + green + blue − (5 × penalties).",
                ]),
            ],
            source: "Qwixx X-Change by Nürnberger-Spielkarten-Verlag (NSV) / White Goblin Games (art. 4290); official scorecard & rules."
        )
    }
}
