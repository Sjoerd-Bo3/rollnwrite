//
//  Connect15ScorecardView.swift
//  RollnWrite – Qwixx Connect15
//
//  The interactive Qwixx "Connect 15" scorecard. Rule enforcement and scoring are
//  delegated to `Connect15Game`; this file is presentation + touch handling only.
//
//  Built on the reusable scorecard framework: a pure `Connect15BoardView`
//  (fullscreen, edge-to-edge, square-capped tiles via `BoardMetrics.tile`,
//  composed from the Core `BoardComponents`) plus a thin wrapper that drops the
//  board into `ScorecardScaffold` for the header, landscape lock and rules sheet.
//
//  Connect15 specifics: every colour row carries three "connection" fields, each
//  a small square straddling the gap between two adjacent number tiles at the
//  positions printed on the official sheet (`Connect15Layout`). They carry no
//  number (link glyph), join the row's single left-to-right sequence, and count
//  as extra crosses — raising each row's cap to 15 (120 points).
//

import SwiftUI

/// The pure banded board for one player — no navigation chrome. Per-board
/// controls (undo, new game) live in its bottom bar, like the printed card's
/// corner buttons.
struct Connect15BoardView: View {
    @ObservedObject var game: Connect15Game
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

    // chevron + 11 numbers + lock + per-row score. The three connection fields
    // straddle the gaps between number tiles, so they take no column of their own.
    private let columns: CGFloat = 14

    init(game: Connect15Game, scoreTitle: String) {
        _game = ObservedObject(wrappedValue: game)
        self.scoreTitle = scoreTitle
    }

    var body: some View {
        GeometryReader { geo in
            // 4 colour bands + 1 bottom bar; bottom bar ≈ 0.95 of a band's height.
            let t = BoardMetrics.tile(
                in: geo.size,
                columns: columns,
                rowUnits: 4 + 0.95,
                rowCount: 5,
                gap: tileGap,
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
    }

    // MARK: - Colour band
    //
    // A row renders, left → right: a direction chevron, the eleven number tiles,
    // the lock, and the running score. The three connection fields don't occupy
    // columns of their own — each is a small square OVERLAID on the gap between
    // the two number tiles it connects (`Connect15Layout.connectionColumns`),
    // like the printed sheet, where the square straddles the boundary.

    private func band(_ color: GameColor, w: CGFloat, tile th: CGFloat) -> some View {
        let row = game.row(for: color)
        return HStack(spacing: tileGap) {
            BandChevron(w: w, h: th)
            numberStrip(color, w: w, th: th)
            LockTile(tint: color.tint, locked: row.locked,
                     undoable: row.locked && game.isLastConcede(color),
                     w: w, h: th) {
                tapLock(color)
            }
            .accessibilityLabel("\(color.displayName) lock")
            ScoreTile(game.points(for: color), w: w, h: th)
        }
        .colourBand(tint: color.tint, hPad: bandPad, vPad: th * 0.09, corner: min(w, th) * 0.3)
    }

    /// The eleven number tiles with the row's three connection squares overlaid
    /// on the gaps at their printed positions. Within the strip, the gap after
    /// number column `i` is centred at `i·(w+gap) + w + gap/2`; the square is
    /// vertically centred (the overlay's `.leading` alignment) and offset there.
    private func numberStrip(_ color: GameColor, w: CGFloat, th: CGFloat) -> some View {
        let columns = Connect15Layout.columns(for: color)
        let s = min(w, th) * 0.52
        return HStack(spacing: tileGap) {
            ForEach(0..<11, id: \.self) { i in
                numberTile(color, i, w: w, th: th)
            }
        }
        .overlay(alignment: .leading) {
            ForEach(Array(columns.enumerated()), id: \.offset) { field, column in
                let gapCenter = CGFloat(column) * (w + tileGap) + w + tileGap / 2
                connectionTile(color, field: field, size: s)
                    .offset(x: gapCenter - s / 2)
            }
        }
    }

    private func numberTile(_ color: GameColor, _ i: Int, w: CGFloat, th: CGFloat) -> some View {
        let marked = game.row(for: color).marks.contains(i)
        let undoable = marked && game.isLastColorMark(color, i)
        return NumberTile("\(color.numbers[i])", tint: color.tint,
                          marked: marked, legal: game.canMarkColor(color, i),
                          undoable: undoable, w: w, h: th) {
            if undoable { game.undo() } else { game.markColor(color, i) }
        }
        .accessibilityLabel("\(color.displayName) \(color.numbers[i])")
    }

    /// One connection field. `field` is its 0-based ordinal within the row's
    /// three fields. Any unmarked field right of the row's highest mark is legal
    /// (the engine's interleaved rule — skipping forfeits, exactly like numbers);
    /// only the most recent action's mark is ringed and tap-undoable.
    private func connectionTile(_ color: GameColor, field: Int, size: CGFloat) -> some View {
        let marked = game.connections(for: color).marks.contains(field)
        let legal = game.canMarkConnection(color, field: field)
        let undoable = marked && game.isLastConnectionMark(color, field)
        return ConnectionTile(
            tint: color.tint,
            marked: marked,
            legal: legal,
            undoable: undoable,
            size: size
        ) {
            if undoable { game.undo() } else if legal { game.markConnection(color, field: field) }
        }
        .accessibilityLabel("\(color.displayName) connection field \(field + 1)")
    }

    // MARK: - Bottom bar
    //
    // Controls (undo, new game) on the left; penalties + running total on the
    // right — echoing the corner buttons on the printed card.

    private func bottomBar(w: CGFloat, h: CGFloat) -> some View {
        let b = min(h, 64)
        return HStack(spacing: tileGap) {
            BoardControlButton("arrow.uturn.backward", size: b) { game.undo() }
                .disabled(!game.canUndo)
                .opacity(game.canUndo ? 1 : 0.4)
            BoardControlButton("trash", size: b) { confirmReset = true }
            BoardControlButton("flag.checkered", size: b) { confirmFinish = true }
                .disabled(game.isGameOver)
                .opacity(game.isGameOver ? 0.4 : 1)
            Spacer(minLength: w * 0.1)
            ForEach(0..<Connect15State.maxPenalties, id: \.self) { i in
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

/// A Connect15 "connection" square: a small dashed-edged light square that
/// straddles the boundary between two number tiles, carrying a link glyph
/// (uncrossed) or an X (crossed) — matching the printed sheet. Sits on top of
/// the number strip, so when inert it lets touches pass through to the tiles
/// beneath its overhang.
private struct ConnectionTile: View {
    let tint: Color
    let marked: Bool
    let legal: Bool
    let undoable: Bool
    let size: CGFloat
    let onTap: () -> Void

    var body: some View {
        let s = size
        let dimmed = !marked && !legal
        return Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                    .fill(Color.white.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                            .strokeBorder(tint,
                                          style: StrokeStyle(lineWidth: s * 0.07, dash: [s * 0.16, s * 0.1]))
                    )
                if marked {
                    Image(systemName: "xmark")
                        .font(.system(size: s * 0.66, weight: .black))
                        .foregroundStyle(tint)
                } else {
                    Image(systemName: "link")
                        .font(.system(size: s * 0.46, weight: .bold))
                        .foregroundStyle(tint)
                }
            }
            .frame(width: s, height: s)
            .shadow(color: .black.opacity(0.2), radius: 1)
            .overlay(
                RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                    .strokeBorder(tint, lineWidth: undoable ? 2.5 : 0)
            )
        }
        .buttonStyle(.plain)
        .disabled(!(legal || undoable))
        .allowsHitTesting(legal || undoable)
        .opacity(dimmed ? 0.35 : 1)
        .accessibilityValue(marked ? "marked" : (legal ? "available" : "blocked"))
        .accessibilityHint(undoable ? "Tap to undo" : "")
        .animation(.easeOut(duration: 0.12), value: marked)
    }
}

/// Hosts one Connect15 board, wrapping it in the shared `ScorecardScaffold`
/// (header, landscape lock, rules). The chrome is reused from Core.
public struct Connect15ScorecardView: View {
    @ObservedObject var game: Connect15Game
    let rules: RulesDocument

    public init(game: Connect15Game, rules: RulesDocument) {
        _game = ObservedObject(wrappedValue: game)
        self.rules = rules
    }

    public var body: some View {
        ScorecardScaffold(
            title: title,
            rules: rules,
            board: { Connect15BoardView(game: game, scoreTitle: title) }
        )
    }

    /// The board's display title — also the high-score key (`HighScores`), so a
    /// game's best is stored under the same name shown in the header.
    private let title = "Qwixx Connect15"
}

// MARK: - Variant owner
//
// Owns its own `Connect15Game` via the `@StateObject` property-default pattern
// and renders the scorecard.

/// Qwixx Connect15: four classic colour rows plus three connection fields each
/// (cap 15 → 120).
public struct QwixxConnect15ScorecardView: View {
    @StateObject private var game = Connect15Game()
    let rules: RulesDocument

    public init(rules: RulesDocument) { self.rules = rules }

    public var body: some View {
        Connect15ScorecardView(game: game, rules: rules)
    }
}
