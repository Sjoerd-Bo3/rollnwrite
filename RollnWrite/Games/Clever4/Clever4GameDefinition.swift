//
//  Clever4GameDefinition.swift
//  RollnWrite – Clever4
//

import SwiftUI

public struct Clever4everGame: GameDefinition {
    public init() {}

    public let id = "clever-4"
    public let title = "Clever 4ever"
    public let subtitle = "Score calculator · yellow, blue, grey, green, pink"
    public let iconSystemName = "brain.head.profile"
    public let accent = Color(red: 0.20, green: 0.62, blue: 0.30)
    public let availability: GameAvailability = .available

    public func makeScorecardView() -> AnyView { AnyView(Clever4ScorecardView(rules: rules)) }

    public var rules: RulesDocument {
        RulesDocument(
            title: "Clever 4ever",
            subtitle: "Official rules — Wolfgang Warsch / Schmidt Spiele",
            sections: [
                RulesSection(heading: "Areas", body: [
                    "Five areas: yellow (three rows — ascending top, negative middle, positive bottom), blue (cross a cell by blue+white coordinates), grey (cross a polyomino of size = grey die), green and pink.",
                    "White is wild. Each fox scores your lowest area.",
                ]),
                RulesSection(heading: "This version", body: [
                    "Clever 4ever's board (polyominoes, coordinates) isn't interactive in the app yet, and its per-row/column point tables are printed only on the physical sheet.",
                    "So this is a scorecard calculator: enter each area total from your sheet and the app computes foxes (× your lowest area) and the grand total. The interactive board can be added once the official sheet is transcribed.",
                ]),
            ],
            source: "Clever 4ever by Wolfgang Warsch, Schmidt Spiele (art. 49424); official rulebook."
        )
    }
}
