//
//  BonusScorecardView.swift
//  RollnWrite – Qwixx Bonus
//
//  The interactive Qwixx "Bonus" (version A) scorecard. Rule enforcement and
//  scoring are delegated to `BonusGame`; this file is presentation + touch
//  handling only.
//
//  Built on the shared scorecard framework: a pure `BonusBoardView` renders the
//  board fullscreen edge-to-edge via `BoardMetrics` + Core components, and a thin
//  `QwixxBonusScorecardView` wraps it in `ScorecardScaffold` (compact header,
//  landscape lock, rules sheet — no system nav bar). Mirrors `QwixxBoardView` /
//  `QwixxScorecardView`.
//
//  Variant twist preserved: twelve black-boxed numbers across the four rows feed
//  a snaking twelve-field bonus bar (the `BonusLayout.barColors` sequence). The
//  boxed cells wear a heavy black outline; the bar is auto-advanced by the engine
//  and rendered here as a coloured band below the rows.
//

import SwiftUI

/// The pure banded board for one player — no navigation chrome. Per-board
/// controls (undo, new game) live in its bottom bar, like the printed card.
struct BonusBoardView: View {
    @ObservedObject var game: BonusGame
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

    init(game: BonusGame, scoreTitle: String) {
        _game = ObservedObject(wrappedValue: game)
        self.scoreTitle = scoreTitle
    }

    var body: some View {
        GeometryReader { geo in
            // 4 colour bands + bonus bar (≈0.82) + bottom bar (≈1.05).
            let t = BoardMetrics.tile(
                in: geo.size,
                columns: columns,
                rowUnits: 4 + 0.82 + 1.05,
                rowCount: 6,
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
            Text("Use this when another player locked \(color.displayName). The row closes but you score no lock bonus, and its remaining bonus-bar fields are forfeited.")
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
        let barH = h * 0.82
        let bottomH = h * 1.05
        return VStack(spacing: rowGap) {
            band(.red, w: w, tile: h)
            band(.yellow, w: w, tile: h)
            band(.green, w: w, tile: h)
            band(.blue, w: w, tile: h)
            bonusBar(w: w, h: barH)
            bottomBar(w: w, h: bottomH)
        }
    }

    /// One full-width colour band: direction chevron, eleven number tiles (boxed
    /// ones outlined), the lock indicator, and the row's running score.
    private func band(_ color: GameColor, w: CGFloat, tile th: CGFloat) -> some View {
        let row = game.row(for: color)
        return HStack(spacing: tileGap) {
            BandChevron(w: w, h: th)
            ForEach(0..<11, id: \.self) { i in
                let marked = row.marks.contains(i)
                let undoable = marked && game.isLastColorMark(color, i)
                let forfeited = !marked && (i < row.maxMarkedIndex || row.locked)
                ZStack {
                    NumberTile("\(color.numbers[i])", tint: color.tint,
                               marked: marked, legal: game.canMarkColor(color, i),
                               undoable: undoable, forfeited: forfeited, w: w, h: th) {
                        if undoable { game.undo() } else { game.markColor(color, i) }
                    }
                    // Boxed bonus numbers wear a heavy black outline, matching the
                    // printed sheet. Decorative only — it never blocks taps.
                    if game.isBoxed(color, i) {
                        RoundedRectangle(cornerRadius: min(w, th) * 0.18, style: .continuous)
                            .strokeBorder(.black, lineWidth: BoardStroke.small(min(w, th)))
                            .frame(width: w, height: th)
                            .allowsHitTesting(false)
                    }
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
        .colourBand(tint: color.tint, hPad: bandPad, vPad: th * 0.09, corner: min(w, th) * 0.3)
    }

    /// The snaking bonus bar: twelve coloured fields, earned left-to-right as
    /// boxed numbers are hit — skipping any field forfeited because its colour
    /// row was completed. Aligned under the number tiles (offset past the
    /// chevron column). The engine advances it automatically; it is read-only.
    private func bonusBar(w: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: tileGap) {
            Color.clear.frame(width: w, height: h) // chevron column
            ForEach(Array(BonusLayout.barColors.enumerated()), id: \.offset) { idx, color in
                barField(idx: idx, color: color, w: w, h: h)
                    .frame(width: w, height: h)
            }
            // Remaining columns: pad out to the full 11-number + lock + score grid.
            let used = CGFloat(BonusLayout.barCount)
            let remaining = (columns - 1) - used // minus the chevron column
            if remaining > 0 {
                Color.clear.frame(width: w * remaining + tileGap * (remaining - 1), height: h)
            }
        }
        .padding(.horizontal, bandPad)
        .frame(maxWidth: .infinity)
    }

    private func barField(idx: Int, color: GameColor, w: CGFloat, h: CGFloat) -> some View {
        let s = min(w, h)
        let isEarned = game.bar.earned.contains(idx)
        let isForfeited = game.bar.forfeited.contains(idx)
        return ZStack {
            // Light base so an unearned field clearly shows its colour in dark
            // mode too (a bare low-opacity tint sank into the black background).
            RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                .fill(Color.white.opacity(0.9))
            RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                .fill(color.tint.opacity(isEarned ? 1 : 0.3))
            RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                .strokeBorder(isEarned ? Color.black.opacity(0.25) : color.tint.opacity(0.9),
                              lineWidth: BoardStroke.small(s))
            if isEarned {
                Image(systemName: "xmark")
                    .font(.system(size: s * 0.6, weight: .black))
                    .foregroundStyle(color.textColor)
            } else if isForfeited {
                // Forfeited fields keep the slash but stay identifiable by
                // colour: the slash is drawn in the field's own tint on the
                // light-tinted base.
                Image(systemName: "line.diagonal")
                    .font(.system(size: s * 0.7, weight: .regular))
                    .foregroundStyle(color.tint)
            }
        }
        .frame(width: w, height: h)
        .opacity(isEarned ? 1 : (isForfeited ? 0.55 : 0.9))
        .accessibilityLabel("Bonus \(color.displayName)")
        .accessibilityValue(isEarned ? "crossed" : (isForfeited ? "forfeited" : "open"))
    }

    /// Controls (undo, new game) on the left; penalties + running total on the
    /// right — echoing the printed card's corner buttons.
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
            ForEach(0..<BonusState.maxPenalties, id: \.self) { i in
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
// Owns its own `BonusGame` via the `@StateObject` property-default pattern and
// wraps the pure board in the shared `ScorecardScaffold`.

/// Qwixx Bonus (version A): four classic colour rows (cap 12) plus the bonus bar.
public struct QwixxBonusScorecardView: View {
    @StateObject private var game = BonusGame()
    let rules: RulesDocument

    public init(rules: RulesDocument) { self.rules = rules }

    public var body: some View {
        ScorecardScaffold(
            title: "Qwixx Bonus",
            rules: rules,
            board: { BonusBoardView(game: game, scoreTitle: "Qwixx Bonus") }
        )
    }
}
