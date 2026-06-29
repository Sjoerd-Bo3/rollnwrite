//
//  DoubleScorecardView.swift
//  RollnWrite – Qwixx Double
//
//  The interactive Qwixx "Double" scorecard (Variant A — "double crosses"),
//  built on the reusable scorecard framework: a pure `DoubleBoardView` rendered
//  fullscreen edge-to-edge via `BoardMetrics` + Core board components, wrapped in
//  the shared `ScorecardScaffold` (compact header, landscape lock, rules sheet).
//
//  Rule enforcement and scoring are delegated to `DoubleGame`; this file is
//  presentation + touch handling only. Each colour band is a full-width coloured
//  band of number tiles (the canonical Qwixx look), with a thin "second cross"
//  strip directly beneath, mirroring the printed sheet where the second cross is
//  drawn below the number. Only the most-recently crossed space's second-cross
//  cell is tappable. Tapping the single most-recent mark un-checks it (LIFO).
//

import SwiftUI

/// The pure banded board for one player — no navigation chrome. Per-board
/// controls (undo, new game) live in its bottom bar, like the physical card's
/// corner buttons.
struct DoubleBoardView: View {
    @ObservedObject var game: DoubleGame
    @State private var confirmReset = false

    private let tileGap: CGFloat = 4
    private let rowGap: CGFloat = 4
    private let outerPad: CGFloat = 4   // gap to the safe-area edge
    private let bandPad: CGFloat = 4    // coloured border inside each band
    // chevron + 11 numbers + lock + per-row score
    private let columns: CGFloat = 14

    init(game: DoubleGame) {
        _game = ObservedObject(wrappedValue: game)
    }

    var body: some View {
        GeometryReader { geo in
            // Four colour bands, each with a half-height second-cross strip
            // (≈0.55× a tile), plus the bottom bar.
            let (w, h) = BoardMetrics.tile(
                in: geo.size,
                columns: columns,
                rowUnits: 4 * (1 + 0.55) + 1.05,
                rowCount: 4 * 2 + 1,
                gap: rowGap,
                pad: outerPad,
                minTile: 18
            )
            boardStack(w: w, h: h)
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
        let stripH = max(12, h * 0.55)
        let bottomH = h * 1.05
        return VStack(spacing: rowGap) {
            band(.red, w: w, tile: h, strip: stripH)
            band(.yellow, w: w, tile: h, strip: stripH)
            band(.green, w: w, tile: h, strip: stripH)
            band(.blue, w: w, tile: h, strip: stripH)
            bottomBar(w: w, h: bottomH)
        }
    }

    /// One full-width colour band: a direction chevron, the eleven number tiles,
    /// the lock and running score (reusable Core components), with the thin
    /// second-cross strip drawn directly beneath the number tiles.
    private func band(_ color: GameColor, w: CGFloat, tile th: CGFloat, strip stripH: CGFloat) -> some View {
        let row = game.row(for: color)
        return VStack(spacing: 2) {
            HStack(spacing: tileGap) {
                BandChevron(w: w, h: th)
                ForEach(0..<11, id: \.self) { i in
                    let marked = row.marks.contains(i)
                    let undoable = marked && game.isLastColorMark(color, i)
                    NumberTile("\(color.numbers[i])", tint: color.tint,
                               marked: marked, legal: game.canMarkColor(color, i),
                               undoable: undoable, w: w, h: th) {
                        if undoable { game.undo() } else { game.markColor(color, i) }
                    }
                    .accessibilityLabel("\(color.displayName) \(color.numbers[i])")
                }
                LockTile(tint: color.tint, locked: row.locked, w: w, h: th)
                    .accessibilityLabel("\(color.displayName) lock")
                ScoreTile(game.points(for: color), w: w, h: th)
            }
            // Second-cross strip: a thinner cell under each number. Only the
            // most-recent space is tappable; already-doubled spaces show a mark.
            HStack(spacing: tileGap) {
                Color.clear.frame(width: w, height: stripH) // chevron column
                ForEach(0..<11, id: \.self) { i in
                    secondCrossCell(color, index: i, row: row, w: w, h: stripH)
                }
                Color.clear.frame(width: w * 2 + tileGap, height: stripH) // lock + score columns
            }
        }
        .colourBand(tint: color.tint, hPad: bandPad, vPad: th * 0.09, corner: min(w, th) * 0.3)
    }

    /// The "draw a second cross below" cell for one column. Marked when the
    /// number was crossed twice; tappable only on the most-recent space. Tapping
    /// the single most-recent double un-checks it (LIFO undo).
    private func secondCrossCell(_ color: GameColor, index i: Int, row: DoubleColorRow,
                                 w: CGFloat, h: CGFloat) -> some View {
        let isDoubled = row.doubles.contains(i)
        let isLegal = game.canDoubleColor(color, i)
        let undoable = isDoubled && game.isLastDoubleMark(color, i)
        let active = isDoubled || isLegal
        let s = min(w, h)
        return ZStack {
            RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                .fill(Color.white.opacity(active ? 0.85 : 0.0))
                .overlay(
                    RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                        .strokeBorder(undoable ? color.tint : Color.white.opacity(active ? 0.6 : 0.25),
                                      style: StrokeStyle(lineWidth: undoable ? 2.5 : 1,
                                                         dash: (isDoubled || undoable) ? [] : [2, 2]))
                )
            if isDoubled {
                Image(systemName: "xmark")
                    .font(.system(size: s * 0.7, weight: .black))
                    .foregroundStyle(color.tint)
            } else if isLegal {
                Text("+1×")
                    .font(.system(size: s * 0.42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
            }
        }
        .frame(width: w, height: h)
        .opacity(active ? 1 : 0.25)
        .contentShape(Rectangle())
        .onTapGesture {
            if undoable { game.undo() }
            else if isLegal { game.doubleColor(color, i) }
        }
        .accessibilityLabel("\(color.displayName) \(color.numbers[i]) second cross")
        .accessibilityValue(isDoubled ? "marked" : (isLegal ? "available" : "blocked"))
        .accessibilityHint(undoable ? "Tap to undo" : "")
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
            ForEach(0..<DoubleState.maxPenalties, id: \.self) { i in
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

// MARK: - Wrapper + variant owner

/// Hosts one Qwixx Double board, wrapping it in the shared `ScorecardScaffold`
/// (header, landscape lock, rules sheet). All the chrome is reused from Core.
public struct DoubleScorecardView: View {
    @ObservedObject var game: DoubleGame
    let rules: RulesDocument

    public init(game: DoubleGame, rules: RulesDocument) {
        _game = ObservedObject(wrappedValue: game)
        self.rules = rules
    }

    public var body: some View {
        ScorecardScaffold(
            title: "Qwixx Double",
            rules: rules,
            board: { DoubleBoardView(game: game) }
        )
    }
}

/// Qwixx Double: four classic colour rows where the most-recent cross can be
/// doubled, scored up to 16 crosses per row (cap 16).
public struct QwixxDoubleScorecardView: View {
    @StateObject private var game = DoubleGame()
    let rules: RulesDocument

    public init(rules: RulesDocument) { self.rules = rules }

    public var body: some View {
        DoubleScorecardView(game: game, rules: rules)
    }
}
