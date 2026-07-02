//
//  CleverV3GameDefinition.swift
//  RollnWrite – Clever
//
//  Registers "That's Pretty Clever (v3)" — an EXPERIMENTAL, landscape-optimised
//  reflow of the Clever 1 sheet. Same game, same official rules and the SAME
//  saved state as the regular entry (shared persistence key): the two
//  catalogue entries are two lenses on one running game.
//

import SwiftUI

public struct ThatsPrettyCleverV3Game: GameDefinition {
    public init() {}

    public let id = "clever-v3"
    public let title = "That's Pretty Clever (v3)"
    public let subtitle = "Landscape layout experiment · shares your Clever game"
    public let iconSystemName = "rectangle.split.2x1"
    public let accent = Color(red: 0.55, green: 0.28, blue: 0.72)
    public let availability: GameAvailability = .available

    /// Same physical dice as the regular entry (one shared set).
    public var diceSet: [DieSpec]? { cleverDice }

    public func makeScorecardView() -> AnyView {
        AnyView(CleverV3ScorecardView(rules: rules)
            .environment(\.gameDiceSet, diceSet))
    }

    /// The rules are identical to the regular entry — only the layout differs.
    public var rules: RulesDocument { cleverRulesDocument() }
}
