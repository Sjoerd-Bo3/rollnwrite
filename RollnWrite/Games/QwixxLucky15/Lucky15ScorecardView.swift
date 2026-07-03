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

    /// Orange tint of the Lucky 15 track, matching the official sheet.
    static let luckyTint = Color(red: 0.93, green: 0.45, blue: 0.13)

    init(game: Lucky15Game, scoreTitle: String) {
        _game = ObservedObject(wrappedValue: game)
        self.scoreTitle = scoreTitle
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
                    } + [GameOverCard.Line(label: "Lucky 15", value: game.luckyPoints, tint: Self.luckyTint)]
                    + (game.penaltyPoints > 0
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

    /// The orange Lucky 15 bonus track: four diamond-value fields (the printed
    /// sheet's diamonds) crossed strictly left → right. Only the next uncrossed
    /// field is legal; the right-most crossed field is the tap-to-undo cell.
    /// The chevron column matches the colour bands' (same leading position and
    /// width), the diamonds distribute EVENLY across the band like the printed
    /// sheet, and the track's score keeps the trailing score-chip column.
    private func luckyBand(w: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: tileGap) {
            BandChevron(w: w, h: h)
            HStack(spacing: 0) {
                ForEach(Array(Lucky15Track.values.enumerated()), id: \.offset) { idx, value in
                    Spacer(minLength: 0)
                    let marked = idx < game.lucky.crossed
                    let isNext = idx == game.lucky.crossed && game.canMarkLucky()
                    let undoable = marked && idx == game.lucky.crossed - 1 && game.isLastLuckyMark()
                    LuckyDiamondTile(value: value, tint: Self.luckyTint,
                                     marked: marked, legal: isNext,
                                     undoable: undoable, w: w, h: h) {
                        if undoable { game.undo() } else { game.markLucky() }
                    }
                    .accessibilityLabel("Lucky 15 field \(value)")
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            ScoreTile(game.luckyPoints, w: w, h: h)
                .accessibilityLabel("Lucky 15 bonus")
        }
        .colourBand(tint: Self.luckyTint, hPad: bandPad, vPad: h * 0.09, corner: min(w, h) * 0.3)
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
                .accessibilityLabel("Undo")
            BoardControlButton("arrow.uturn.forward", size: b) { game.redo() }
                .disabled(!game.canRedo)
                .opacity(game.canRedo ? 1 : 0.4)
                .accessibilityLabel("Redo")
            BoardControlButton("trash", size: b) { confirmReset = true }
            BoardControlButton("flag.checkered", size: b) { confirmFinish = true }
                .disabled(game.isGameOver)
                .opacity(game.isGameOver ? 0.4 : 1)
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

/// A Lucky 15 track field: a white diamond (the shared Core `Diamond` shape,
/// exactly as printed on the official sheet and as used by X-Change) carrying
/// the field's point value, crossed when marked. Follows the same sizing /
/// crossed-out / undo-ring conventions as the Core tiles.
private struct LuckyDiamondTile: View {
    let value: Int
    let tint: Color
    let marked: Bool
    let legal: Bool
    let undoable: Bool
    let w: CGFloat
    let h: CGFloat
    let onTap: () -> Void

    var body: some View {
        let d = min(w, h)
        return Button(action: onTap) {
            ZStack {
                Diamond()
                    .fill(Color.white.opacity(0.95))
                Diamond()
                    .strokeBorder(tint.opacity(0.85), lineWidth: BoardStroke.small(d))
                Text("\(value)")
                    .font(.system(size: d * 0.32, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
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
            .animation(.spring(response: 0.26, dampingFraction: 0.6), value: marked)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(legal || undoable)
        .opacity(marked || legal ? 1 : 0.4)
        .accessibilityValue(marked ? "crossed" : (legal ? "available" : "blocked"))
        .accessibilityHint(undoable ? "Tap to undo" : "")
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
            board: { Lucky15BoardView(game: game, scoreTitle: "Qwixx Lucky15") }
        )
    }
}
