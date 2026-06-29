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
    @State private var confirmReset = false

    private let tileGap: CGFloat = 4
    private let rowGap: CGFloat = 4
    private let outerPad: CGFloat = 4   // gap to the safe-area edge
    private let bandPad: CGFloat = 4    // coloured border inside each band
    // chevron + 11 numbers + lock + per-row score
    private let columns: CGFloat = 14

    init(game: BonusGame) {
        _game = ObservedObject(wrappedValue: game)
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
                ZStack {
                    NumberTile("\(color.numbers[i])", tint: color.tint,
                               marked: marked, legal: game.canMarkColor(color, i),
                               undoable: undoable, w: w, h: th) {
                        if undoable { game.undo() } else { game.markColor(color, i) }
                    }
                    // Boxed bonus numbers wear a heavy black outline, matching the
                    // printed sheet. Decorative only — it never blocks taps.
                    if game.isBoxed(color, i) {
                        RoundedRectangle(cornerRadius: min(w, th) * 0.18, style: .continuous)
                            .strokeBorder(.black, lineWidth: 2.5)
                            .frame(width: w, height: th)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel("\(color.displayName) \(color.numbers[i])")
            }
            LockTile(tint: color.tint, locked: row.locked, w: w, h: th)
                .accessibilityLabel("\(color.displayName) lock")
            ScoreTile(game.points(for: color), w: w, h: th)
        }
        .colourBand(tint: color.tint, hPad: bandPad, vPad: th * 0.09, corner: min(w, th) * 0.3)
    }

    /// The snaking bonus bar: twelve coloured fields, crossed left-to-right as
    /// boxed numbers are hit. Aligned under the number tiles (offset past the
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
        let isCrossed = idx < game.bar.crossed
        return ZStack {
            RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                .fill(color.tint)
                .overlay(
                    RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                        .strokeBorder(.black.opacity(0.25), lineWidth: 1)
                )
            if isCrossed {
                Image(systemName: "xmark")
                    .font(.system(size: s * 0.6, weight: .black))
                    .foregroundStyle(color.textColor)
            }
        }
        .frame(width: w, height: h)
        .opacity(isCrossed ? 1 : 0.5)
        .accessibilityLabel("Bonus \(color.displayName)")
        .accessibilityValue(isCrossed ? "crossed" : "open")
    }

    /// Controls (undo, new game) on the left; penalties + running total on the
    /// right — echoing the printed card's corner buttons.
    private func bottomBar(w: CGFloat, h: CGFloat) -> some View {
        let b = min(h, 64)
        return HStack(spacing: tileGap) {
            BoardControlButton("arrow.uturn.backward", size: b) { game.undo() }
                .disabled(!game.canUndo)
                .opacity(game.canUndo ? 1 : 0.4)
            BoardControlButton("trash", size: b) { confirmReset = true }
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
            board: { BonusBoardView(game: game) }
        )
    }
}
