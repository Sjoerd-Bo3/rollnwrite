//
//  XChangeScorecardView.swift
//  RollnWrite – Qwixx X-Change
//
//  The interactive Qwixx "X-Change" scorecard. Rule enforcement and scoring are
//  delegated to `XChangeGame`; this file is presentation + touch handling only.
//
//  View bodies are kept small and extracted, and the game is owned by the
//  `@StateObject` property-default pattern (no closure-injection init), to stay
//  clear of strict-concurrency init isolation issues.
//

import SwiftUI

public struct XChangeScorecardView: View {
    @ObservedObject var game: XChangeGame
    let rules: RulesDocument

    @State private var showRules = false
    @State private var confirmNewGame = false

    private let spacing: CGFloat = 3
    private let columns = 12  // 11 numbers + lock

    public init(game: XChangeGame, rules: RulesDocument) {
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
                    xchangeRow(cell: cell)

                    penaltiesRow
                    scoringLegend
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: contentWidth)
                .frame(maxWidth: .infinity) // center within the available width
            }
        }
        .navigationTitle("Qwixx X-change")
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
                        title: "\(min(game.crosses(for: color), 12))×",
                        value: "\(game.points(for: color))",
                        tint: color.tint
                    )
                }
                ScoreChip(
                    title: "X-Change",
                    value: "\(game.xchange.crossed)",
                    tint: Self.xchangeTint
                )
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

    // MARK: - X-Change row

    private static let xchangeTint = Color(red: 0.55, green: 0.10, blue: 0.42)

    private func xchangeRow(cell: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("X-Change")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Self.xchangeTint)
            HStack(spacing: spacing + 2) {
                ForEach(0..<XChangeRow.count, id: \.self) { i in
                    xchangeCell(i, cell: cell + 6)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func xchangeCell(_ index: Int, cell: CGFloat) -> some View {
        let pair = XChangeRow.pair(index)
        let isMarked = game.xchange.marks.contains(index)
        let isLegal = game.canMarkXChange(index)
        // A skipped field is one that is no longer legal and isn't marked but lies
        // left of an existing cross — render it dimmed/blocked.
        let dimmed = !isMarked && !isLegal
        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Self.xchangeTint, lineWidth: 2)
                )
            VStack(spacing: 0) {
                Text("\(pair.top)")
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                Text("\(pair.bottom)")
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.4)
            .lineLimit(1)
            .foregroundStyle(Self.xchangeTint)
            if isMarked {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Self.xchangeTint)
            }
        }
        .frame(width: cell, height: cell)
        .opacity(dimmed ? 0.3 : 1)
        .contentShape(Rectangle())
        .onTapGesture { if isLegal { game.markXChange(index) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("X-Change \(pair.top) swap \(pair.bottom)")
        .accessibilityValue(isMarked ? "marked" : (isLegal ? "available" : "blocked"))
        .accessibilityAddTraits(isLegal && !isMarked ? .isButton : [])
        .animation(.easeOut(duration: 0.12), value: isMarked)
    }

    // MARK: - Penalties

    private var penaltiesRow: some View {
        HStack {
            Text("Penalties")
                .font(.subheadline.weight(.semibold))
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<XChangeState.maxPenalties, id: \.self) { i in
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
            Text("1·1  2·3  3·6  4·10  5·15  6·21  7·28  8·36  9·45  10·55  11·66  12·78")
                .font(.system(size: 11, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("X-Change diamonds let you swap the white-dice sum (top ↔ bottom) before marking a colour. They score no points themselves.")
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
