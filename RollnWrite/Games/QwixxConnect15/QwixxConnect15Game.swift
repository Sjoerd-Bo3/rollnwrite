//
//  QwixxConnect15Game.swift
//  RollnWrite – Qwixx Connect15
//
//  The `GameDefinition` that registers Qwixx "Connect 15" in the catalogue and
//  wires up its rules and scorecard. Adding a game means adding a file like this
//  plus one line in `GameRegistry` (OCP).
//

import SwiftUI

public struct QwixxConnect15Game: GameDefinition {
    public init() {}

    public let id = "qwixx-connect15"
    public let title = "Qwixx Connect15"
    public let subtitle = "Classic rows · connection fields → 15"
    public let iconSystemName = "link"
    public let accent = Color(red: 0.93, green: 0.45, blue: 0.13)
    public let availability: GameAvailability = .available

    public var diceSet: [DieSpec]? { qwixxDice }

    public func makeScorecardView() -> AnyView {
        AnyView(QwixxConnect15ScorecardView(rules: rules)
            .environment(\.gameDiceSet, diceSet))
    }

    public var rules: RulesDocument {
        RulesDocument(
            title: "Qwixx — Connect 15",
            subtitle: "Official rules for the Connect 15 anniversary variant",
            sections: [
                RulesSection(heading: "Goal", body: [
                    "Play classic Qwixx, but every colour row now carries three extra connection fields. Filling them lets a row reach 15 crosses worth 120 points — hence “Connect 15”.",
                ]),
                RulesSection(heading: "The card", body: [
                    "Red and yellow rows run 2 → 12 (left to right). Green and blue rows run 12 → 2.",
                    "Each row carries three small connection squares sitting between specific numbers: red between 3–4, 6–7 and 10–11; yellow between 5–6, 7–8 and 9–10; green between 10–9, 6–5 and 4–3; blue between 11–10, 8–7 and 5–4. They carry no number.",
                ]),
                RulesSection(heading: "Crossing out numbers", body: [
                    "Numbers and connection fields form one left-to-right sequence per row: every new cross must sit to the right of everything already crossed in that row. Skipped spaces — numbers and connection fields alike — can never be crossed later.",
                    "So crossing a number to the right of an empty connection field forfeits that field.",
                    "On a turn the white dice total may be crossed in any one row; the active player may also add a white die to a colour die and cross that colour.",
                ]),
                RulesSection(heading: "Connection fields", body: [
                    "Whenever the dice show a 1 and a 5 (in any colour), every player may cross a connection field of one of their rows.",
                    "Which row: a colour die + a white die showing 1 and 5 → that colour’s row; two colour dice → either of those two colours; two white dice → any row.",
                    "The field crossed must lie to the right of the row’s right-most cross; crossing it forfeits every empty number and field to its left. Locking (or conceding) a row closes its remaining connection fields.",
                ]),
                RulesSection(heading: "Locking a row", body: [
                    "To cross the right-most number (12 for red/yellow, 2 for green/blue) you must already have at least 5 crossed numbers in that row — connection fields don’t count toward the five.",
                    "Crossing it locks the row and adds the lock as one extra cross.",
                ]),
                RulesSection(heading: "Penalties & game end", body: [
                    "If on your turn you cross nothing, take a penalty (−5 points). Four penalties end the game.",
                    "The game also ends the moment two rows are locked.",
                ]),
                RulesSection(heading: "Scoring", body: [
                    "Per colour, count its crosses — its numbers, the lock, and every crossed connection field (max 15) — and score 1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66, 78, 91, 105, 120.",
                    "Total = red + yellow + green + blue − (5 × penalties).",
                ]),
            ],
            source: "Qwixx 15 (Connect 15 variant) by White Goblin Games / Nürnberger-Spielkarten-Verlag (NSV); official scorecard."
        )
    }
}
