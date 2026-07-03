//
//  QwixxScorecardView.swift
//  RollnWrite – Qwixx
//
//  The interactive Qwixx Big Points scorecard. Rule enforcement and scoring are
//  delegated to `QwixxGame`; this file is presentation + touch handling only.
//

import SwiftUI

/// The pure banded board for one player — no navigation chrome, so it can be
/// shown on its own or two-up (mirrored) on iPad. Per-board controls (undo,
/// new game) live in its bottom bar, like the physical card's corner buttons.
struct QwixxBoardView: View {
    @ObservedObject var game: QwixxGame
    let scoreTitle: String
    @State private var confirmReset = false
    @State private var showResults = false
    @State private var confirmConcede: GameColor?
    @State private var confirmFinish = false
    @State private var newBest = false
    /// Where leftover height parks (two-player portrait anchors outward).
    @Environment(\.boardAnchor) private var boardAnchor

    private let tileGap: CGFloat = 4
    private let rowGap: CGFloat = 4
    private let outerPad: CGFloat = 4   // gap to the safe-area edge
    private let bandPad: CGFloat = 4    // coloured border inside each band
    // chevron + 11 numbers + lock + per-row score
    private let columns: CGFloat = 14

    init(game: QwixxGame, scoreTitle: String) {
        _game = ObservedObject(wrappedValue: game)
        self.scoreTitle = scoreTitle
    }

    var body: some View {
        GeometryReader { geo in
            let s = sizing(for: geo.size)
            boardStack(w: s.w, th: s.th)
                // Leftover height goes where the host asks: `.center` alone
                // (the default), `.bottom` in the two-player portrait stack so
                // the board hugs its player's table edge (see ScorecardScaffold).
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: boardAnchor)
                .padding(outerPad)
        }
        // Content stays inside the bottom safe area so the bar's controls and
        // penalties never collide with the home indicator (the window background
        // already fills the full screen behind us).
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

    // MARK: - Sizing (fill the screen in any orientation)

    private struct BoardLayout { let w: CGFloat; let th: CGFloat }

    /// Tiles fill the FULL width edge-to-edge (`w`) AND the full height: the tile
    /// height grows to consume the screen, capped at the tile width (square is the
    /// MAX — never tall-skinny) and floored at a readable MIN. Dense boards
    /// (Big Points: 4 bands + 2 bonus rows) fill rectangularly; roomy boards
    /// (classic: 4 bands) hit the square cap and centre the leftover.
    private func sizing(for size: CGSize) -> BoardLayout {
        let bonusRows = CGFloat(game.hasBonusRows ? 2 : 0)
        let bandCount: CGFloat = 4
        let children = bandCount + bonusRows + 1 // colour bands + bonus rows + bottom bar
        let gaps = max(0, children - 1)

        let availW = size.width - 2 * outerPad
        let w = max(14, (availW - (columns - 1) * tileGap - 2 * bandPad) / columns)

        // Each row's height as a multiple of the tile height `th`:
        //   • colour band  = tile + its vertical band padding (2×0.09·th)
        //                                                   → 1.18·th
        //   • bonus row    = 0.82·th of circles + 2×0.09·th vertical breathing
        //     pad, so the tile↔circle visual gap (0.09·th band pad + rowGap +
        //     0.09·th bonus pad) EQUALS the tile↔tile gap across two plain
        //     bands (0.09 + rowGap + 0.09) — one vertical rhythm
        //                                                   → 1.00·th
        //   • bottom bar   = 1.05·th (fixed frame, no padding)
        // Solve for the `th` that fills the available height exactly, then cap
        // at the width and floor at the min.
        let units = bandCount * 1.18 + bonusRows * 1.00 + 1.05
        let availH = size.height - 2 * outerPad
        let fill = (availH - gaps * rowGap) / units
        let th = max(20, min(fill, w))
        return BoardLayout(w: w, th: th)
    }

    // MARK: - Board

    private func boardStack(w: CGFloat, th: CGFloat) -> some View {
        let bonusH = th * 0.82
        let bonusVPad = th * 0.09   // matches the bands' vPad → equal rhythm (see sizing)
        let bottomH = th * 1.05
        return VStack(spacing: rowGap) {
            band(.red, w: w, tile: th)
            if game.hasBonusRows { bonusBand(.redYellow, w: w, h: bonusH, vPad: bonusVPad) }
            band(.yellow, w: w, tile: th)
            band(.green, w: w, tile: th)
            if game.hasBonusRows { bonusBand(.greenBlue, w: w, h: bonusH, vPad: bonusVPad) }
            band(.blue, w: w, tile: th)
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
                // Skipped-forever: left of the row's front, or unmarked in a
                // locked row (nothing right of the front can ever be marked).
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

    /// Big-Points bonus row: the two-colour spaces, aligned under the number
    /// tiles (offset past the chevron column). `vPad` is the same 0.09·th the
    /// colour bands use, so the board keeps one vertical rhythm (see sizing).
    private func bonusBand(_ id: BonusRowID, w: CGFloat, h: CGFloat, vPad: CGFloat) -> some View {
        let bonus = game.bonus(id)
        let (a, b) = id.colors
        return HStack(spacing: tileGap) {
            Color.clear.frame(width: w, height: h) // chevron column
            ForEach(0..<11, id: \.self) { i in
                let undoable = bonus.marks.contains(i) && game.isLastBonusMark(id, i)
                BonusTile("\(bonus.numbers[i])", tintA: a.tint, tintB: b.tint,
                          marked: bonus.marks.contains(i), legal: game.canMarkBonus(id, i),
                          aActive: game.row(for: a).marks.contains(i),
                          bActive: game.row(for: b).marks.contains(i),
                          undoable: undoable) {
                    if undoable { game.undo() } else { game.markBonus(id, i) }
                }
                .frame(width: w, height: h)
            }
            Color.clear.frame(width: w * 2 + tileGap, height: h) // lock + score columns
        }
        .padding(.horizontal, bandPad)
        .padding(.vertical, vPad)
        .frame(maxWidth: .infinity)
    }

    /// Controls (undo, new game) on the left, penalties + running total on the
    /// right — echoing the corner buttons on the printed card.
    private func bottomBar(w: CGFloat, h: CGFloat) -> some View {
        // One shared control height `b` and one baseline: buttons, penalty
        // boxes, flag, the Total label and the score all centre in the same
        // fixed-height strip.
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
            ForEach(0..<QwixxState.maxPenalties, id: \.self) { i in
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
                .contentTransition(.numericText())
                .animation(.snappy, value: game.totalScore)
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

/// Hosts one Qwixx board, wrapping it in the shared `ScorecardScaffold` (header,
/// landscape lock, rules, optional two-player mirror). All the chrome is reused
/// from Core — this is just the Qwixx-specific wiring of board + opponent.
public struct QwixxScorecardView: View {
    @ObservedObject var game: QwixxGame
    private let opponent: QwixxGame?
    let rules: RulesDocument
    let navigationTitle: String

    public init(game: QwixxGame, opponent: QwixxGame? = nil, rules: RulesDocument, navigationTitle: String) {
        _game = ObservedObject(wrappedValue: game)
        self.opponent = opponent
        self.rules = rules
        self.navigationTitle = navigationTitle
    }

    public var body: some View {
        ScorecardScaffold(
            title: navigationTitle,
            rules: rules,
            board: { QwixxBoardView(game: game, scoreTitle: navigationTitle) },
            opponent: opponent.map { opp in { QwixxBoardView(game: opp, scoreTitle: navigationTitle) } }
        )
    }
}

// MARK: - Variant owners
//
// Each owns its own `QwixxGame` via the `@StateObject` property-default pattern
// (which stays clear of strict-concurrency init isolation issues) and renders the
// shared `QwixxScorecardView`.

/// Qwixx Big Points: the two bonus rows, scoring capped at 15.
public struct QwixxBigPointsScorecardView: View {
    @StateObject private var game = QwixxGame()
    @StateObject private var opponent = QwixxGame(
        scoring: TriangularScoring(cap: 15),
        persistenceKey: "rollnwrite.qwixx.bigpoints.p2.state",
        hasBonusRows: true
    )
    let rules: RulesDocument

    public init(rules: RulesDocument) { self.rules = rules }

    public var body: some View {
        QwixxScorecardView(game: game, opponent: opponent, rules: rules, navigationTitle: "Qwixx Big Points")
    }
}

/// Classic Qwixx: no bonus rows, scoring capped at 12.
public struct QwixxClassicScorecardView: View {
    @StateObject private var game = QwixxGame(
        scoring: TriangularScoring(cap: 12),
        persistenceKey: "rollnwrite.qwixx.classic.state",
        hasBonusRows: false
    )
    @StateObject private var opponent = QwixxGame(
        scoring: TriangularScoring(cap: 12),
        persistenceKey: "rollnwrite.qwixx.classic.p2.state",
        hasBonusRows: false
    )
    let rules: RulesDocument

    public init(rules: RulesDocument) { self.rules = rules }

    public var body: some View {
        QwixxScorecardView(game: game, opponent: opponent, rules: rules, navigationTitle: "Qwixx")
    }
}
