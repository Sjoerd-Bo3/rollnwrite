//
//  MixxScorecardView.swift
//  RollnWrite – Qwixx Mixx
//
//  The interactive Qwixx "gemixxt" (Mixx) scorecard. Rule enforcement and
//  scoring are delegated to `MixxGame`; this file is presentation + touch
//  handling only.
//
//  A segmented control at the top switches between Variant A and Variant B; the
//  two boards keep independent state. Every number cell is tinted with its own
//  segment colour (Variant A) or the row colour (Variant B); the lock cell uses
//  the row's lock colour — the die removed from play when that row is closed.
//
//  View bodies are kept small and extracted, and the game is owned by the
//  `@StateObject` property-default pattern (no closure-injection init), to stay
//  clear of strict-concurrency init isolation issues.
//

import SwiftUI

public struct MixxScorecardView: View {
    @ObservedObject var game: MixxGame
    let rules: RulesDocument

    @State private var showRules = false
    @State private var confirmNewGame = false

    private let spacing: CGFloat = 3
    private let columns = 12  // 11 numbers + lock

    public init(game: MixxGame, rules: RulesDocument) {
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
                    boardPicker
                    summary

                    VStack(spacing: spacing) {
                        ForEach(0..<4, id: \.self) { rowIndex in
                            mixxRow(rowIndex, cell: cell)
                        }
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
        .navigationTitle("Qwixx Mixx")
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
            Text("This clears the \(game.board.displayName) scorecard.")
        }
    }

    // MARK: - Board picker

    private var boardPicker: some View {
        Picker("Board", selection: $game.board) {
            ForEach(MixxBoard.allCases) { b in
                Text(b.displayName).tag(b)
            }
        }
        .pickerStyle(.segmented)
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
                ForEach(0..<4, id: \.self) { rowIndex in
                    ScoreChip(
                        title: "\(min(game.crosses(rowIndex), 12))×",
                        value: "\(game.points(rowIndex))",
                        tint: game.rowLayout(rowIndex).lockColor.tint
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

    // MARK: - Rows

    private func mixxRow(_ rowIndex: Int, cell: CGFloat) -> some View {
        let layout = game.rowLayout(rowIndex)
        let row = game.rowState(rowIndex)
        return HStack(spacing: spacing) {
            ForEach(0..<11, id: \.self) { i in
                let c = layout.cells[i]
                MarkableCell(
                    label: "\(c.number)",
                    tint: c.color.tint,
                    textColor: c.color.textColor,
                    isMarked: row.marks.contains(i),
                    isLegal: game.canMark(rowIndex, i),
                    isInteractive: true,
                    shape: .square
                ) { game.mark(rowIndex, i) }
                .frame(width: cell, height: cell)
            }
            lockCell(color: layout.lockColor, locked: row.locked)
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

    // MARK: - Penalties

    private var penaltiesRow: some View {
        HStack {
            Text("Penalties")
                .font(.subheadline.weight(.semibold))
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<MixxState.maxPenalties, id: \.self) { i in
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
            Text(boardHint)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var boardHint: String {
        switch game.board {
        case .variantA:
            return "Variant A: numbers run 2→12 / 12→2 as usual, but each cell belongs to a die colour — cross it with that colour. Closing a row removes its lock-colour die from play."
        case .variantB:
            return "Variant B: one row per colour, numbers scrambled — still crossed left → right. Closing a row removes that colour's die from play."
        }
    }
}

// MARK: - Variant owner
//
// Owns its own `MixxGame` via the `@StateObject` property-default pattern and
// renders the scorecard (with its A/B board toggle).

/// Qwixx Mixx ("gemixxt"): both official boards, classic scoring (cap 12).
public struct QwixxMixxScorecardView: View {
    @StateObject private var game = MixxGame()
    let rules: RulesDocument

    public init(rules: RulesDocument) { self.rules = rules }

    public var body: some View {
        MixxScorecardView(game: game, rules: rules)
    }
}
