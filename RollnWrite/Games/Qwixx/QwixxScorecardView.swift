//
//  QwixxScorecardView.swift
//  RollnWrite – Qwixx
//
//  The interactive Qwixx Big Points scorecard. Rule enforcement and scoring are
//  delegated to `QwixxGame`; this file is presentation + touch handling only.
//

import SwiftUI

public struct QwixxScorecardView: View {
    @StateObject private var game: QwixxGame
    let rules: RulesDocument
    let navigationTitle: String

    @State private var showRules = false
    @State private var confirmNewGame = false

    private let spacing: CGFloat = 3
    private let columns = 12  // 11 numbers + lock

    public init(
        rules: RulesDocument,
        navigationTitle: String = "Qwixx Big Points",
        makeGame: @escaping () -> QwixxGame = { QwixxGame() }
    ) {
        self.rules = rules
        self.navigationTitle = navigationTitle
        _game = StateObject(wrappedValue: makeGame())
    }

    public var body: some View {
        GeometryReader { geo in
            // Cap the card width on iPad / large or landscape screens so cells stay
            // a comfortable touch size and the layout stays centered rather than
            // stretching edge-to-edge.
            let contentWidth = min(geo.size.width, 700)
            let cell = max(24, (contentWidth - 24 - spacing * CGFloat(columns - 1)) / CGFloat(columns))
            ScrollView {
                VStack(spacing: 10) {
                    summary

                    VStack(spacing: spacing) {
                        colorRow(.red, cell: cell)
                        if game.hasBonusRows { bonusRow(.redYellow, cell: cell) }
                        colorRow(.yellow, cell: cell)

                        Divider().padding(.vertical, 3)

                        colorRow(.green, cell: cell)
                        if game.hasBonusRows { bonusRow(.greenBlue, cell: cell) }
                        colorRow(.blue, cell: cell)
                    }

                    penaltiesRow
                    scoringLegend
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: contentWidth)
                .frame(maxWidth: .infinity) // center within the available width
            }
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

    // MARK: - Summary

    private var summary: some View {
        VStack(spacing: 8) {
            if game.isGameOver {
                Label("Game over — final score \(game.totalScore)", systemImage: "flag.checkered")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
            HStack(spacing: 6) {
                ForEach(GameColor.allCases) { color in
                    ScoreChip(
                        title: "\(min(game.crosses(for: color), 15))×",
                        value: "\(game.points(for: color))",
                        tint: color.tint
                    )
                }
            }
            HStack {
                if game.penalties > 0 {
                    Text("Penalties −\(game.penaltyPoints)")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
                Spacer()
                Text("Total")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(game.totalScore)")
                    .font(.title3.bold().monospacedDigit())
            }
        }
    }

    // MARK: - Rows

    private func colorRow(_ color: GameColor, cell: CGFloat) -> some View {
        let row = game.row(for: color)
        return HStack(spacing: spacing) {
            ForEach(0..<11, id: \.self) { i in
                MarkableCell(
                    label: "\(color.numbers[i])",
                    tint: color.tint,
                    textColor: color.textColor,
                    isMarked: row.marks.contains(i),
                    isLegal: game.canMarkColor(color, i),
                    isInteractive: true,
                    shape: .square
                ) { game.markColor(color, i) }
                .frame(width: cell, height: cell)
            }
            lockCell(color: color, locked: row.locked)
                .frame(width: cell, height: cell)
        }
    }

    private func bonusRow(_ id: BonusRowID, cell: CGFloat) -> some View {
        let bonus = game.bonus(id)
        let (a, b) = id.colors
        return HStack(spacing: spacing) {
            ForEach(0..<11, id: \.self) { i in
                BonusCell(
                    label: "\(bonus.numbers[i])",
                    colorA: a,
                    colorB: b,
                    isMarked: bonus.marks.contains(i),
                    isLegal: game.canMarkBonus(id, i)
                ) { game.markBonus(id, i) }
                .frame(width: cell, height: cell)
            }
            Color.clear.frame(width: cell, height: cell) // align with the lock column
        }
    }

    private func lockCell(color: GameColor, locked: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.tint)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(.black.opacity(0.18), lineWidth: 1)
                )
            Image(systemName: locked ? "lock.fill" : "lock.open")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color.textColor)
        }
        .opacity(locked ? 1 : 0.45)
        .accessibilityLabel("\(color.displayName) lock")
        .accessibilityValue(locked ? "locked" : "open")
    }

    // MARK: - Penalties

    private var penaltiesRow: some View {
        HStack {
            Text("Penalties")
                .font(.subheadline.weight(.semibold))
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<QwixxState.maxPenalties, id: \.self) { i in
                    let filled = i < game.penalties
                    let isNext = i == game.penalties && game.canAddPenalty()
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(.red, lineWidth: 2)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(filled ? Color.red.opacity(0.85) : .clear)
                            )
                        if filled {
                            Image(systemName: "xmark").font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                        } else {
                            Text("−5").font(.caption2.bold()).foregroundStyle(.red)
                        }
                    }
                    .frame(width: 34, height: 34)
                    .opacity(filled || isNext ? 1 : 0.4)
                    .onTapGesture { if isNext { game.addPenalty() } }
                    .accessibilityLabel("Penalty \(i + 1)")
                    .accessibilityValue(filled ? "taken" : "empty")
                }
            }
        }
    }

    // MARK: - Scoring legend

    private var scoringLegend: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Points per crosses")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("1·1  2·3  3·6  4·10  5·15  6·21  7·28  8·36  9·45  10·55  11·66  12·78  13·91  14·105  15·120")
                .font(.system(size: 11, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
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
