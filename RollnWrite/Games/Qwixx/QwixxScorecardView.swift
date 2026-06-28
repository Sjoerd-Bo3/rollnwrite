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
            boardStack(w: s.w, h: s.h)
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

    // MARK: - Sizing (fill the screen in any orientation)

    private struct BoardLayout { let w: CGFloat; let h: CGFloat }

    /// Tiles fill the FULL width edge-to-edge (`w`); their height (`h`) shrinks
    /// so every row fits the screen. Tiles go slightly rectangular when a board
    /// has many rows, but the board is always fullscreen — no margins, no
    /// scrolling — in any orientation.
    private func sizing(for size: CGSize) -> BoardLayout {
        let bandRows = CGFloat(game.hasBonusRows ? 6 : 4)
        let bonusRows = CGFloat(game.hasBonusRows ? 2 : 0)
        let rowsCount = bandRows + bonusRows + 1 // + bottom bar

        let availW = size.width - 2 * outerPad
        let w = max(14, (availW - (columns - 1) * tileGap - 2 * bandPad) / columns)

        // Row heights: colour band = h, bonus row ≈ 0.6h, bottom bar ≈ 0.95h.
        let availH = size.height - 2 * outerPad
        let vUnits = bandRows + 0.6 * bonusRows + 0.95
        let h = max(14, (availH - (rowsCount - 1) * rowGap) / vUnits)
        return BoardLayout(w: w, h: h)
    }

    // MARK: - Board

    private func boardStack(w: CGFloat, h: CGFloat) -> some View {
        let bonusH = h * 0.6
        let bottomH = h * 0.95
        return VStack(spacing: rowGap) {
            band(.red, w: w, h: h)
            if game.hasBonusRows { bonusBand(.redYellow, w: w, h: bonusH) }
            band(.yellow, w: w, h: h)
            band(.green, w: w, h: h)
            if game.hasBonusRows { bonusBand(.greenBlue, w: w, h: bonusH) }
            band(.blue, w: w, h: h)
            bottomBar(w: w, h: bottomH)
        }
    }

    /// One full-width colour band: a direction chevron, the eleven number tiles,
    /// the lock, and that colour's running score — styled like the real card.
    private func band(_ color: GameColor, w: CGFloat, h: CGFloat) -> some View {
        let th = h * 0.84
        let s = min(w, th)
        return HStack(spacing: tileGap) {
            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: s * 0.5, weight: .black))
                .foregroundStyle(.black.opacity(0.5))
                .frame(width: w, height: th)
            ForEach(0..<11, id: \.self) { i in numberTile(color, i, w: w, h: th) }
            lockTile(color, w: w, h: th)
            scoreTile(value: game.points(for: color), w: w, h: th)
        }
        .padding(.horizontal, bandPad)
        .padding(.vertical, h * 0.08)
        .frame(maxWidth: .infinity)
        .background(color.tint)
        .clipShape(RoundedRectangle(cornerRadius: s * 0.3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: s * 0.3, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
    }

    private func numberTile(_ color: GameColor, _ i: Int, w: CGFloat, h: CGFloat) -> some View {
        let marked = game.row(for: color).marks.contains(i)
        let legal = game.canMarkColor(color, i)
        let s = min(w, h)
        return Button {
            game.markColor(color, i)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                    .fill(Color.white.opacity(marked ? 0.7 : 0.95))
                Text("\(color.numbers[i])")
                    .font(.system(size: s * 0.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(color.tint)
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                if marked {
                    Image(systemName: "xmark")
                        .font(.system(size: s * 0.72, weight: .black))
                        .foregroundStyle(color.tint)
                }
            }
            .frame(width: w, height: h)
        }
        .buttonStyle(.plain)
        .disabled(marked || !legal)
        .opacity(marked || legal ? 1 : 0.4)
        .accessibilityLabel("\(color.displayName) \(color.numbers[i])")
        .accessibilityValue(marked ? "crossed" : (legal ? "available" : "blocked"))
    }

    private func lockTile(_ color: GameColor, w: CGFloat, h: CGFloat) -> some View {
        let locked = game.row(for: color).locked
        let s = min(w, h)
        return ZStack {
            RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                .fill(Color.white.opacity(locked ? 0.95 : 0.42))
            Image(systemName: locked ? "lock.fill" : "lock.open")
                .font(.system(size: s * 0.5, weight: .bold))
                .foregroundStyle(color.tint)
        }
        .frame(width: w, height: h)
        .accessibilityLabel("\(color.displayName) lock")
        .accessibilityValue(locked ? "locked" : "open")
    }

    private func scoreTile(value: Int, w: CGFloat, h: CGFloat) -> some View {
        let s = min(w, h)
        return ZStack {
            RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                .fill(Color.black.opacity(0.2))
            Text("\(value)")
                .font(.system(size: s * 0.46, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .minimumScaleFactor(0.3)
                .lineLimit(1)
        }
        .frame(width: w, height: h)
    }

    /// Big-Points bonus row: the two-colour spaces, aligned under the number
    /// tiles (offset past the chevron column).
    private func bonusBand(_ id: BonusRowID, w: CGFloat, h: CGFloat) -> some View {
        let bonus = game.bonus(id)
        let (a, b) = id.colors
        return HStack(spacing: tileGap) {
            Color.clear.frame(width: w, height: h) // chevron column
            ForEach(0..<11, id: \.self) { i in
                BonusCell(
                    label: "\(bonus.numbers[i])",
                    colorA: a, colorB: b,
                    isMarked: bonus.marks.contains(i),
                    isLegal: game.canMarkBonus(id, i)
                ) { game.markBonus(id, i) }
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
            boardButton("arrow.uturn.backward", size: b) { game.undo() }
                .disabled(!game.canUndo)
                .opacity(game.canUndo ? 1 : 0.4)
            boardButton("trash", size: b) { confirmReset = true }
            Spacer(minLength: w * 0.1)
            ForEach(0..<QwixxState.maxPenalties, id: \.self) { i in
                penaltyBox(i, size: b)
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

    private func penaltyBox(_ i: Int, size h: CGFloat) -> some View {
        let filled = i < game.penalties
        let isNext = i == game.penalties && game.canAddPenalty()
        return ZStack {
            RoundedRectangle(cornerRadius: h * 0.2, style: .continuous)
                .fill(filled ? Color.red.opacity(0.85) : Color.gray.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: h * 0.2, style: .continuous)
                        .strokeBorder(.red.opacity(0.7), lineWidth: 1.5)
                )
            if filled {
                Image(systemName: "xmark").font(.system(size: h * 0.5, weight: .black)).foregroundStyle(.white)
            } else {
                Text("−5").font(.system(size: h * 0.32, weight: .bold)).foregroundStyle(.red)
            }
        }
        .frame(width: h, height: h)
        .opacity(filled || isNext ? 1 : 0.5)
        .onTapGesture { if isNext { game.addPenalty() } }
        .accessibilityLabel("Penalty \(i + 1)")
    }

    private func boardButton(_ icon: String, size h: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: h * 0.2, style: .continuous)
                    .fill(Color.gray.opacity(0.25))
                Image(systemName: icon)
                    .font(.system(size: h * 0.42, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .frame(width: h, height: h)
        }
        .buttonStyle(.plain)
    }
}

/// Hosts one Qwixx board with navigation. When an `opponent` is supplied and
/// there's room (iPad / regular width), a "2 players" toggle shows the
/// opponent's board mirrored above — for two people sitting across a table.
public struct QwixxScorecardView: View {
    @ObservedObject var game: QwixxGame
    private let opponent: QwixxGame?
    let rules: RulesDocument
    let navigationTitle: String

    @Environment(\.horizontalSizeClass) private var hSize
    @State private var showRules = false
    @State private var twoPlayer = false

    public init(game: QwixxGame, opponent: QwixxGame? = nil, rules: RulesDocument, navigationTitle: String) {
        _game = ObservedObject(wrappedValue: game)
        self.opponent = opponent
        self.rules = rules
        self.navigationTitle = navigationTitle
    }

    private var canMirror: Bool { opponent != nil && hSize == .regular }

    public var body: some View {
        Group {
            if canMirror, twoPlayer, let opponent {
                VStack(spacing: 8) {
                    QwixxBoardView(game: opponent)
                        .rotationEffect(.degrees(180))
                    Divider()
                    QwixxBoardView(game: game)
                }
                .padding(.vertical, 4)
            } else {
                QwixxBoardView(game: game)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if canMirror {
                    Button { twoPlayer.toggle() } label: {
                        Image(systemName: twoPlayer ? "person.fill" : "person.2.fill")
                    }
                    .accessibilityLabel(twoPlayer ? "Single player" : "Two players")
                }
                Button { showRules = true } label: { Image(systemName: "info.circle") }
            }
        }
        .sheet(isPresented: $showRules) { RulesView(document: rules) }
    }
}

/// A two-colour bonus space (diagonal split fill).
private struct BonusCell: View {
    let label: String
    let colorA: GameColor
    let colorB: GameColor
    let isMarked: Bool
    let isLegal: Bool
    var onTap: () -> Void

    private var dimmed: Bool { !isMarked && !isLegal }

    var body: some View {
        ZStack {
            Circle()
                .fill(colorA.tint)
                .overlay(
                    Circle().fill(colorB.tint)
                        .mask(
                            GeometryReader { g in
                                Path { p in
                                    p.move(to: CGPoint(x: g.size.width, y: 0))
                                    p.addLine(to: CGPoint(x: g.size.width, y: g.size.height))
                                    p.addLine(to: CGPoint(x: 0, y: g.size.height))
                                    p.closeSubpath()
                                }
                            }
                        )
                )
                .overlay(Circle().strokeBorder(.black.opacity(0.18), lineWidth: 1))
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .foregroundStyle(.white)
                .shadow(radius: 0.5)
            if isMarked {
                Image(systemName: "xmark").font(.system(size: 18, weight: .black)).foregroundStyle(.white)
            }
        }
        .opacity(dimmed ? 0.3 : 1)
        .contentShape(Circle())
        .onTapGesture { if isLegal && !isMarked { onTap() } }
        .accessibilityLabel("Bonus \(label)")
        .accessibilityValue(isMarked ? "marked" : (isLegal ? "available" : "blocked"))
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
