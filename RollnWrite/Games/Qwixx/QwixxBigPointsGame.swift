//
//  QwixxBigPointsGame.swift
//  RollnWrite – Qwixx
//
//  The `GameDefinition` that registers Qwixx Big Points in the catalogue and
//  wires up its rules and scorecard. Adding a game means adding a file like this.
//

import SwiftUI

public struct QwixxBigPointsGame: GameDefinition {
    public init() {}

    public let id = "qwixx-big-points"
    public let title = "Qwixx Big Points"
    public let subtitle = "Bonus rows · up to 120 per colour"
    public let iconSystemName = "die.face.6"
    public let accent = Color(red: 0.86, green: 0.18, blue: 0.18)
    public let availability: GameAvailability = .available

    public var diceSet: [DieSpec]? { qwixxDice }

    public func makeScorecardView() -> AnyView {
        AnyView(QwixxBigPointsScorecardView(rules: rules)
            .environment(\.gameDiceSet, diceSet))
    }

    public var rules: RulesDocument {
        RulesDocument(
            title: "Qwixx — Big Points",
            subtitle: "Official rules for the Big Points variant",
            sections: [
                RulesSection(heading: "Goal", body: [
                    "Cross out as many numbers as you can in the four colour rows to score points. In Big Points the two extra bonus rows let a single colour reach up to 120 points.",
                ]),
                RulesSection(heading: "The card", body: [
                    "Red and yellow rows run 2 → 12 (left to right). Green and blue rows run 12 → 2.",
                    "Between red and yellow sits the red/yellow bonus row; between green and blue sits the green/blue bonus row. Each has the same numbers as its neighbours.",
                ]),
                RulesSection(heading: "Crossing out numbers", body: [
                    "Within every row you must cross out from left to right. You may skip numbers, but skipped numbers can never be crossed later.",
                    "On a turn the white dice total may be crossed in any one row; the active player may also add a white die to a colour die and cross that colour.",
                ]),
                RulesSection(heading: "Bonus rows", body: [
                    "A bonus space may only be crossed once an adjacent same-number colour space (either colour) has already been crossed.",
                    "The general rule applies to the bonus rows too: cross them from left to right — previously skipped bonus spaces may not be crossed later.",
                    "Each crossed bonus space counts for BOTH adjacent colour rows when scoring, but bonus crosses do NOT count toward the 5 crosses required to lock a row.",
                    "Bonus spaces next to an already-locked colour row can still be crossed (activated via the other colour) and still count for both rows.",
                    "Crossing only a bonus space on your turn does not count as a failed throw — no penalty.",
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
                    "Per colour, count its crosses (its own numbers + lock + adjacent bonus crosses, max 15) and score 1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66, 78, 91, 105, 120.",
                    "Total = red + yellow + green + blue − (5 × penalties).",
                ]),
            ],
            source: "Qwixx Big Points by Nürnberger-Spielkarten-Verlag (NSV); official scorecard & variant rules.",
            officialRulesURL: URL(string: "https://www.nsv.de/wp-content/uploads/2024/04/QwixxBP_GB.pdf")
        )
    }
}
