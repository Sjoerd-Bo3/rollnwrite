//
//  MixxScorecardView.swift
//  RollnWrite – Qwixx Mixx
//
//  The interactive Qwixx "gemixxt" (Mixx) scorecard. Rule enforcement and
//  scoring are delegated to `MixxGame`; this file is presentation + touch
//  handling only.
//
//  Built on the reusable scorecard framework: a pure `MixxBoardView` renders the
//  board fullscreen edge-to-edge via `BoardMetrics` + the Core board components,
//  and a thin `QwixxMixxScorecardView` wrapper adds the shared chrome
//  (`ScorecardScaffold`: compact header, landscape lock, rules sheet) — mirroring
//  `QwixxBoardView` / `QwixxScorecardView`.
//
//  Mixx rows are SCRAMBLED: each cell carries its own die colour (Variant A
//  segments) or the row colour (Variant B), and the order is non-standard. Every
//  `NumberTile` is therefore tinted per-cell; the band background and lock use
//  the row's lock colour. An A / B segmented control above the bands switches the
//  two independent boards.
//

import SwiftUI

/// The pure banded Mixx board for the currently selected variant — no navigation
/// chrome, so the scaffold can host it fullscreen. The A / B picker and the
/// per-board controls (undo, new game) live in the board itself, like the
/// printed card's toggle and corner buttons.
struct MixxBoardView: View {
    @ObservedObject var game: MixxGame
    @State private var confirmReset = false

    private let tileGap: CGFloat = 4
    private let rowGap: CGFloat = 4
    private let outerPad: CGFloat = 4   // gap to the safe-area edge
    private let bandPad: CGFloat = 4    // coloured border inside each band
    // chevron + 11 numbers + lock + per-row score
    private let columns: CGFloat = 14
    // 4 colour bands + bottom bar; the picker sits in a fixed-height strip above.
    private let pickerHeight: CGFloat = 36

    init(game: MixxGame) {
        _game = ObservedObject(wrappedValue: game)
    }

    var body: some View {
        VStack(spacing: rowGap) {
            boardPicker
            GeometryReader { geo in
                let t = BoardMetrics.tile(
                    in: geo.size,
                    columns: columns,
                    rowUnits: 4 + 0.95,   // 4 colour bands + bottom bar (≈0.95)
                    rowCount: 5,
                    gap: rowGap,
                    pad: outerPad
                )
                boardStack(w: t.w, h: t.h)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(outerPad)
            }
        }
        .padding(.top, 4)
        .ignoresSafeArea(.container, edges: .bottom)
        .confirmationDialog("Start a new game?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("New game", role: .destructive) { game.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears the \(game.board.displayName) scorecard.")
        }
    }

    // MARK: - Board picker (switches the two independent A / B boards)

    private var boardPicker: some View {
        Picker("Board", selection: $game.board) {
            ForEach(MixxBoard.allCases) { b in
                Text(b.displayName).tag(b)
            }
        }
        .pickerStyle(.segmented)
        .frame(height: pickerHeight)
        .padding(.horizontal, 16)
    }

    // MARK: - Board

    private func boardStack(w: CGFloat, h: CGFloat) -> some View {
        let bottomH = h * 1.05
        return VStack(spacing: rowGap) {
            ForEach(0..<4, id: \.self) { rowIndex in
                band(rowIndex, w: w, tile: h)
            }
            bottomBar(w: w, h: bottomH)
        }
    }

    /// One full-width Mixx row: a direction chevron, the eleven per-cell-tinted
    /// number tiles, the lock (row's lock colour) and the running score. The band
    /// background uses the row's lock colour; each `NumberTile` keeps its own
    /// cell colour so the scrambled segment colours are preserved exactly.
    private func band(_ rowIndex: Int, w: CGFloat, tile th: CGFloat) -> some View {
        let layout = game.rowLayout(rowIndex)
        let row = game.rowState(rowIndex)
        let lock = layout.lockColor
        return HStack(spacing: tileGap) {
            BandChevron(w: w, h: th)
            ForEach(0..<11, id: \.self) { i in
                let cell = layout.cells[i]
                let marked = row.marks.contains(i)
                let undoable = marked && game.isLastMark(rowIndex, i)
                NumberTile("\(cell.number)", tint: cell.color.tint,
                           marked: marked, legal: game.canMark(rowIndex, i),
                           undoable: undoable, w: w, h: th) {
                    if undoable { game.undo() } else { game.mark(rowIndex, i) }
                }
                .accessibilityLabel("\(lock.displayName) row \(cell.color.displayName) \(cell.number)")
            }
            LockTile(tint: lock.tint, locked: row.locked, w: w, h: th)
                .accessibilityLabel("\(lock.displayName) lock")
            ScoreTile(game.points(rowIndex), w: w, h: th)
        }
        .colourBand(tint: lock.tint, hPad: bandPad, vPad: th * 0.09, corner: min(w, th) * 0.3)
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
            ForEach(0..<MixxState.maxPenalties, id: \.self) { i in
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
        }
        .frame(maxWidth: .infinity)
        .frame(height: h)
        .padding(.horizontal, bandPad)
    }
}

// MARK: - Variant owner
//
// Owns its own `MixxGame` via the `@StateObject` property-default pattern (no
// closure-injection init), and renders the pure board inside the shared
// `ScorecardScaffold` (header, landscape lock, rules sheet). The A / B board
// toggle lives inside `MixxBoardView`.

/// Qwixx Mixx ("gemixxt"): both official boards, classic scoring (cap 12).
public struct QwixxMixxScorecardView: View {
    @StateObject private var game = MixxGame()
    let rules: RulesDocument

    public init(rules: RulesDocument) { self.rules = rules }

    public var body: some View {
        ScorecardScaffold(
            title: "Qwixx Mixx",
            rules: rules,
            board: { MixxBoardView(game: game) }
        )
    }
}
