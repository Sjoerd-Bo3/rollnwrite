//
//  Lucky15ScorecardView.swift
//  RollnWrite – Qwixx Lucky15
//
//  The interactive Qwixx "Lucky 15" scorecard. Rule enforcement and scoring are
//  delegated to `Lucky15Game`; this file is presentation + touch handling only.
//
//  Built on the reusable scorecard framework: a pure `Lucky15BoardView` composes
//  the Core board components (colour bands, number/lock/score tiles, the bottom
//  bar) and `QwixxLucky15ScorecardView` wraps it in `ScorecardScaffold` to inherit
//  the compact header, landscape lock and rules sheet. Lucky15's variant-specific
//  Lucky 15 bonus track is rendered as an extra band of number tiles.
//

import SwiftUI

/// The pure banded board for one Lucky15 player — no navigation chrome, so it
/// can be wrapped by the shared `ScorecardScaffold`. Per-board controls (undo,
/// new game) live in its bottom bar, like the physical card's corner buttons.
struct Lucky15BoardView: View {
    @ObservedObject var game: Lucky15Game
    @State private var confirmReset = false

    private let tileGap: CGFloat = 4
    private let rowGap: CGFloat = 4
    private let outerPad: CGFloat = 4   // gap to the safe-area edge
    private let bandPad: CGFloat = 4    // coloured border inside each band
    // chevron + 11 numbers + lock + per-row score
    private let columns: CGFloat = 14

    /// Orange tint of the Lucky 15 track, matching the official sheet.
    static let luckyTint = Color(red: 0.93, green: 0.45, blue: 0.13)

    init(game: Lucky15Game) {
        _game = ObservedObject(wrappedValue: game)
    }

    var body: some View {
        GeometryReader { geo in
            // 4 colour bands + 1 Lucky 15 track band + bottom bar = 6 rows.
            let t = BoardMetrics.tile(in: geo.size, columns: columns,
                                      rowUnits: 4 + 0.82 + 1.05,
                                      rowCount: 6, gap: tileGap, pad: outerPad)
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
        let luckyH = th * 0.82
        let bottomH = th * 1.05
        return VStack(spacing: rowGap) {
            band(.red, w: w, tile: th)
            band(.yellow, w: w, tile: th)
            band(.green, w: w, tile: th)
            band(.blue, w: w, tile: th)
            luckyBand(w: w, h: luckyH)
            bottomBar(w: w, h: bottomH)
        }
    }

    /// One full-width colour band: a direction chevron, the eleven number tiles,
    /// the lock, and that colour's running score — all reusable Core components.
    private func band(_ color: GameColor, w: CGFloat, tile th: CGFloat) -> some View {
        HStack(spacing: tileGap) {
            BandChevron(w: w, h: th)
            ForEach(0..<11, id: \.self) { i in
                let marked = game.row(for: color).marks.contains(i)
                let undoable = marked && game.isLastColorMark(color, i)
                NumberTile("\(color.numbers[i])", tint: color.tint,
                           marked: marked, legal: game.canMarkColor(color, i),
                           undoable: undoable, w: w, h: th) {
                    if undoable { game.undo() } else { game.markColor(color, i) }
                }
                .accessibilityLabel("\(color.displayName) \(color.numbers[i])")
            }
            LockTile(tint: color.tint, locked: game.row(for: color).locked, w: w, h: th)
                .accessibilityLabel("\(color.displayName) lock")
            ScoreTile(game.points(for: color), w: w, h: th)
        }
        .colourBand(tint: color.tint, hPad: bandPad, vPad: th * 0.09, corner: min(w, th) * 0.3)
    }

    /// The orange Lucky 15 bonus track: four diamond-value fields crossed
    /// strictly left → right. Only the next uncrossed field is legal; the
    /// right-most crossed field is the tap-to-undo cell.
    private func luckyBand(w: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: tileGap) {
            BandChevron(w: w, h: h)
            ForEach(Array(Lucky15Track.values.enumerated()), id: \.offset) { idx, value in
                let marked = idx < game.lucky.crossed
                let isNext = idx == game.lucky.crossed && game.canMarkLucky()
                let undoable = marked && idx == game.lucky.crossed - 1 && game.isLastLuckyMark()
                NumberTile("\(value)", tint: Self.luckyTint,
                           marked: marked, legal: isNext,
                           undoable: undoable, w: w, h: h) {
                    if undoable { game.undo() } else { game.markLucky() }
                }
                .accessibilityLabel("Lucky 15 field \(value)")
            }
            // Pad out the remaining columns so the track aligns under the rows.
            Color.clear.frame(width: w * 7 + tileGap * 7, height: h)
            ScoreTile(game.luckyPoints, w: w, h: h)
                .accessibilityLabel("Lucky 15 bonus")
        }
        .colourBand(tint: Self.luckyTint, hPad: bandPad, vPad: h * 0.09, corner: min(w, h) * 0.3)
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
            ForEach(0..<Lucky15State.maxPenalties, id: \.self) { i in
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
// Owns its own `Lucky15Game` via the `@StateObject` property-default pattern and
// renders the board wrapped in the shared `ScorecardScaffold` (header, landscape
// lock, rules sheet).

/// Qwixx Lucky15: four classic colour rows (cap 12) plus the Lucky 15 track.
public struct QwixxLucky15ScorecardView: View {
    @StateObject private var game = Lucky15Game()
    let rules: RulesDocument

    public init(rules: RulesDocument) { self.rules = rules }

    public var body: some View {
        ScorecardScaffold(
            title: "Qwixx Lucky15",
            rules: rules,
            board: { Lucky15BoardView(game: game) }
        )
    }
}
