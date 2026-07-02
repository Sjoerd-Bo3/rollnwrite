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

    init(game: DoubleGame, scoreTitle: String) {
        _game = ObservedObject(wrappedValue: game)
        self.scoreTitle = scoreTitle
    }

    var body: some View {
        GeometryReader { geo in
            // Sizing must model the TRUE rendered height so the board fills the
            // screen exactly (no overflow, no dead space). Per colour band:
            //   number row 1.00·h + strip 0.55·h + colourBand vPad 2×0.09·h
            //   = 1.73·h, plus the band's inner VStack(spacing: 2) = rowGap/2.
            // Bottom bar = 1.05·h. Fixed gaps: 4 stack gaps (rowGap) between the
            // 5 VStack children + 4 intra-band 2pt spacings = 6·rowGap total,
            // i.e. rowCount 7. minTile 22 keeps 0.55·h ≥ the strip's 12pt floor
            // so the unit math stays exact.
            //   → 4 × 1.73 + 1.05 = 7.97 units, 6 × rowGap fixed.
            let (w, h) = BoardMetrics.tile(
                in: geo.size,
                columns: columns,
                rowUnits: 4 * (1 + 0.55 + 2 * 0.09) + 1.05,
                rowCount: 7,
                gap: rowGap,
                pad: outerPad,
                minTile: 22
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
        // 12pt legibility floor; inert while h ≥ minTile (22 × 0.55 ≥ 12), so
        // the sizing above stays exact.
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
        return VStack(spacing: rowGap / 2) {   // counted as half a gap in sizing
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
                LockTile(tint: color.tint, locked: row.locked,
                         undoable: row.locked && game.isLastConcede(color),
                         w: w, h: th) {
                    tapLock(color)
                }
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
            BoardControlButton("flag.checkered", size: b) { confirmFinish = true }
                .disabled(game.isGameOver)
                .opacity(game.isGameOver ? 0.4 : 1)
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
            board: { DoubleBoardView(game: game, scoreTitle: "Qwixx Double") }
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
