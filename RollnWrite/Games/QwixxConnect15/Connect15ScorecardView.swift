//
//  Connect15ScorecardView.swift
//  RollnWrite – Qwixx Connect15
//
//  The interactive Qwixx "Connect 15" scorecard. Rule enforcement and scoring are
//  delegated to `Connect15Game`; this file is presentation + touch handling only.
//
//  Built on the reusable scorecard framework: a pure `Connect15BoardView`
//  (fullscreen, edge-to-edge, square-capped tiles via `BoardMetrics.tile`,
//  composed from the Core `BoardComponents`) plus a thin wrapper that drops the
//  board into `ScorecardScaffold` for the header, landscape lock and rules sheet.
//
//  Connect15 specifics: every colour row carries three "connection" fields woven
//  in at the positions printed on the official sheet (`Connect15Layout`). They
//  carry no number, are crossed strictly left → right (link glyph), and count as
//  extra crosses — raising each row's cap to 15 (120 points).
//

import SwiftUI

/// The pure banded board for one player — no navigation chrome. Per-board
/// controls (undo, new game) live in its bottom bar, like the printed card's
/// corner buttons.
struct Connect15BoardView: View {
    @ObservedObject var game: Connect15Game
    @State private var confirmReset = false

    private let tileGap: CGFloat = 4
    private let rowGap: CGFloat = 4
    private let outerPad: CGFloat = 4   // gap to the safe-area edge
    private let bandPad: CGFloat = 4    // coloured border inside each band

    // chevron + 11 numbers + 3 connection fields + lock + per-row score
    private let columns: CGFloat = 17

    init(game: Connect15Game) {
        _game = ObservedObject(wrappedValue: game)
    }

    var body: some View {
        GeometryReader { geo in
            // 4 colour bands + 1 bottom bar; bottom bar ≈ 0.95 of a band's height.
            let t = BoardMetrics.tile(
                in: geo.size,
                columns: columns,
                rowUnits: 4 + 0.95,
                rowCount: 5,
                gap: tileGap,
                pad: outerPad
            )
            boardStack(w: t.w, h: t.h)
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

    // MARK: - Board

    private func boardStack(w: CGFloat, h: CGFloat) -> some View {
        let th = h
        let bottomH = th * 1.05
        return VStack(spacing: rowGap) {
            band(.red, w: w, tile: th)
            band(.yellow, w: w, tile: th)
            band(.green, w: w, tile: th)
            band(.blue, w: w, tile: th)
            bottomBar(w: w, h: bottomH)
        }
    }

    // MARK: - Colour band
    //
    // A row renders, left → right: a direction chevron, the eleven number tiles
    // with the connection fields woven in at their printed positions
    // (`Connect15Layout.connectionColumns`), the lock, and the running score.
    //
    // Connection fields are tracked by COUNT in the engine (crossed left → right,
    // skippable), so the n-th visible field is "crossed" when `crossed > n` and
    // "next" when `crossed == n`. Any capacity beyond the documented print
    // positions is appended just before the lock so all three are always shown.

    private func band(_ color: GameColor, w: CGFloat, tile th: CGFloat) -> some View {
        let row = game.row(for: color)
        let printed = Connect15Layout.connectionColumns[color] ?? []
        // Connection-field ordinals (0-based) keyed by the number column they
        // follow; remaining fields up to capacity sit at the row's end (-1 key).
        let weave = connectionPlacement(printed: printed)

        return HStack(spacing: tileGap) {
            BandChevron(w: w, h: th)
            ForEach(0..<11, id: \.self) { i in
                numberTile(color, i, w: w, th: th)
                if let ordinal = weave.afterColumn[i] {
                    connectionTile(color, ordinal: ordinal, w: w, th: th)
                }
            }
            // Connection fields that have no documented print position go here,
            // keeping every row at the full three (and aligned across rows).
            ForEach(weave.trailing, id: \.self) { ordinal in
                connectionTile(color, ordinal: ordinal, w: w, th: th)
            }
            LockTile(tint: color.tint, locked: row.locked, w: w, h: th)
                .accessibilityLabel("\(color.displayName) lock")
            ScoreTile(game.points(for: color), w: w, h: th)
        }
        .colourBand(tint: color.tint, hPad: bandPad, vPad: th * 0.09, corner: min(w, th) * 0.3)
    }

    /// Maps the documented per-row connection positions onto connection-field
    /// ordinals, assigning any leftover ordinals (up to capacity) to the trailing
    /// group so every row shows all `ConnectionFields.capacity` fields.
    private func connectionPlacement(printed: [Int]) -> (afterColumn: [Int: Int], trailing: [Int]) {
        var afterColumn: [Int: Int] = [:]
        let cappedPrinted = Array(printed.prefix(ConnectionFields.capacity))
        for (ordinal, column) in cappedPrinted.enumerated() {
            afterColumn[column] = ordinal
        }
        let placed = cappedPrinted.count
        let trailing = placed < ConnectionFields.capacity ? Array(placed..<ConnectionFields.capacity) : []
        return (afterColumn, trailing)
    }

    private func numberTile(_ color: GameColor, _ i: Int, w: CGFloat, th: CGFloat) -> some View {
        let marked = game.row(for: color).marks.contains(i)
        let undoable = marked && game.isLastColorMark(color, i)
        return NumberTile("\(color.numbers[i])", tint: color.tint,
                          marked: marked, legal: game.canMarkColor(color, i),
                          undoable: undoable, w: w, h: th) {
            if undoable { game.undo() } else { game.markColor(color, i) }
        }
        .accessibilityLabel("\(color.displayName) \(color.numbers[i])")
    }

    /// One connection field. `ordinal` is its 0-based order within the row's
    /// three fields; the engine crosses them strictly left → right.
    private func connectionTile(_ color: GameColor, ordinal: Int, w: CGFloat, th: CGFloat) -> some View {
        let crossed = game.connections(for: color).crossed
        let isMarked = ordinal < crossed
        // The next legal field is the left-most uncrossed one.
        let isNext = ordinal == crossed && game.canMarkConnection(color)
        // Only the most-recently-crossed field (the highest crossed ordinal) is
        // tap-undoable, and only if a connection mark is the last action.
        let isLastCrossed = ordinal == crossed - 1
        let undoable = isMarked && isLastCrossed && game.isLastConnectionMark(color)
        return ConnectionTile(
            tint: color.tint,
            textColor: color.textColor,
            marked: isMarked,
            legal: isNext,
            undoable: undoable,
            w: w, h: th
        ) {
            if undoable { game.undo() } else if isNext { game.markConnection(color) }
        }
        .accessibilityLabel("\(color.displayName) connection field")
    }

    // MARK: - Bottom bar
    //
    // Controls (undo, new game) on the left; penalties + running total on the
    // right — echoing the corner buttons on the printed card.

    private func bottomBar(w: CGFloat, h: CGFloat) -> some View {
        let b = min(h, 64)
        return HStack(spacing: tileGap) {
            BoardControlButton("arrow.uturn.backward", size: b) { game.undo() }
                .disabled(!game.canUndo)
                .opacity(game.canUndo ? 1 : 0.4)
            BoardControlButton("trash", size: b) { confirmReset = true }
            Spacer(minLength: w * 0.1)
            ForEach(0..<Connect15State.maxPenalties, id: \.self) { i in
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

/// A Connect15 "connection" field tile: a dashed-edged cell carrying a link glyph
/// (uncrossed) or an X (crossed). Styled like the Core `NumberTile` but specific
/// to Connect15's number-less connection spaces, so it stays in the game module.
private struct ConnectionTile: View {
    let tint: Color
    let textColor: Color
    let marked: Bool
    let legal: Bool
    let undoable: Bool
    let w: CGFloat
    let h: CGFloat
    let onTap: () -> Void

    var body: some View {
        let s = min(w, h)
        let dimmed = !marked && !legal
        return Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                    .fill(tint)
                    .overlay(
                        RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                            .strokeBorder(.white.opacity(0.9),
                                          style: StrokeStyle(lineWidth: s * 0.07, dash: [s * 0.16, s * 0.1]))
                    )
                if marked {
                    Image(systemName: "xmark")
                        .font(.system(size: s * 0.66, weight: .black))
                        .foregroundStyle(textColor)
                } else {
                    Image(systemName: "link")
                        .font(.system(size: s * 0.46, weight: .bold))
                        .foregroundStyle(textColor)
                }
            }
            .frame(width: w, height: h)
            .overlay(
                RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                    .strokeBorder(.white, lineWidth: undoable ? 2.5 : 0)
            )
        }
        .buttonStyle(.plain)
        .disabled(!(legal || undoable))
        .opacity(dimmed ? 0.3 : 1)
        .accessibilityValue(marked ? "marked" : (legal ? "available" : "blocked"))
        .accessibilityHint(undoable ? "Tap to undo" : "")
        .animation(.easeOut(duration: 0.12), value: marked)
    }
}

/// Hosts one Connect15 board, wrapping it in the shared `ScorecardScaffold`
/// (header, landscape lock, rules). The chrome is reused from Core.
public struct Connect15ScorecardView: View {
    @ObservedObject var game: Connect15Game
    let rules: RulesDocument

    public init(game: Connect15Game, rules: RulesDocument) {
        _game = ObservedObject(wrappedValue: game)
        self.rules = rules
    }

    public var body: some View {
        ScorecardScaffold(
            title: "Qwixx Connect15",
            rules: rules,
            board: { Connect15BoardView(game: game) }
        )
    }
}

// MARK: - Variant owner
//
// Owns its own `Connect15Game` via the `@StateObject` property-default pattern
// and renders the scorecard.

/// Qwixx Connect15: four classic colour rows plus three connection fields each
/// (cap 15 → 120).
public struct QwixxConnect15ScorecardView: View {
    @StateObject private var game = Connect15Game()
    let rules: RulesDocument

    public init(rules: RulesDocument) { self.rules = rules }

    public var body: some View {
        Connect15ScorecardView(game: game, rules: rules)
    }
}
