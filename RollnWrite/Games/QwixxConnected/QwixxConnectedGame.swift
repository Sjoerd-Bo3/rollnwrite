//
//  QwixxConnectedGame.swift
//  RollnWrite – Qwixx Connected
//
//  The `GameDefinition` that registers Qwixx "Connected" in the catalogue and
//  wires up its rules and scorecard. Adding a game means adding a file like this
//  plus one line in `GameRegistry` (OCP).
//
//  This implements the "Die Kette" / "The Chain" game variant (officially
//  "Version B" in the rules) using slip "A" of the five sheets (A–E), which is
//  the layout on the supplied scorecard.
//

import SwiftUI

public struct QwixxConnectedGame: GameDefinition {
    public init() {}

    public let id = "qwixx-connected"
    public let title = "Qwixx Connected"
    public let subtitle = "Connected — Chain · linked spaces auto-cross"
    public let iconSystemName = "link"
    public let accent = Color(red: 0.20, green: 0.55, blue: 0.85)
    public let availability: GameAvailability = .available

    public var diceSet: [DieSpec]? { qwixxDice }

    public func makeScorecardView() -> AnyView {
        AnyView(QwixxConnectedScorecardView(rules: rules)
            .environment(\.gameDiceSet, diceSet))
    }

    public var rules: RulesDocument {
        RulesDocument(
            title: "Qwixx — Connected (The Chain)",
            subtitle: "Official rules for the Connected \u{201E}Kette\u{201C} variant (sheet A)",
            sections: [
                RulesSection(heading: "Goal", body: [
                    "Play classic Qwixx, but certain circled spaces are linked in pairs by a printed line. Crossing one space of a chain forces you to cross its partner too.",
                ]),
                RulesSection(heading: "The card", body: [
                    "Red and yellow rows run 2 → 12 (left to right). Green and blue rows run 12 → 2.",
                    "Several spaces are circled and joined to a partner in a neighbouring row by a short line. On this sheet the chains are: red 6 ↔ yellow 6, red 11 ↔ yellow 11, yellow 3 ↔ green 11, yellow 8 ↔ green 6, green 9 ↔ blue 9, and green 4 ↔ blue 4.",
                    "Each sheet (A–E) places the chains differently.",
                ]),
                RulesSection(heading: "Crossing out numbers", body: [
                    "All rules for crossing within each colour row stay completely unchanged: cross out from left to right, skipped numbers are lost, and the dice procedure and turn order are exactly as in classic Qwixx.",
                ]),
                RulesSection(heading: "The chains", body: [
                    "Whenever you cross a circled chain space (following the ordinary colour rules), you must automatically also cross its linked partner space.",
                    "This automatic co-marking happens always and at any point in the game. It does NOT obey the normal marking rules: the partner is crossed even if you have already marked further to the right of it, and even if that partner's row has already been locked.",
                    "Example: you have locked the yellow row. Later you legally cross a red chain space — its linked yellow chain space is still crossed automatically.",
                ]),
                RulesSection(heading: "Locking a row", body: [
                    "To cross the right-most number (12 for red/yellow, 2 for green/blue) you must already have at least 5 crosses in that row.",
                    "Crossing it deliberately locks the row and adds the lock as one extra cross. A forced chain co-mark never locks a row by itself.",
                ]),
                RulesSection(heading: "Penalties & game end", body: [
                    "If on your turn you cross nothing, take a penalty (−5 points). Four penalties end the game.",
                    "The game also ends the moment two rows are locked.",
                ]),
                RulesSection(heading: "Scoring", body: [
                    "Scoring is exactly classic Qwixx — the chains do not score separately. They simply let you place extra crosses.",
                    "Per colour, count its crosses (its own numbers + the lock, max 12) and score 1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66, 78. Every chained cross counts as a normal cross in its row.",
                    "Total = red + yellow + green + blue − (5 × penalties).",
                ]),
            ],
            source: "Qwixx Connected (\u{201E}Die Kette\u{201C} / The Chain, version B) by Steffen Benndorf, Nürnberger-Spielkarten-Verlag (NSV); art. 088 19900030; official scorecard & rules (nsv.de)."
        )
    }
}
