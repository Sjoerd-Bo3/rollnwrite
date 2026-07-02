//
//  QwixxMixxGame.swift
//  RollnWrite – Qwixx Mixx
//
//  The `GameDefinition` that registers Qwixx "gemixxt" (Mixx) in the catalogue
//  and wires up its rules and scorecard. A single entry hosts both official
//  boards (Variant A and Variant B) via the in-card segmented toggle.
//

import SwiftUI

public struct QwixxMixxGame: GameDefinition {
    public init() {}

    public let id = "qwixx-mixx"
    public let title = "Qwixx Mixx"
    public let subtitle = "Mixed-up rows · two boards (A & B)"
    public let iconSystemName = "shuffle"
    public let accent = Color(red: 0.86, green: 0.18, blue: 0.18)
    public let availability: GameAvailability = .available

    public func makeScorecardView() -> AnyView {
        AnyView(QwixxMixxScorecardView(rules: rules))
    }

    public var rules: RulesDocument {
        RulesDocument(
            title: "Qwixx — gemixxt (Mixx)",
            subtitle: "Official rules for the two Mixx boards (Variant A & Variant B)",
            sections: [
                RulesSection(heading: "Goal", body: [
                    "Qwixx gemixxt keeps every rule of classic Qwixx exactly the same — only the rows are mixed up. The set ships two boards; switch between them with the A / B toggle at the top of the card.",
                ]),
                RulesSection(heading: "Variant A — colour segments", body: [
                    "The four rows still run 2 → 12 (top two) and 12 → 2 (bottom two), exactly like the original.",
                    "But each row is split into small segments and every number cell belongs to one of the four die colours. To cross a cell you use a die of that cell's colour (or the two white dice), as in normal Qwixx.",
                    "Each row's lock (its band colour) marks which coloured die is removed from play when the row is closed: closing the red-locked row takes the red die out, and so on. After a colour die is gone you can still cross that colour's cells in the other rows with the two white dice (but never in a closed row).",
                ]),
                RulesSection(heading: "Variant B — scrambled numbers", body: [
                    "There is one row per die colour (red, yellow, green, blue), but the eleven numbers within each row are no longer ordered — they are scattered wildly.",
                    "You still cross strictly left → right, and to cross a number you must roll it with that row's coloured die (or the white dice). E.g. to cross an 11 in the red row you need an 11 in red.",
                    "As in Variant A, closing a row removes that colour's die from play.",
                ]),
                RulesSection(heading: "Crossing out numbers", body: [
                    "Within every row you must cross out from left to right. You may skip cells, but skipped cells can never be crossed later.",
                    "On a turn the white dice total may be crossed in any one row; the active player may also add a white die to a colour die and cross a matching cell.",
                ]),
                RulesSection(heading: "Locking a row", body: [
                    "To cross the right-most cell you must already have at least 5 crosses in that row.",
                    "Crossing it locks the row and counts as one extra cross — and removes the corresponding coloured die from the game for everyone.",
                ]),
                RulesSection(heading: "Penalties & game end", body: [
                    "If on your turn you cross nothing, take a penalty (−5 points). Four penalties end the game.",
                    "The game also ends the moment two rows are locked.",
                ]),
                RulesSection(heading: "Scoring", body: [
                    "Scoring is identical to classic Qwixx. Per row, count its crosses (its own numbers + the lock, max 12) and score 1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66, 78.",
                    "Total = row 1 + row 2 + row 3 + row 4 − (5 × penalties).",
                ]),
            ],
            source: "Qwixx gemixxt by Nürnberger-Spielkarten-Verlag (NSV, art. 4033) / White Goblin Games; official score sheet & rules."
        )
    }
}
