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
    @State private var confirmReset = false
    @State private var showResults = false

    private let tileGap: CGFloat = 4
    private let rowGap: CGFloat = 4
    private let outerPad: CGFloat = 4   // gap to the safe-area edge
    private let bandPad: CGFloat = 4    // coloured border inside each band
    // chevron + 11 numbers + lock + per-row score
    private let columns: CGFloat = 14

    init(game: QwixxGame) {
        _game = ObservedObject(wrappedValue: game)
    }

    var body: some View {
        GeometryReader { geo in
            let s = sizing(for: geo.size)
            boardStack(w: s.w, th: s.th)
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
        .overlay {
            if showResults {
                GameOverCard(
                    lines: GameColor.allCases.map {
                        GameOverCard.Line(label: $0.displayName, value: game.points(for: $0), tint: $0.tint)
                    } + (game.penaltyPoints > 0
                         ? [GameOverCard.Line(label: "Penalties", value: -game.penaltyPoints, tint: .red)]
                         : []),
                    total: game.totalScore,
                    onNewGame: { game.reset(); showResults = false },
                    onDismiss: { withAnimation { showResults = false } }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .onChange(of: game.isGameOver) { _, isOver in
            if isOver {
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

        // Each row's height as a multiple of the tile height `th`: a colour band
        // is the tile plus its vertical band padding (≈1.18·th), a bonus row
        // ≈0.82·th, the bottom bar ≈1.05·th. Solve for the `th` that fills the
        // available height exactly, then cap at the width and floor at the min.
        let units = bandCount * 1.18 + bonusRows * 0.82 + 1.05
        let availH = size.height - 2 * outerPad
        let fill = (availH - gaps * rowGap) / units
        let th = max(20, min(fill, w))
        return BoardLayout(w: w, th: th)
    }

    // MARK: - Board

    private func boardStack(w: CGFloat, th: CGFloat) -> some View {
        let bonusH = th * 0.82
        let bottomH = th * 1.05
        return VStack(spacing: rowGap) {
            band(.red, w: w, tile: th)
            if game.hasBonusRows { bonusBand(.redYellow, w: w, h: bonusH) }
            band(.yellow, w: w, tile: th)
            band(.green, w: w, tile: th)
            if game.hasBonusRows { bonusBand(.greenBlue, w: w, h: bonusH) }
            band(.blue, w: w, tile: th)
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

    /// Big-Points bonus row: the two-colour spaces, aligned under the number
    /// tiles (offset past the chevron column).
    private func bonusBand(_ id: BonusRowID, w: CGFloat, h: CGFloat) -> some View {
        let bonus = game.bonus(id)
        let (a, b) = id.colors
        return HStack(spacing: tileGap) {
            Color.clear.frame(width: w, height: h) // chevron column
            ForEach(0..<11, id: \.self) { i in
                let undoable = bonus.marks.contains(i) && game.isLastBonusMark(id, i)
                BonusTile("\(bonus.numbers[i])", tintA: a.tint, tintB: b.tint,
                          marked: bonus.marks.contains(i), legal: game.canMarkBonus(id, i),
                          undoable: undoable) {
                    if undoable { game.undo() } else { game.markBonus(id, i) }
                }
                .frame(width: w, height: h)
            }
            Color.clear.frame(width: w * 2 + tileGap, height: h) // lock + score columns
        }
        .padding(.horizontal, bandPad)
        .frame(maxWidth: .infinity)
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
            }
            Text("Total")
                .font(.system(size: b * 0.34, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("\(game.totalScore)")
                .font(.system(size: b * 0.55, weight: .heavy, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
                .animation(.snappy, value: game.totalScore)
        }
        .frame(maxWidth: .infinity)
        .frame(height: h)
        .padding(.horizontal, bandPad)
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
            board: { QwixxBoardView(game: game) },
            opponent: opponent.map { opp in { QwixxBoardView(game: opp) } }
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
