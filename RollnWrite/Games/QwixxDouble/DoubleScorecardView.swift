//
//  DoubleScorecardView.swift
//  RollnWrite – Qwixx Double
//
//  The interactive Qwixx "Double" scorecard (Variant A — "double crosses").
//  Rule enforcement and scoring are delegated to `DoubleGame`; this file is
//  presentation + touch handling only.
//
//  Each colour row is drawn as a row of numbered cells with a thin "second
//  cross" strip directly beneath, mirroring the printed sheet where the second
//  cross is drawn below the number. Only the most-recently crossed space's
//  second-cross cell is tappable.
//
//  View bodies are kept small and extracted, and the game is owned by the
//  `@StateObject` property-default pattern (no closure-injection init), to stay
//  clear of strict-concurrency init isolation issues.
//

import SwiftUI

public struct DoubleScorecardView: View {
    @ObservedObject var game: DoubleGame
    let rules: RulesDocument

    @State private var showRules = false
    @State private var confirmNewGame = false

    private let spacing: CGFloat = 3
    private let columns = 12  // 11 numbers + lock

    public init(game: DoubleGame, rules: RulesDocument) {
        _game = ObservedObject(wrappedValue: game)
        self.rules = rules
    }

    public var body: some View {
        GeometryReader { geo in
            // Cap the card width so cells stay a comfortable touch size and the
            // layout stays centered rather than stretching edge-to-edge.
            let contentWidth = min(geo.size.width, 700)
            let cell = max(24, (contentWidth - 24 - spacing * CGFloat(columns - 1)) / CGFloat(columns))
            ScrollView {
                VStack(spacing: 10) {
                    summary

                    VStack(spacing: spacing) {
                        colorRow(.red, cell: cell)
                        colorRow(.yellow, cell: cell)
                        Divider().padding(.vertical, 3)
                        colorRow(.green, cell: cell)
                        colorRow(.blue, cell: cell)
                    }

                    Divider().padding(.vertical, 3)
                    penaltiesRow
                    scoringLegend
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: contentWidth)
                .frame(maxWidth: .infinity) // center within the available width
            }
        }
        .navigationTitle("Qwixx Double")
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
                        title: "\(min(game.crosses(for: color), DoubleGame.scoringCap))×",
                        value: "\(game.points(for: color))",
                        tint: color.tint
                    )
                }
            }
            totalsRow
        }
    }

    private var totalsRow: some View {
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

    // MARK: - Colour rows

    private func colorRow(_ color: GameColor, cell: CGFloat) -> some View {
        let row = game.row(for: color)
        return VStack(spacing: 2) {
            // First-cross row: the 11 numbers + the lock.
            HStack(spacing: spacing) {
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
            // Second-cross strip: a thinner cell under each number. Only the
            // most-recent space is tappable; already-doubled spaces show a mark.
            HStack(spacing: spacing) {
                ForEach(0..<11, id: \.self) { i in
                    secondCrossCell(color, index: i, row: row, cell: cell)
                }
                // Spacer column under the lock keeps the strip aligned.
                Color.clear.frame(width: cell, height: cell * 0.5)
            }
        }
    }

    /// The "draw a second cross below" cell for one column. Marked when the
    /// number was crossed twice; tappable only on the most-recent space.
    private func secondCrossCell(_ color: GameColor, index i: Int, row: DoubleColorRow, cell: CGFloat) -> some View {
        let isDoubled = row.doubles.contains(i)
        let isLegal = game.canDoubleColor(color, i)
        let active = isDoubled || isLegal
        return ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color.tint.opacity(active ? 0.55 : 0.0))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(color.tint.opacity(active ? 0.7 : 0.18),
                                      style: StrokeStyle(lineWidth: 1, dash: isDoubled ? [] : [2, 2]))
                )
            if isDoubled {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(color.textColor == .black ? .black : color.tint)
            } else if isLegal {
                Text("+1×")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(color.tint)
            }
        }
        .frame(width: cell, height: cell * 0.5)
        .opacity(active ? 1 : 0.25)
        .contentShape(Rectangle())
        .onTapGesture { if isLegal { game.doubleColor(color, i) } }
        .accessibilityLabel("\(color.displayName) \(color.numbers[i]) second cross")
        .accessibilityValue(isDoubled ? "marked" : (isLegal ? "available" : "blocked"))
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
                ForEach(0..<DoubleState.maxPenalties, id: \.self) { i in
                    penaltyBox(i)
                }
            }
        }
    }

    private func penaltyBox(_ i: Int) -> some View {
        let filled = i < game.penalties
        let isNext = i == game.penalties && game.canAddPenalty()
        return ZStack {
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

    // MARK: - Scoring legend

    private var scoringLegend: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Points per crosses")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("1·1  2·3  3·6  4·10  5·15  6·21  7·28  8·36  9·45  10·55  11·66  12·78  13·91  14·105  15·120  16·136")
                .font(.system(size: 11, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Tap the strip below your most-recent cross to draw a second cross there. A row scores up to 16 crosses (136 points). The lock number needs 7 crosses first.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}

// MARK: - Variant owner
//
// Owns its own `DoubleGame` via the `@StateObject` property-default pattern and
// renders the scorecard.

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
