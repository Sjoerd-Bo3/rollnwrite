//
//  QwixxScorecardView.swift
//  RollnWrite – Qwixx
//
//  The interactive Qwixx Big Points scorecard. Rule enforcement and scoring are
//  delegated to `QwixxGame`; this file is presentation + touch handling only.
//

import SwiftUI

public struct QwixxScorecardView: View {
    @ObservedObject var game: QwixxGame
    let rules: RulesDocument
    let navigationTitle: String

    @State private var showRules = false
    @State private var confirmNewGame = false

    private let tileGap: CGFloat = 4
    private let rowGap: CGFloat = 6
    // chevron + 11 numbers + lock + per-row score
    private let columns: CGFloat = 14

    public init(game: QwixxGame, rules: RulesDocument, navigationTitle: String) {
        _game = ObservedObject(wrappedValue: game)
        self.rules = rules
        self.navigationTitle = navigationTitle
    }

    public var body: some View {
        GeometryReader { geo in
            let s = sizing(for: geo.size)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                boardStack(cell: s.cell)
                    .frame(width: s.boardWidth)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 8)
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { game.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(!game.canUndo)
                Button { showRules = true } label: { Image(systemName: "info.circle") }
                Button(role: .destructive) { confirmNewGame = true } label: { Image(systemName: "trash") }
            }
        }
        .sheet(isPresented: $showRules) { RulesView(document: rules) }
        .confirmationDialog("Start a new game?", isPresented: $confirmNewGame, titleVisibility: .visible) {
            Button("New game", role: .destructive) { game.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears the current scorecard.")
        }
    }

    // MARK: - Sizing (fill the screen in any orientation)

    private struct BoardLayout { let cell: CGFloat; let boardWidth: CGFloat; let rowGap: CGFloat }

    /// Sizes a cell so the whole banded board fits BOTH the available width and
    /// height — no scrolling, no cut-off, in portrait or landscape.
    private func sizing(for size: CGSize) -> BoardLayout {
        let bandRows = game.hasBonusRows ? 6 : 4
        let bonusRows = game.hasBonusRows ? 2 : 0

        // Width: band content = columns*cell + inner padding (cell*0.32) + gaps.
        let usableW = min(size.width, 1024) - 16
        let cellByWidth = (usableW - (columns - 1) * tileGap) / (columns + 0.32)

        // Height: band ≈ cell*1.28, bonus ≈ cell*0.7, bottom bar ≈ cell*1.1.
        let rowsCount = CGFloat(bandRows + bonusRows + 1)
        let units = CGFloat(bandRows) * 1.28 + CGFloat(bonusRows) * 0.7 + 1.1
        let usableH = size.height - 16 - (rowsCount - 1) * rowGap
        let cellByHeight = usableH / units

        let cell = max(16, min(cellByWidth, cellByHeight))
        let boardWidth = cell * (columns + 0.32) + (columns - 1) * tileGap
        return BoardLayout(cell: cell, boardWidth: boardWidth, rowGap: rowGap)
    }

    // MARK: - Board

    private func boardStack(cell: CGFloat) -> some View {
        VStack(spacing: rowGap) {
            band(.red, cell: cell)
            if game.hasBonusRows { bonusBand(.redYellow, cell: cell) }
            band(.yellow, cell: cell)
            band(.green, cell: cell)
            if game.hasBonusRows { bonusBand(.greenBlue, cell: cell) }
            band(.blue, cell: cell)
            bottomBar(cell: cell)
        }
    }

    /// One full-width colour band: a direction chevron, the eleven number tiles,
    /// the lock, and that colour's running score — styled like the real card.
    private func band(_ color: GameColor, cell: CGFloat) -> some View {
        HStack(spacing: tileGap) {
            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: cell * 0.46, weight: .black))
                .foregroundStyle(.black.opacity(0.5))
                .frame(width: cell, height: cell)
            ForEach(0..<11, id: \.self) { i in numberTile(color, i, cell: cell) }
            lockTile(color, cell: cell)
            scoreTile(value: game.points(for: color), cell: cell)
        }
        .padding(.horizontal, cell * 0.16)
        .padding(.vertical, cell * 0.14)
        .background(color.tint)
        .clipShape(RoundedRectangle(cornerRadius: cell * 0.24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cell * 0.24, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
    }

    private func numberTile(_ color: GameColor, _ i: Int, cell: CGFloat) -> some View {
        let marked = game.row(for: color).marks.contains(i)
        let legal = game.canMarkColor(color, i)
        return Button {
            game.markColor(color, i)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: cell * 0.16, style: .continuous)
                    .fill(Color.white.opacity(marked ? 0.7 : 0.95))
                Text("\(color.numbers[i])")
                    .font(.system(size: cell * 0.42, weight: .heavy, design: .rounded))
                    .foregroundStyle(color.tint)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                if marked {
                    Image(systemName: "xmark")
                        .font(.system(size: cell * 0.66, weight: .black))
                        .foregroundStyle(color.tint)
                }
            }
            .frame(width: cell, height: cell)
        }
        .buttonStyle(.plain)
        .disabled(marked || !legal)
        .opacity(marked || legal ? 1 : 0.4)
        .accessibilityLabel("\(color.displayName) \(color.numbers[i])")
        .accessibilityValue(marked ? "crossed" : (legal ? "available" : "blocked"))
    }

    private func lockTile(_ color: GameColor, cell: CGFloat) -> some View {
        let locked = game.row(for: color).locked
        return ZStack {
            RoundedRectangle(cornerRadius: cell * 0.16, style: .continuous)
                .fill(Color.white.opacity(locked ? 0.95 : 0.42))
            Image(systemName: locked ? "lock.fill" : "lock.open")
                .font(.system(size: cell * 0.42, weight: .bold))
                .foregroundStyle(color.tint)
        }
        .frame(width: cell, height: cell)
        .accessibilityLabel("\(color.displayName) lock")
        .accessibilityValue(locked ? "locked" : "open")
    }

    private func scoreTile(value: Int, cell: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cell * 0.16, style: .continuous)
                .fill(Color.black.opacity(0.2))
            Text("\(value)")
                .font(.system(size: cell * 0.4, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .minimumScaleFactor(0.35)
                .lineLimit(1)
        }
        .frame(width: cell, height: cell)
    }

    /// Big-Points bonus row: the two-colour spaces, aligned under the number
    /// tiles (offset past the chevron column).
    private func bonusBand(_ id: BonusRowID, cell: CGFloat) -> some View {
        let bonus = game.bonus(id)
        let (a, b) = id.colors
        let h = cell * 0.7
        return HStack(spacing: tileGap) {
            Color.clear.frame(width: cell, height: h) // chevron column
            ForEach(0..<11, id: \.self) { i in
                BonusCell(
                    label: "\(bonus.numbers[i])",
                    colorA: a, colorB: b,
                    isMarked: bonus.marks.contains(i),
                    isLegal: game.canMarkBonus(id, i)
                ) { game.markBonus(id, i) }
                .frame(width: cell, height: h)
            }
            Color.clear.frame(width: cell * 2 + tileGap, height: h) // lock + score columns
        }
        .padding(.horizontal, cell * 0.16)
    }

    /// Penalties on the left, running total on the right.
    private func bottomBar(cell: CGFloat) -> some View {
        let h = cell * 0.82
        return HStack(spacing: tileGap) {
            ForEach(0..<QwixxState.maxPenalties, id: \.self) { i in
                let filled = i < game.penalties
                let isNext = i == game.penalties && game.canAddPenalty()
                ZStack {
                    RoundedRectangle(cornerRadius: cell * 0.16, style: .continuous)
                        .fill(filled ? Color.red.opacity(0.85) : Color.gray.opacity(0.28))
                        .overlay(
                            RoundedRectangle(cornerRadius: cell * 0.16, style: .continuous)
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
            Spacer(minLength: cell * 0.2)
            if game.isGameOver {
                Image(systemName: "flag.checkered").foregroundStyle(.secondary)
            }
            Text("Total")
                .font(.system(size: h * 0.34, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("\(game.totalScore)")
                .font(.system(size: h * 0.5, weight: .heavy, design: .rounded).monospacedDigit())
                .frame(minWidth: cell * 1.4, alignment: .trailing)
        }
        .frame(height: h)
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
    let rules: RulesDocument

    public init(rules: RulesDocument) { self.rules = rules }

    public var body: some View {
        QwixxScorecardView(game: game, rules: rules, navigationTitle: "Qwixx Big Points")
    }
}

/// Classic Qwixx: no bonus rows, scoring capped at 12.
public struct QwixxClassicScorecardView: View {
    @StateObject private var game = QwixxGame(
        scoring: TriangularScoring(cap: 12),
        persistenceKey: "rollnwrite.qwixx.classic.state",
        hasBonusRows: false
    )
    let rules: RulesDocument

    public init(rules: RulesDocument) { self.rules = rules }

    public var body: some View {
        QwixxScorecardView(game: game, rules: rules, navigationTitle: "Qwixx")
    }
}
