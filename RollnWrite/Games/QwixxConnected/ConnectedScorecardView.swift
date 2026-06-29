//
//  ConnectedScorecardView.swift
//  RollnWrite – Qwixx Connected
//
//  The interactive Qwixx "Connected" (The Chain) scorecard. Rule enforcement and
//  scoring are delegated to `ConnectedGame`; this file is presentation + touch
//  handling only.
//
//  Built on the shared scorecard framework: a pure `ConnectedBoardView` rendered
//  fullscreen edge-to-edge with `BoardMetrics` + the Core board components, plus a
//  thin `QwixxConnectedScorecardView` wrapper that adds the compact header,
//  landscape lock, and rules sheet via `ScorecardScaffold`. Mirrors
//  `QwixxBoardView` / `QwixxScorecardView`.
//
//  Chain spaces are rendered as the underlying colour `NumberTile` wearing a
//  dashed ring (matching the printed circled chain fields). Crossing one chain
//  space automatically crosses its partner — handled entirely by the engine.
//

import SwiftUI

/// The pure banded Connected board for one player — no navigation chrome, so it
/// can be hosted on its own (or, in future, two-up mirrored). Per-board controls
/// (undo, new game) live in its bottom bar, like the physical card's corners.
struct ConnectedBoardView: View {
    @ObservedObject var game: ConnectedGame
    @State private var confirmReset = false

    private let tileGap: CGFloat = 4
    private let rowGap: CGFloat = 4
    private let outerPad: CGFloat = 4   // gap to the safe-area edge
    private let bandPad: CGFloat = 4    // coloured border inside each band
    // chevron + 11 numbers + lock + per-row score
    private let columns: CGFloat = 14

    init(game: ConnectedGame) {
        _game = ObservedObject(wrappedValue: game)
    }

    var body: some View {
        GeometryReader { geo in
            let t = BoardMetrics.tile(
                in: geo.size,
                columns: columns,
                rowUnits: 4 + 0.95,   // 4 colour bands + bottom bar
                rowCount: 5,
                gap: rowGap,
                pad: outerPad
            )
            boardStack(w: t.w, h: t.h)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(outerPad)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .confirmationDialog("Start a new game?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("New game", role: .destructive) { game.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears the current scorecard.")
        }
    }

    // MARK: - Board

    private func boardStack(w: CGFloat, h: CGFloat) -> some View {
        let th = h
        let bottomH = th * 1.05
        return VStack(spacing: rowGap) {
            band(.red, w: w, tile: th)
            band(.yellow, w: w, tile: th)
            band(.green, w: w, tile: th)
            band(.blue, w: w, tile: th)
            bottomBar(w: w, h: bottomH)
        }
    }

    /// One full-width colour band: a direction chevron, the eleven number tiles
    /// (chain spaces ringed), the lock, and that colour's running score — all
    /// reusable Core components.
    private func band(_ color: GameColor, w: CGFloat, tile th: CGFloat) -> some View {
        HStack(spacing: tileGap) {
            BandChevron(w: w, h: th)
            ForEach(0..<11, id: \.self) { i in
                numberTile(color, index: i, w: w, th: th)
            }
            LockTile(tint: color.tint, locked: game.row(for: color).locked, w: w, h: th)
                .accessibilityLabel("\(color.displayName) lock")
            ScoreTile(game.points(for: color), w: w, h: th)
        }
        .colourBand(tint: color.tint, hPad: bandPad, vPad: th * 0.09, corner: min(w, th) * 0.3)
    }

    /// A single number tile, with the dashed chain ring overlaid for circled
    /// chain spaces. The deliberately-crossed cell is tap-undoable; a forced
    /// partner co-mark is undone together with it, so only the deliberate cell
    /// shows the undo ring.
    @ViewBuilder
    private func numberTile(_ color: GameColor, index i: Int, w: CGFloat, th: CGFloat) -> some View {
        let marked = game.isMarked(color, i)
        let undoable = marked && game.isLastColorMark(color, i)
        let isChain = game.isChainSpace(color, i)
        ZStack {
            NumberTile("\(color.numbers[i])", tint: color.tint,
                       marked: marked, legal: game.canMarkColor(color, i),
                       undoable: undoable, w: w, h: th) {
                if undoable { game.undo() } else { game.markColor(color, i) }
            }
            .accessibilityLabel("\(color.displayName) \(color.numbers[i])")
            .accessibilityHint(isChain ? "Chain field — crossing it also crosses its partner" : "")

            if isChain {
                Circle()
                    .strokeBorder(
                        color.textColor.opacity(0.9),
                        style: StrokeStyle(lineWidth: 2, dash: [3, 2.5])
                    )
                    .frame(width: min(w, th), height: min(w, th))
                    .padding(2)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: w, height: th)
    }

    /// Controls (undo, new game) on the left, penalties + running total on the
    /// right — echoing the corner buttons on the printed card.
    private func bottomBar(w: CGFloat, h: CGFloat) -> some View {
        let b = min(h, 64)
        return HStack(spacing: tileGap) {
            BoardControlButton("arrow.uturn.backward", size: b) { game.undo() }
                .disabled(!game.canUndo)
                .opacity(game.canUndo ? 1 : 0.4)
            BoardControlButton("trash", size: b) { confirmReset = true }
            Spacer(minLength: w * 0.1)
            ForEach(0..<ConnectedState.maxPenalties, id: \.self) { i in
                let isNext = i == game.penalties && game.canAddPenalty()
                PenaltyBox(
                    filled: i < game.penalties,
                    isNext: isNext,
                    undoable: i == game.penalties - 1 && game.isLastPenalty(),
                    size: b
                ) {
                    if isNext { game.addPenalty() } else { game.undo() }
                }
                .accessibilityLabel("Penalty \(i + 1)")
            }
            if game.isGameOver {
                Image(systemName: "flag.checkered").foregroundStyle(.secondary)
            }
            Text("Total")
                .font(.system(size: b * 0.34, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("\(game.totalScore)")
                .font(.system(size: b * 0.55, weight: .heavy, design: .rounded).monospacedDigit())
        }
        .frame(maxWidth: .infinity)
        .frame(height: h)
        .padding(.horizontal, bandPad)
    }
}

// MARK: - Variant owner
//
// Owns its own `ConnectedGame` via the `@StateObject` property-default pattern
// (which stays clear of strict-concurrency init isolation issues) and renders the
// pure board inside the shared `ScorecardScaffold` (header, landscape lock,
// rules sheet).

/// Qwixx Connected (The Chain): four classic colour rows (cap 12) with linked
/// chain spaces that auto-cross their partner.
public struct QwixxConnectedScorecardView: View {
    @StateObject private var game = ConnectedGame()
    let rules: RulesDocument

    public init(rules: RulesDocument) { self.rules = rules }

    public var body: some View {
        ScorecardScaffold(
            title: "Qwixx Connected",
            rules: rules,
            board: { ConnectedBoardView(game: game) }
        )
    }
}
