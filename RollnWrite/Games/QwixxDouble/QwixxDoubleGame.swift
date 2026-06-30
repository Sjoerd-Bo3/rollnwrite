//
//  QwixxDoubleGame.swift
//  RollnWrite – Qwixx Double
//
//  The `GameDefinition` that registers Qwixx "Double" in the catalogue and wires
//  up its rules and scorecard. Adding a game means adding a file like this plus
//  one line in `GameRegistry` (OCP).
//
//  This definition implements the official Qwixx Double **Variant A — "double
//  crosses"**: the most-recently crossed space in a row can be crossed a second
//  time, and a row scores up to 16 crosses (136 points).
//

import SwiftUI

public struct QwixxDoubleGame: GameDefinition {
    public init() {}

    public let id = "qwixx-double"
    public let title = "Qwixx Double"
    public let subtitle = "Classic rows · double the most-recent cross"
    public let iconSystemName = "xmark.square.fill"
    public let accent = Color(red: 0.86, green: 0.18, blue: 0.18)
    public let availability: GameAvailability = .available

    public func makeScorecardView() -> AnyView {
        AnyView(QwixxDoubleScorecardView(rules: rules))
    }

    public var rules: RulesDocument {
        RulesDocument(
            title: "Qwixx — Double (Variant A)",
            subtitle: "Official rules for the Qwixx Double \"double crosses\" variant",
            sections: [
                RulesSection(heading: "Goal", body: [
                    "Play classic Qwixx, but the space you most recently crossed in each colour row can be crossed off a second time — for many more points.",
                ]),
                RulesSection(heading: "The card", body: [
                    "Red and yellow rows run 2 → 12 (left to right). Green and blue rows run 12 → 2.",
                    "Below every number there is room to draw a second cross.",
                ]),
                RulesSection(heading: "Crossing out numbers", body: [
                    "Within every row you must cross out from left to right. You may skip numbers, but skipped numbers can never be crossed later.",
                    "On a turn the white dice total may be crossed in any one row; the active player may also add a white die to a colour die and cross that colour.",
                ]),
                RulesSection(heading: "Double crosses", body: [
                    "The space you most recently crossed off in a colour row can be crossed off again whenever the matching number comes up — whether you are the active player or not. The first cross is drawn in the numbered space, the second cross below it.",
                    "Only your single most-recent space is eligible: once you cross a new number further along the row, the previous space can no longer be doubled.",
                ]),
                RulesSection(heading: "Locking a row", body: [
                    "Before you may cross the right-most number (12 for red/yellow, 2 for green/blue) you must already have at least 7 crosses in that row (as opposed to 5 in the regular game).",
                    "Crossing it locks the row and adds the lock as one extra cross.",
                ]),
                RulesSection(heading: "Penalties & game end", body: [
                    "If on your turn you cross nothing, take a penalty (−5 points). Four penalties end the game.",
                    "The game also ends the moment two rows are locked.",
                ]),
                RulesSection(heading: "Scoring", body: [
                    "Per colour, count all crosses (first crosses + second crosses + the lock). It is possible to draw up to 22 crosses, but you may only score a maximum of 16 crosses per row.",
                    "Score by the table: 1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66, 78, 91, 105, 120, 136 for 1 … 16 crosses (a whopping 136 points per row).",
                    "Total = red + yellow + green + blue − (5 × penalties).",
                ]),
            ],
            source: "Qwixx Double by Nürnberger-Spielkarten-Verlag (NSV) / White Goblin Games; official \"How to play Qwixx Double\" rules (Variant A), English translation by Jo Lefebure."
        )
    }
}
