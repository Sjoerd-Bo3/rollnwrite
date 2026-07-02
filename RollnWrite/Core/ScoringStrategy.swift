//
//  ScoringStrategy.swift
//  RollnWrite – Core
//
//  Game-agnostic scoring abstractions.
//
//  SOLID notes:
//  - SRP: scoring math lives here, separate from game state and views.
//  - OCP: new scoring rules are added by creating a new `ScoringStrategy`
//         conformer; existing games and engines never change.
//  - DIP: game engines depend on the `ScoringStrategy` abstraction and have a
//         concrete strategy injected, rather than hard-coding a formula.
//

import Foundation

/// Maps a number of marks ("crosses") to a point value for a single track.
///
/// Different roll-and-write games (and even different rows within a game) score
/// crosses differently. Conform a new type to plug in new behaviour without
/// modifying the engines that consume it.
public protocol ScoringStrategy {
    /// Points awarded for `crosses` marks on a single track.
    func points(forCrosses crosses: Int) -> Int
}

/// Classic Qwixx scoring: the *n*-th cross is worth a cumulative triangular
/// total `n * (n + 1) / 2` — i.e. 1, 3, 6, 10, 15, 21, … points.
///
/// In *Qwixx Big Points* a colour may earn up to 15 valued crosses (120 points),
/// so the strategy is capped. The base game caps at 12 (78 points).
public struct TriangularScoring: ScoringStrategy {
    /// Maximum number of crosses that are valued; extra crosses score nothing more.
    public let cap: Int

    public init(cap: Int) {
        self.cap = cap
    }

    public func points(forCrosses crosses: Int) -> Int {
        let n = min(max(crosses, 0), cap)
        return n * (n + 1) / 2
    }
}

/// Common surface every game's score model exposes to generic UI/host code.
///
/// ISP: deliberately tiny — hosts that only need a headline score and a
/// game-over flag don't have to know any game-specific detail.
///
/// Main-actor isolated: every conformer is a `@MainActor` engine driving
/// SwiftUI, so the protocol carries the isolation (required in Swift 6).
@MainActor
public protocol Scoreboard: ObservableObject {
    /// The current overall score.
    var totalScore: Int { get }
    /// Whether the game has reached an end condition.
    var isGameOver: Bool { get }
    /// Whether there is an action available to undo.
    var canUndo: Bool { get }
    /// Reverse the most recent action.
    func undo()
    /// Clear the card back to a fresh game.
    func reset()
}
