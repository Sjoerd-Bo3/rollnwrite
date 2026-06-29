//
//  ScorecardScaffold.swift
//  RollnWrite – Core
//
//  Reusable scorecard chrome shared by EVERY game. A game supplies only its pure
//  board view(s); the scaffold provides the compact in-board header (back, title,
//  optional two-player toggle, rules), the per-screen landscape lock, the rules
//  sheet, and the optional mirrored two-player layout.
//
//  This is the framework hook for the non-negotiable scorecard requirements in
//  CLAUDE.md: build a pure `…BoardView` for your game, then wrap it here — you
//  inherit fullscreen orientation handling and the across-the-table mirror for
//  free, exactly like `QwixxBoardView` + `QwixxScorecardView`.
//

import SwiftUI

public struct ScorecardScaffold<Board: View>: View {
    private let title: String
    private let rules: RulesDocument
    private let board: Board
    private let opponentBoard: Board?

    @Environment(\.dismiss) private var dismiss
    @State private var showRules = false
    @State private var twoPlayer = false

    /// - Parameters:
    ///   - board: the player's pure board view (no nav chrome).
    ///   - opponent: an independent second board for the across-the-table
    ///     mirror; pass `nil` to disable two-player.
    public init(
        title: String,
        rules: RulesDocument,
        @ViewBuilder board: () -> Board,
        opponent: (() -> Board)? = nil
    ) {
        self.title = title
        self.rules = rules
        self.board = board()
        self.opponentBoard = opponent?()
    }

    private var canMirror: Bool { opponentBoard != nil }

    public var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showRules) { RulesView(document: rules) }
        // Single player pins iPhone to landscape; two-player frees rotation so
        // the mirrored boards can stack in portrait.
        .landscapeLockediPhone(when: !twoPlayer)
    }

    @ViewBuilder private var content: some View {
        if canMirror, twoPlayer, let opponentBoard {
            // Across-the-table mirror (opponent rotated 180°). Stacking two
            // full-width boards is only comfortable in PORTRAIT; in landscape the
            // rows get too thin, so place the two boards SIDE BY SIDE instead.
            // Each board self-sizes to the half it's handed.
            GeometryReader { geo in
                let landscape = geo.size.width > geo.size.height
                let opponent = opponentBoard.rotationEffect(.degrees(180))
                if landscape {
                    HStack(spacing: 6) {
                        opponent
                        board
                    }
                } else {
                    VStack(spacing: 6) {
                        opponent
                        board
                    }
                }
            }
        } else {
            board
        }
    }

    /// Compact header that replaces the system nav bar so the board gets the
    /// full screen height.
    private var header: some View {
        HStack(spacing: 16) {
            Button { dismiss() } label: { Image(systemName: "chevron.left") }
            Text(title).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
            if canMirror {
                Button { twoPlayer.toggle() } label: {
                    Image(systemName: twoPlayer ? "person.fill" : "person.2.fill")
                }
                .accessibilityLabel(twoPlayer ? "Single player" : "Two players")
            }
            Button { showRules = true } label: { Image(systemName: "info.circle") }
        }
        .font(.title3)
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }
}

/// Square-capped, fill-the-screen tile sizing shared by banded boards.
///
/// Width fills the row edge-to-edge; height fills the row but is **capped at the
/// width (square is the max)** and floored at a readable minimum — so cramped
/// boards go rectangular and fill, roomy boards stay square and centre.
public enum BoardMetrics {
    /// - Parameters:
    ///   - columns: equal columns across the widest row.
    ///   - rowUnits: weighted row count for height (e.g. colour band 1.0,
    ///     bonus row 0.72, bottom bar 0.95 → sum them).
    public static func tile(
        in size: CGSize,
        columns: CGFloat,
        rowUnits: CGFloat,
        rowCount: CGFloat,
        gap: CGFloat = 4,
        pad: CGFloat = 4,
        minTile: CGFloat = 20
    ) -> (w: CGFloat, h: CGFloat) {
        let w = max(minTile, (size.width - 2 * pad - (columns - 1) * gap) / columns)
        let availH = size.height - 2 * pad
        let rowH = (availH - max(0, rowCount - 1) * gap) / max(1, rowUnits)
        let h = max(minTile, min(rowH * 0.86, w))
        return (w, h)
    }
}
