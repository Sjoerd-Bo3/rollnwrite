//
//  GameDefinition.swift
//  RollnWrite – Core
//
//  The extension point of the whole app. Every roll-and-write game is described
//  by a `GameDefinition` and registered in `GameRegistry`.
//
//  SOLID notes:
//  - OCP: to add a game you create a new `GameDefinition` and add it to the
//         registry. No existing type (RootView, registry consumers) is modified.
//  - DIP: the catalogue UI depends on this abstraction, never on a concrete game.
//  - LSP: any `GameDefinition` can stand in for another wherever one is expected.
//  - ISP: the protocol carries only what the catalogue and navigation need.
//

import SwiftUI

/// Whether a registered game can be played yet.
public enum GameAvailability {
    case available
    case comingSoon
}

/// Describes one roll-and-write game (or variant) for the catalogue and routing.
public protocol GameDefinition {
    /// Stable identifier, also used as the persistence namespace.
    var id: String { get }
    var title: String { get }
    var subtitle: String { get }
    /// SF Symbol used in the catalogue.
    var iconSystemName: String { get }
    /// Brand colour for the row / scorecard accents.
    var accent: Color { get }
    var availability: GameAvailability { get }
    var rules: RulesDocument { get }

    /// Factory for the game's scorecard screen.
    ///
    /// Returning `AnyView` keeps the protocol free of associated types so a
    /// heterogeneous `[GameDefinition]` registry is possible (type erasure is the
    /// deliberate trade-off for an open, list-driven catalogue).
    @MainActor func makeScorecardView() -> AnyView
}

/// The single source of truth for which games exist.
///
/// This is the *only* place touched when shipping a new game — the embodiment of
/// the Open/Closed Principle for this app.
@MainActor
public enum GameRegistry {
    public static let games: [GameDefinition] = [
        QwixxBigPointsGame(),
        QwixxClassicGame(),
        QwixxLucky15Game(),
        QwixxConnect15Game(),
        QwixxConnectedGame(),
        QwixxXChangeGame(),
        QwixxDoubleGame(),
        QwixxBonusGame(),
        QwixxMixxGame(),
        ThatsPrettyCleverGame(),
        TwiceAsCleverGame(),
        CleverCubedGame(),
        Clever4everGame(),

        // Future variants slot in here with zero changes elsewhere.
    ]

    public static var playable: [GameDefinition] {
        games.filter { $0.availability == .available }
    }

    public static var upcoming: [GameDefinition] {
        games.filter { $0.availability == .comingSoon }
    }
}

/// Lightweight placeholder definition for games on the roadmap.
///
/// Demonstrates the registry pattern: a brand-new game type drops in without
/// editing any existing game. Provides empty rules and an unavailable view.
public struct ComingSoonGame: GameDefinition {
    public let id: String
    public let title: String
    public let subtitle: String
    public let iconSystemName: String
    public let accent: Color
    public let availability: GameAvailability = .comingSoon

    public init(id: String, title: String, subtitle: String, iconSystemName: String, accent: Color) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconSystemName = iconSystemName
        self.accent = accent
    }

    public var rules: RulesDocument {
        RulesDocument(
            title: title,
            subtitle: "Coming soon",
            sections: [RulesSection(heading: "Coming soon", body: ["This game hasn't been added yet."])],
            source: "—"
        )
    }

    public func makeScorecardView() -> AnyView {
        AnyView(
            ContentUnavailableView(
                "Coming soon",
                systemImage: "hourglass",
                description: Text("\(title) hasn't been added yet.")
            )
        )
    }
}
