//
//  QwixxLucky15Game.swift
//  RollnWrite – Qwixx Lucky15
//
//  The `GameDefinition` that registers Qwixx "Lucky 15" in the catalogue and
//  wires up its rules and scorecard. Adding a game means adding a file like this
//  plus one line in `GameRegistry` (OCP).
//

import SwiftUI

public struct QwixxLucky15Game: GameDefinition {
    public init() {}

    public let id = "qwixx-lucky15"
    public let title = "Qwixx Lucky15"
    public let subtitle = "Classic rows · Lucky 15 bonus track"
    public let iconSystemName = "die.face.5"
    public let accent = Color(red: 0.93, green: 0.45, blue: 0.13)
    public let availability: GameAvailability = .available

    public var diceSet: [DieSpec]? { qwixxDice }

    public func makeScorecardView() -> AnyView {
        AnyView(QwixxLucky15ScorecardView(rules: rules)
            .environment(\.gameDiceSet, diceSet))
    }

    public var rules: RulesDocument {
        RulesDocument(
            title: "Qwixx — Lucky 15",
            subtitle: "Official rules for the Lucky 15 anniversary variant",
            sections: [
                RulesSection(heading: "Goal", body: [
                    "Play classic Qwixx, but a new orange Lucky 15 track rewards you whenever you can form exactly 15 with the dice.",
                ]),
                RulesSection(heading: "The card", body: [
                    "Red and yellow rows run 2 → 12 (left to right). Green and blue rows run 12 → 2.",
                    "Below the colour rows sits the orange Lucky 15 track with four fields worth 5, 11, 18 and 25 points.",
                ]),
                RulesSection(heading: "Crossing out numbers", body: [
                    "Within every row you must cross out from left to right. You may skip numbers, but skipped numbers can never be crossed later.",
                    "On a turn the white dice total may be crossed in any one row; the active player may also add a white die to a colour die and cross that colour.",
                ]),
                RulesSection(heading: "The Lucky 15 track", body: [
                    "Whenever the active player rolls exactly 15 with both white dice plus one coloured die, they may cross the next free field of the Lucky 15 track (active player only).",
                    "The Lucky 15 mark replaces BOTH usual actions — it is your only action that turn. It counts as a mark, so it also spares you a penalty.",
                    "The track is crossed strictly left to right: 5, then 11, then 18, then 25.",
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
                    "The Lucky 15 bonus equals the value of the highest field you crossed (0 / 5 / 11 / 18 / 25).",
                    "Total = red + yellow + green + blue + Lucky 15 bonus − (5 × penalties).",
                ]),
            ],
            source: "Qwixx 15 (Lucky 15 variant) by White Goblin Games / Nürnberger-Spielkarten-Verlag (NSV); official scorecard."
        )
    }
}
