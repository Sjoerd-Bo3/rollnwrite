//
//  XChangeScorecardView.swift
//  RollnWrite – Qwixx X-Change
//
//  The interactive Qwixx "X-Change" scorecard. Rule enforcement and scoring are
//  delegated to `XChangeGame`; this file is presentation + touch handling only.
//
//  Built on the reusable scorecard framework: a pure `XChangeBoardView` renders
//  the banded board fullscreen edge-to-edge via `BoardMetrics` + Core components
//  (`NumberTile`, `LockTile`, `ScoreTile`, `PenaltyBox`, `BoardControlButton`,
//  `BandChevron`, `.colourBand`), and the thin `XChangeScorecardView` wraps it in
//  the shared `ScorecardScaffold` (compact header, landscape lock, rules sheet) —
//  mirroring `QwixxBoardView` / `QwixxScorecardView`.
//
//  The X-Change swap row (nine two-number diamonds) is the variant-specific part;
//  it is composed from a small inline diamond tile that follows the same sizing /
//  crossed-out / tap-to-undo conventions as the Core components.
//

import SwiftUI

/// The pure banded board for one X-Change player — no navigation chrome, so it
/// fills the screen and could be shown two-up (mirrored) if ever desired. Per-
/// board controls (undo, new game) live in its bottom bar.
struct XChangeBoardView: View {
    @ObservedObject var game: XChangeGame
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

    /// The X-Change row's deep magenta (presentation only).
    static let xchangeTint = Color(red: 0.55, green: 0.10, blue: 0.42)

    init(game: XChangeGame, scoreTitle: String) {
        _game = ObservedObject(wrappedValue: game)
        self.scoreTitle = scoreTitle
    }

    var body: some View {
        GeometryReader { geo in
            // Weighted row units = the TRUE rendered height of each row in tile
            // heights `h`, so the six rows fill the screen with no overflow:
            //   • colour band ×4 — tile h + `.colourBand` vPad (h·0.09 top and
            //     bottom)                          → 1.18 h each (cf. QwixxBoardView)
            //   • X-Change band  — content 1.15 h (two stacked numbers) + ITS
            //     vPad (1.15h·0.07 top and bottom) → 1.15 × 1.14 = 1.311 h
            //   • bottom bar     — frame(height: h·1.05), no vertical padding
            //                                       → 1.05 h
            //   Σ = 4×1.18 + 1.15×1.14 + 1.05 = 7.081 units across 6 rows (5 gaps).
            let t = BoardMetrics.tile(
                in: geo.size,
                columns: columns,
                rowUnits: 4 * 1.18 + 1.15 * 1.14 + 1.05,
                rowCount: 6,
                gap: tileGap,
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
        let xchangeH = h * 1.15
        let bottomH = h * 1.05
        return VStack(spacing: rowGap) {
            band(.red, w: w, tile: h)
            band(.yellow, w: w, tile: h)
            band(.green, w: w, tile: h)
            band(.blue, w: w, tile: h)
            xchangeBand(w: w, h: xchangeH)
            bottomBar(w: w, h: bottomH)
        }
    }

    /// One full-width colour band: a direction chevron, the eleven number tiles,
    /// the lock, and that colour's running score — all reusable Core components.
    private func band(_ color: GameColor, w: CGFloat, tile th: CGFloat) -> some View {
        let row = game.row(for: color)
        return HStack(spacing: tileGap) {
            BandChevron(w: w, h: th)
            ForEach(0..<11, id: \.self) { i in
                let marked = row.marks.contains(i)
                let undoable = marked && game.isLastColorMark(color, i)
                let forfeited = !marked && (i < row.maxMarkedIndex || row.locked)
                NumberTile("\(color.numbers[i])", tint: color.tint,
                           marked: marked, legal: game.canMarkColor(color, i),
                           undoable: undoable, forfeited: forfeited, w: w, h: th) {
                    if undoable { game.undo() } else { game.markColor(color, i) }
                }
                .accessibilityLabel("\(color.displayName) \(color.numbers[i])")
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

    /// The X-Change swap row: nine two-number diamonds, distributed EVENLY
    /// across the full band width like the printed sheet, with a leading
    /// direction chevron aligned with the colour bands' chevron column (the
    /// row is crossed strictly left → right). Scores no points — a swap tool.
    private func xchangeBand(w: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: tileGap) {
            BandChevron(w: w, h: h)
            HStack(spacing: 0) {
                ForEach(0..<XChangeRow.count, id: \.self) { i in
                    Spacer(minLength: 0)
                    let marked = game.xchange.marks.contains(i)
                    let undoable = marked && game.isLastXChangeMark(i)
                    let forfeited = !marked && i < game.xchange.maxMarkedIndex
                    XChangeTile(
                        pair: XChangeRow.pair(i),
                        tint: Self.xchangeTint,
                        marked: marked,
                        legal: game.canMarkXChange(i),
                        undoable: undoable,
                        forfeited: forfeited,
                        w: w,
                        h: h
                    ) {
                        if undoable { game.undo() } else { game.markXChange(i) }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .colourBand(tint: Self.xchangeTint, hPad: bandPad, vPad: h * 0.07,
                    corner: min(w, h) * 0.3)
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
            ForEach(0..<XChangeState.maxPenalties, id: \.self) { i in
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

/// A single X-Change diamond: a white diamond (the shared Core `Diamond`
/// shape, as printed on the official sheet) with the deep-magenta border, the
/// top number above the swap arrows and the bottom number below, crossed when
/// marked. Follows the same sizing / crossed-out / undo-ring conventions as
/// the Core tiles, but is X-Change-specific (two numbers + swap glyph) so it
/// stays in this module.
private struct XChangeTile: View {
    let pair: (top: Int, bottom: Int)
    let tint: Color
    let marked: Bool
    let legal: Bool
    let undoable: Bool
    let forfeited: Bool
    let w: CGFloat
    let h: CGFloat
    let onTap: () -> Void

    private var dimmed: Bool { !marked && !legal }

    var body: some View {
        // The diamond's point-to-point extent: the largest rotated square that
        // fits the w×h slot without clipping the neighbouring tiles.
        let d = min(w, h)
        return Button(action: onTap) {
            ZStack {
                // Uniform near-opaque white whether crossed or not — only the
                // undo ring distinguishes the last cross (no two-tier look).
                Diamond()
                    .fill(Color.white.opacity(0.95))
                Diamond()
                    .strokeBorder(tint.opacity(0.85), lineWidth: BoardStroke.small(d))
                // The numbers sit in the diamond's narrow vertical points, so
                // they are scaled to the width available there (≈0.54·d at the
                // top number's line), not to the full tile.
                VStack(spacing: d * 0.02) {
                    Text("\(pair.top)")
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: d * 0.16, weight: .bold))
                        .foregroundStyle(tint.opacity(0.7))
                    Text("\(pair.bottom)")
                }
                .font(.system(size: d * 0.23, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.3)
                .lineLimit(1)
                // Skipped-forever diamonds wear a subtle slash (still dim).
                if forfeited && !marked {
                    Image(systemName: "line.diagonal")
                        .font(.system(size: d * 0.62, weight: .regular))
                        .foregroundStyle(tint.opacity(0.5))
                }
                if marked {
                    Image(systemName: "xmark")
                        .font(.system(size: d * 0.5, weight: .black))
                        .foregroundStyle(tint)
                }
            }
            .frame(width: w, height: h)
            .overlay(
                Diamond()
                    .strokeBorder(tint, lineWidth: undoable ? BoardStroke.medium(d) : 0)
            )
        }
        .buttonStyle(.plain)
        // Not `.disabled` — the plain style dims disabled labels, which faded
        // crossed-but-not-last diamonds (see NumberTile).
        .allowsHitTesting(legal || undoable)
        .opacity(dimmed ? 0.4 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("X-Change \(pair.top) swap \(pair.bottom)")
        .accessibilityValue(marked ? "crossed" : (legal ? "available" : (forfeited ? "forfeited" : "blocked")))
        .accessibilityHint(undoable ? "Tap to undo" : "")
    }
}

/// Hosts one X-Change board, wrapping it in the shared `ScorecardScaffold`
/// (header, landscape lock, rules sheet). All the chrome is reused from Core —
/// this is just the X-Change-specific wiring of board + rules.
public struct XChangeScorecardView: View {
    @ObservedObject var game: XChangeGame
    let rules: RulesDocument

    public init(game: XChangeGame, rules: RulesDocument) {
        _game = ObservedObject(wrappedValue: game)
        self.rules = rules
    }

    public var body: some View {
        ScorecardScaffold(
            title: "Qwixx X-change",
            rules: rules,
            board: { XChangeBoardView(game: game, scoreTitle: "Qwixx X-change") }
        )
    }
}

// MARK: - Variant owner
//
// Owns its own `XChangeGame` via the `@StateObject` property-default pattern and
// renders the scorecard.

/// Qwixx X-Change: four classic colour rows (cap 12) plus the X-Change swap row.
public struct QwixxXChangeScorecardView: View {
    @StateObject private var game = XChangeGame()
    let rules: RulesDocument

    public init(rules: RulesDocument) { self.rules = rules }

    public var body: some View {
        XChangeScorecardView(game: game, rules: rules)
    }
}
