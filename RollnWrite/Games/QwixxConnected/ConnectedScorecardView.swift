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
//  dashed ring, and each pair is joined by a short dashed connector line —
//  matching the printed circled-and-linked chain fields. Crossing one chain
//  space automatically crosses its partner — handled entirely by the engine.
//

import SwiftUI

/// The pure banded Connected board for one player — no navigation chrome, so it
/// can be hosted on its own (or, in future, two-up mirrored). Per-board controls
/// (undo, new game) live in its bottom bar, like the physical card's corners.
struct ConnectedBoardView: View {
    @ObservedObject var game: ConnectedGame
    let scoreTitle: String
    @State private var confirmReset = false
    @State private var showResults = false
    @State private var confirmConcede: GameColor?
    @State private var confirmFinish = false
    @State private var newBest = false

    private let tileGap: CGFloat = 4
    private let rowGap: CGFloat = 4
    private let outerPad: CGFloat = 4   // gap to the safe-area edge
    private let bandPad: CGFloat = 4    // coloured border inside each band
    // chevron + 11 numbers + lock + per-row score
    private let columns: CGFloat = 14

    init(game: ConnectedGame, scoreTitle: String) {
        _game = ObservedObject(wrappedValue: game)
        self.scoreTitle = scoreTitle
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
        // Content stays inside the bottom safe area so the bar never collides
        // with the home indicator (the window background fills behind us).
        .confirmationDialog("Start a new game?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("New game", role: .destructive) { game.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears the current scorecard.")
        }
        .confirmationDialog("Finish the game?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Finish", role: .destructive) { game.finishGame() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("End the game now and show the final score.")
        }
        .confirmationDialog(
            "Close this colour?",
            isPresented: Binding(get: { confirmConcede != nil },
                                 set: { if !$0 { confirmConcede = nil } }),
            titleVisibility: .visible,
            presenting: confirmConcede
        ) { color in
            Button("Close \(color.displayName) — no points", role: .destructive) {
                game.concedeRow(color); confirmConcede = nil
            }
            Button("Cancel", role: .cancel) { confirmConcede = nil }
        } message: { color in
            Text("Use this when another player locked \(color.displayName). The row closes but you score no lock bonus.")
        }
        .overlay {
            if showResults {
                GameOverCard(
                    lines: GameColor.allCases.map {
                        GameOverCard.Line(label: $0.displayName, value: game.points(for: $0), tint: $0.tint)
                    } + (game.penaltyPoints > 0
                         ? [GameOverCard.Line(label: "Penalties", value: -game.penaltyPoints, tint: .red)]
                         : []),
                    total: game.totalScore,
                    best: HighScores.best(for: scoreTitle),
                    isNewBest: newBest,
                    onNewGame: { game.reset(); showResults = false },
                    onDismiss: { withAnimation { showResults = false } }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .onChange(of: game.isGameOver) { _, isOver in
            if isOver {
                newBest = HighScores.record(game.totalScore, for: scoreTitle)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showResults = true }
            } else {
                showResults = false
            }
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
        // The printed sheet joins each circled chain pair with a short line —
        // draw the connectors on top of the stack (they never intercept taps).
        .overlay { chainLinks(w: w, th: th) }
    }

    /// Dashed connector lines between the two dashed circles of every chain,
    /// like the printed sheet. All six chains join ADJACENT rows in the SAME
    /// column, so each connector is a short vertical dashed segment from the
    /// bottom edge of the upper ring to the top edge of the lower ring.
    ///
    /// Geometry mirrors `band(_:w:tile:)` exactly: a band is `1.18·th` tall
    /// (tile + 2×0.09 vertical padding) and starts at `row·(1.18·th + rowGap)`;
    /// within it, column `c`'s tile centre sits at
    /// `bandPad + (c+1)·(w+tileGap) + w/2` (chevron occupies column 0). The
    /// ring's diameter is `min(w, th)` (see `numberTile`).
    private func chainLinks(w: CGFloat, th: CGFloat) -> some View {
        let bandH = th * 1.18
        let dia = min(w, th)
        let colors = GameColor.allCases
        return Canvas { ctx, _ in
            for chain in ConnectedLayout.chains {
                guard
                    let rowA = colors.firstIndex(of: chain.a.color),
                    let rowB = colors.firstIndex(of: chain.b.color)
                else { continue }
                let top = min(rowA, rowB)
                let bottom = max(rowA, rowB)
                let x = bandPad + CGFloat(chain.a.index + 1) * (w + tileGap) + w / 2
                let tileCentre = th * 0.09 + th / 2
                let yTop = CGFloat(top) * (bandH + rowGap) + tileCentre + dia / 2 - 1
                let yBottom = CGFloat(bottom) * (bandH + rowGap) + tileCentre - dia / 2 + 1
                var path = Path()
                path.move(to: CGPoint(x: x, y: yTop))
                path.addLine(to: CGPoint(x: x, y: yBottom))
                ctx.stroke(path, with: .color(.primary.opacity(0.55)),
                           style: StrokeStyle(lineWidth: 2, dash: [3, 2.5]))
            }
        }
        .allowsHitTesting(false)
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
            LockTile(tint: color.tint, locked: game.row(for: color).locked,
                     undoable: game.row(for: color).locked && game.isLastConcede(color),
                     w: w, h: th) {
                tapLock(color)
            }
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
        let row = game.row(for: color)
        let marked = game.isMarked(color, i)
        let undoable = marked && game.isLastColorMark(color, i)
        let isChain = game.isChainSpace(color, i)
        let forfeited = !marked && (i < row.maxMarkedIndex || row.locked)
        ZStack {
            NumberTile("\(color.numbers[i])", tint: color.tint,
                       marked: marked, legal: game.canMarkColor(color, i),
                       undoable: undoable, forfeited: forfeited, w: w, h: th) {
                if undoable { game.undo() } else { game.markColor(color, i) }
            }
            .accessibilityLabel("\(color.displayName) \(color.numbers[i])")
            .accessibilityHint(isChain ? "Chain field — crossing it also crosses its partner" : "")

            // Dashed chain ring in the ROW'S TINT — the same colour as the
            // tile's number, which is known-legible on the tile's fixed
            // near-white fill in both light and dark mode. (`textColor` is the
            // legible colour over the BAND, i.e. white for red/green/blue — on
            // the white tile that made the ring invisible everywhere but the
            // yellow row.)
            if isChain {
                Circle()
                    .strokeBorder(
                        color.tint,
                        style: StrokeStyle(lineWidth: BoardStroke.small(min(w, th)), dash: [3, 2.5])
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
        // One shared control height `b` and one baseline for every element.
        let b = min(h, 64)
        return HStack(alignment: .center, spacing: tileGap) {
            BoardControlButton("arrow.uturn.backward", size: b) { game.undo() }
                .disabled(!game.canUndo)
                .opacity(game.canUndo ? 1 : 0.4)
            BoardControlButton("trash", size: b) { confirmReset = true }
            BoardControlButton("flag.checkered", size: b) { confirmFinish = true }
                .disabled(game.isGameOver)
                .opacity(game.isGameOver ? 0.4 : 1)
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
                    .frame(height: b)
            }
            Text("Total")
                .font(.system(size: b * 0.34, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(height: b)
            Text("\(game.totalScore)")
                .font(.system(size: b * 0.55, weight: .heavy, design: .rounded).monospacedDigit())
                .frame(height: b)
        }
        .frame(maxWidth: .infinity)
        .frame(height: h)
        .padding(.horizontal, bandPad)
    }

    /// Tapping the padlock concedes the colour — closes the row for no points
    /// after another player locked it — behind a confirmation, or undoes a
    /// just-made concession. A self-locked row's padlock is inert (undo its
    /// number instead).
    private func tapLock(_ color: GameColor) {
        if game.isLastConcede(color) {
            game.undo()
        } else if game.canConcedeRow(color) {
            confirmConcede = color
        }
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
            board: { ConnectedBoardView(game: game, scoreTitle: "Qwixx Connected") }
        )
    }
}
