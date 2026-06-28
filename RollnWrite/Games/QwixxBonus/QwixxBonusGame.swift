//
//  QwixxBonusGame.swift
//  RollnWrite – Qwixx Bonus
//
//  The `GameDefinition` that registers Qwixx "Bonus" (version A) in the
//  catalogue and wires up its rules and scorecard. Adding a game means adding a
//  file like this plus one line in `GameRegistry` (OCP).
//

import SwiftUI

public struct QwixxBonusGame: GameDefinition {
    public init() {}

    public let id = "qwixx-bonus"
    public let title = "Qwixx Bonus"
    public let subtitle = "Classic rows · boxed numbers feed a bonus bar"
    public let iconSystemName = "die.face.6"
    public let accent = Color(red: 0.93, green: 0.45, blue: 0.13)
    public let availability: GameAvailability = .available

    public func makeScorecardView() -> AnyView {
        AnyView(QwixxBonusScorecardView(rules: rules))
    }

    public var rules: RulesDocument {
        RulesDocument(
            title: "Qwixx — Bonus (Version A)",
            subtitle: "Official rules for the Qwixx Bonus expansion, version A",
            sections: [
                RulesSection(heading: "Goal", body: [
                    "Play classic Qwixx, but twelve special numbers (printed inside a black box) feed a bonus bar that hands you free extra crosses.",
                ]),
                RulesSection(heading: "The card", body: [
                    "Red and yellow rows run 2 → 12 (left to right). Green and blue rows run 12 → 2.",
                    "Three numbers in every colour row are printed inside a black box — twelve boxed numbers in all.",
                    "Below the rows sits the bonus bar: a left-to-right chain of twelve coloured fields.",
                ]),
                RulesSection(heading: "Crossing out numbers", body: [
                    "Within every row you must cross out from left to right. You may skip numbers, but skipped numbers can never be crossed later.",
                    "On a turn the white dice total may be crossed in any one row; the active player may also add a white die to a colour die and cross that colour.",
                ]),
                RulesSection(heading: "Boxed numbers & the bonus bar", body: [
                    "Whenever you cross out a black-boxed number, immediately cross off the left-most still-free field of the bonus bar.",
                    "The bonus bar is crossed strictly left to right with no gaps.",
                    "The field you just crossed shows a colour. You immediately make one extra cross in that colour row — the next legal (left-most free) number in it.",
                    "If that free extra cross lands on another boxed number, it advances the bonus bar again, so chains can form. You may not decline an extra cross.",
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
                    "Version A scores exactly like classic Qwixx — the bonus bar awards no points itself; it only lets you fill rows faster.",
                    "Per colour, count its crosses (its own numbers + the lock, max 12) and score 1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66, 78.",
                    "Total = red + yellow + green + blue − (5 × penalties).",
                ]),
            ],
            source: "Qwixx Bonus (version A) by Nürnberger-Spielkarten-Verlag (NSV) / White Goblin Games; official scorecard (art. 4105)."
        )
    }
}
