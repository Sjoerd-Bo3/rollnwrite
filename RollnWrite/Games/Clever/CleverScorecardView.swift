//
//  CleverScorecardView.swift
//  RollnWrite – Clever
//
//  Interactive "That's Pretty Clever" scorecard, rebuilt to look like the
//  printed sheet. Presentation + touch only; all rules and scoring live in
//  `CleverGame`.
//
//  Layout model (the PILOT for the whole Clever family):
//  • The board is a faithful one-screen MINIATURE of the sheet — header
//    (scratch boxes, rounds bar, reroll/+1 tracks), yellow + blue side by
//    side, full-width green/orange/purple bands, and the bottom total strip.
//    `ScaledSheet` scales the whole sheet uniformly to fit — no scrolling,
//    both orientations (the scaffold's landscape lock is opted out of).
//  • The miniature is directly interactive; tapping anywhere else in an area
//    opens a paged EDITOR sheet (`SheetEditorPager`) with a big, comfortable
//    page per area — swipe to move between areas without closing.
//  • Tapping the most-recent mark un-checks it (LIFO undo), as everywhere.
//

import SwiftUI

/// Cream "paper" background behind the sheet.
private let cleverPaper = Color(red: 0.97, green: 0.96, blue: 0.93)
private let cleverInk = Color(red: 0.13, green: 0.13, blue: 0.15)
/// The sheet's light-grey card colour.
private let cleverSheetGrey = Color(white: 0.82)

// MARK: - Sheet sections

/// The tappable regions of the sheet — one editor page each. Sheet order:
/// the five areas, then the rounds / reroll / +1 header tracks.
enum CleverSheetSection: String, CaseIterable, Identifiable, Hashable {
    case yellow, blue, green, orange, purple, tracks

    var id: String { rawValue }

    /// The scoring area behind this section (`nil` for the header tracks).
    var area: CleverArea? { CleverArea(rawValue: rawValue) }

    /// Localisation KEY for the editor page title.
    var title: String { area?.title ?? "Rounds & bonuses" }
}

// MARK: - Scorecard (scaffold wrapper)

public struct CleverScorecardView: View {
    @StateObject private var game = CleverGame()
    let rules: RulesDocument

    @State private var confirmNewGame = false

    public init(rules: RulesDocument) {
        self.rules = rules
    }

    public var body: some View {
        ScorecardScaffold(
            title: "That's Pretty Clever",
            rules: rules,
            // The sheet is portrait-shaped and scales to fit — let it rotate.
            locksLandscape: false,
            board: { CleverSheetBoardView(game: game) },
            headerAccessory: {
                HStack(spacing: 16) {
                    Button { game.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                        .disabled(!game.canUndo)
                        .opacity(game.canUndo ? 1 : 0.4)
                        .accessibilityLabel("Undo")
                    Button(role: .destructive) { confirmNewGame = true } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("New game")
                }
            }
        )
        .background(cleverPaper.ignoresSafeArea())
        .preferredColorScheme(.light)
        .tint(Color(red: 0.55, green: 0.28, blue: 0.72))
        .confirmationDialog("Start a new game?", isPresented: $confirmNewGame, titleVisibility: .visible) {
            Button("New game", role: .destructive) { game.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears the scorecard.")
        }
    }
}

// MARK: - Overview board (the faithful miniature)

struct CleverSheetBoardView: View {
    @ObservedObject var game: CleverGame
    /// Observed so an open board recolours when Settings changes the palette.
    @ObservedObject private var diceTheme = DiceTheme.shared

    @State private var editorSection: CleverSheetSection = .yellow
    @State private var showEditor = false
    @State private var entry: ValueEntry?

    // Design-space constants (pre-scale points). The sheet is laid out at a
    // fixed "natural" size and `ScaledSheet` fits it to the screen.
    private let sheetW: CGFloat = 580
    private let midCell: CGFloat = 36
    private let rowCell: CGFloat = 40

    var body: some View {
        ScaledSheet { sheet }
            .padding(6)
            .overlay(alignment: .top) {
                CleverBonusBanner(game: game)
                    .padding(.horizontal, 12)
            }
            .sheet(isPresented: $showEditor) {
                CleverEditorSheet(game: game, selection: $editorSection)
            }
            .cleverValueEntry($entry)
    }

    private func open(_ section: CleverSheetSection) {
        editorSection = section
        showEditor = true
    }

    // MARK: The sheet

    private var sheet: some View {
        VStack(spacing: 10) {
            headerBand
            HStack(alignment: .top, spacing: 10) {
                panel(.yellow) { CleverYellowGrid(game: game, cell: midCell) }
                panel(.blue) { CleverBluePanel(game: game, cell: midCell) }
            }
            rowBand(.green) {
                CleverGreenRow(game: game, cell: rowCell)
            }
            rowBand(.orange) {
                CleverOrangeRow(game: game, cell: rowCell) { entry = $0 }
            }
            rowBand(.purple) {
                CleverPurpleRow(game: game, cell: rowCell) { entry = $0 }
            }
            totalStrip
        }
        .padding(14)
        .frame(width: sheetW)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cleverSheetGrey)
        )
    }

    // MARK: Header band (scratch boxes + rounds + tracks)

    private var headerBand: some View {
        HStack(alignment: .top, spacing: 10) {
            SheetScratchBoxes(count: 3, box: 42, ink: cleverInk)
            VStack(spacing: 6) {
                SheetRoundsBar(rounds: 6, darkFrom: 4, cell: 30, ink: cleverInk) { r in
                    cleverRoundBadge(r, game: game, size: 16)
                }
                SheetCircleTrack(slots: CleverLayout.rerollTrackSlots,
                                 used: game.state.rerollUsed,
                                 diameter: 17, ink: cleverInk,
                                 icon: { BonusBadge(icon: .reroll, game: game, size: 21) },
                                 tap: { game.toggleReroll($0) })
                SheetCircleTrack(slots: CleverLayout.extraDieTrackSlots,
                                 used: game.state.extraDieUsed,
                                 diameter: 17, ink: cleverInk,
                                 icon: { BonusBadge(icon: .plusOne, game: game, size: 21) },
                                 tap: { game.toggleExtraDie($0) })
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { open(.tracks) }
    }

    // MARK: Area containers (tap outside the cells opens the editor)

    private func panel<Content: View>(
        _ section: CleverSheetSection, @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(game.color(section.area!).color)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onTapGesture { open(section) }
    }

    private func rowBand<Content: View>(
        _ section: CleverSheetSection, @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white)
            content()
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(game.color(section.area!).color)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture { open(section) }
    }

    // MARK: Bottom total strip

    private var totalStrip: some View {
        var entries: [SheetTotalStrip.Entry] = CleverArea.allCases.map {
            SheetTotalStrip.Entry(value: "\(game.score(for: $0))", tint: game.color($0).color)
        }
        entries.append(SheetTotalStrip.Entry(value: "\(game.foxScore)",
                                             caption: "🦊×\(game.foxCount)", tint: .red))
        return SheetTotalStrip(entries: entries, total: game.totalScore,
                               ink: cleverInk, height: 44)
    }
}

// MARK: - Round badges (bonus icons + player-count markers)

/// The badge under a round number: the printed start-of-round bonus for
/// rounds 1–3 (`CleverLayout.roundBonuses`), player-count end markers for
/// rounds 5–6 (3 players → 5 rounds; 1–2 players → 6 rounds).
@MainActor @ViewBuilder
func cleverRoundBadge(_ round: Int, game: CleverGame, size: CGFloat) -> some View {
    if let bonus = CleverLayout.roundBonuses[round] {
        BonusBadge(icon: bonus, game: game, size: size)
    } else if round == 4 {
        Image(systemName: "person.3.fill")
            .font(.system(size: size * 0.55, weight: .bold))
            .foregroundStyle(.white)
    } else if round == 5 {
        Image(systemName: "person.2.fill")
            .font(.system(size: size * 0.6, weight: .bold))
            .foregroundStyle(.white)
    } else {
        Color.clear.frame(width: size, height: size)
    }
}

// MARK: - Yellow area (4×4 grid + row bonuses + column points)

struct CleverYellowGrid: View {
    @ObservedObject var game: CleverGame
    @ObservedObject private var diceTheme = DiceTheme.shared
    let cell: CGFloat

    private var gap: CGFloat { cell * 0.1 }

    var body: some View {
        let tint = game.color(.yellow)
        HStack(alignment: .top, spacing: cell * 0.18) {
            VStack(spacing: gap) {
                grid(tint)
                pointsRow(tint)
            }
            VStack(spacing: gap) {
                ForEach(0..<4, id: \.self) { r in
                    HStack(spacing: 2) {
                        Image(systemName: "arrowtriangle.right.fill")
                            .font(.system(size: cell * 0.22, weight: .black))
                            .foregroundStyle(.black.opacity(0.55))
                        BonusBadge(icon: CleverLayout.yellowRowBonus[r], game: game, size: cell * 0.55)
                    }
                    .frame(height: cell)
                }
                // The main-diagonal +1 bonus, aligned with the points row.
                BonusBadge(icon: .plusOne, game: game, size: cell * 0.5)
                    .frame(maxWidth: .infinity)
                    .frame(height: cell * 0.72)
            }
        }
    }

    private func grid(_ tint: DiceColor) -> some View {
        VStack(spacing: gap) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<4, id: \.self) { col in
                        let idx = row * 4 + col
                        let free = game.isYellowFree(idx)
                        let crossed = game.state.yellowCrossed.contains(idx)
                        let undoable = crossed && game.isLastYellow(idx)
                        SheetCell(
                            label: CleverLayout.yellowGrid[idx].map(String.init) ?? "",
                            tint: tint.color,
                            ink: cleverInk,
                            marked: crossed || free,
                            legal: game.canMarkYellow(idx),
                            undoable: undoable,
                            size: cell
                        ) {
                            if undoable { game.undo() } else { game.markYellow(idx) }
                        }
                    }
                }
            }
        }
        .overlay {
            // The printed dashed main diagonal (its completion grants the +1).
            CleverDiagonalDash()
                .stroke(style: StrokeStyle(lineWidth: cell * 0.06, lineCap: .round,
                                           dash: [cell * 0.14, cell * 0.12]))
                .foregroundStyle(.black.opacity(0.4))
                .allowsHitTesting(false)
        }
    }

    private func pointsRow(_ tint: DiceColor) -> some View {
        HStack(spacing: gap) {
            ForEach(0..<4, id: \.self) { col in
                let done = Set(CleverLayout.yellowColumns[col]).isSubset(of: game.state.yellowCrossed)
                SheetPointsBadge(value: CleverLayout.yellowColumnValues[col],
                                 tint: tint.color, size: cell * 0.55, highlighted: done)
                    .frame(width: cell)
            }
        }
        .padding(.vertical, cell * 0.06)
        .background(Capsule().fill(.white.opacity(0.4)))
    }
}

/// The yellow grid's dashed main diagonal (top-left → bottom-right).
private struct CleverDiagonalDash: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.12))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.maxY - rect.height * 0.12))
        return p
    }
}

// MARK: - Blue area (points scale + 2–12 grid + row/column bonuses)

struct CleverBluePanel: View {
    @ObservedObject var game: CleverGame
    @ObservedObject private var diceTheme = DiceTheme.shared
    let cell: CGFloat
    /// Show the cross-count under each scale badge (used in the big editor).
    var showCounts = false

    private var gap: CGFloat { cell * 0.1 }

    var body: some View {
        let tint = game.color(.blue)
        VStack(spacing: cell * 0.16) {
            scaleRow(tint)
            HStack(alignment: .top, spacing: cell * 0.18) {
                VStack(spacing: gap) {
                    grid(tint)
                    columnBonusRow
                }
                VStack(spacing: gap) {
                    ForEach(0..<3, id: \.self) { r in
                        HStack(spacing: 2) {
                            Image(systemName: "arrowtriangle.right.fill")
                                .font(.system(size: cell * 0.22, weight: .black))
                                .foregroundStyle(.black.opacity(0.55))
                            BonusBadge(icon: CleverLayout.blueRowBonus[r], game: game, size: cell * 0.55)
                        }
                        .frame(height: cell)
                    }
                    Color.clear.frame(width: 1, height: cell * 0.6)
                }
            }
        }
    }

    private func scaleRow(_ tint: DiceColor) -> some View {
        let count = game.state.blueCrossed.count
        return HStack(spacing: 1) {
            ForEach(1...11, id: \.self) { i in
                VStack(spacing: 0) {
                    SheetPointsBadge(value: CleverLayout.bluePointScale[i],
                                     tint: tint.color, size: cell * 0.42, highlighted: i == count)
                    if showCounts {
                        Text("\(i)")
                            .font(.system(size: cell * 0.2, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, cell * 0.06)
        .padding(.horizontal, cell * 0.08)
        .background(
            RoundedRectangle(cornerRadius: cell * 0.18, style: .continuous)
                .fill(.black.opacity(0.32))
        )
    }

    private func grid(_ tint: DiceColor) -> some View {
        VStack(spacing: gap) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<4, id: \.self) { col in
                        if let v = CleverLayout.blueGrid[row * 4 + col] {
                            SheetCell(
                                label: "\(v)",
                                tint: tint.color,
                                ink: cleverInk,
                                marked: game.state.blueCrossed.contains(v),
                                legal: game.canMarkBlue(v),
                                undoable: game.isLastBlue(v),
                                size: cell
                            ) {
                                if game.isLastBlue(v) { game.undo() } else { game.markBlue(v) }
                            }
                        } else {
                            diceHint
                        }
                    }
                }
            }
        }
    }

    /// The printed "blue die + white die" rule reminder in the grid's corner.
    private var diceHint: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cell * 0.2, style: .continuous)
                .fill(.black.opacity(0.32))
            HStack(spacing: 1) {
                Image(systemName: "die.face.5")
                Image(systemName: "plus")
                Image(systemName: "die.face.2.fill")
            }
            .font(.system(size: cell * 0.24, weight: .bold))
            .foregroundStyle(.white)
        }
        .frame(width: cell, height: cell)
        .accessibilityHidden(true)
    }

    private var columnBonusRow: some View {
        HStack(spacing: gap) {
            ForEach(0..<4, id: \.self) { c in
                BonusBadge(icon: CleverLayout.blueColBonus[c], game: game, size: cell * 0.55)
                    .frame(width: cell)
            }
        }
        .padding(.vertical, cell * 0.06)
        .background(Capsule().fill(.white.opacity(0.35)))
    }
}

// MARK: - Green row (11 cells, left→right, points scale above)

struct CleverGreenRow: View {
    @ObservedObject var game: CleverGame
    @ObservedObject private var diceTheme = DiceTheme.shared
    let cell: CGFloat
    /// Wrap into two lines (6 + 5) — used by the big editor page.
    var split = false

    var body: some View {
        let tint = game.color(.green)
        Group {
            if split {
                VStack(alignment: .leading, spacing: cell * 0.3) {
                    segment(0..<6, tint: tint)
                    segment(6..<11, tint: tint)
                }
            } else {
                segment(0..<11, tint: tint)
            }
        }
    }

    private func segment(_ range: Range<Int>, tint: DiceColor) -> some View {
        HStack(alignment: .top, spacing: cell * 0.1) {
            ForEach(range, id: \.self) { i in
                let undoable = game.lastGreenIndex == i
                VStack(spacing: cell * 0.06) {
                    SheetPointsBadge(value: CleverLayout.greenScale[i], tint: tint.color,
                                     size: cell * 0.45,
                                     highlighted: i == game.state.greenCount - 1)
                    SheetCell(
                        label: "≥\(CleverLayout.greenThresholds[i])",
                        tint: tint.color.opacity(0.55),
                        ink: cleverInk,
                        marked: i < game.state.greenCount,
                        legal: i == game.state.greenCount,
                        undoable: undoable,
                        size: cell,
                        fontScale: 0.42
                    ) {
                        if undoable { game.undo() } else { game.markGreen() }
                    }
                    cleverBonusSlot(CleverLayout.greenBonus[i], game: game, size: cell * 0.42)
                }
            }
        }
    }
}

// MARK: - Orange row (write die × multiplier, left→right)

struct CleverOrangeRow: View {
    @ObservedObject var game: CleverGame
    @ObservedObject private var diceTheme = DiceTheme.shared
    let cell: CGFloat
    var split = false
    let requestEntry: (ValueEntry) -> Void

    var body: some View {
        let tint = game.color(.orange)
        Group {
            if split {
                VStack(alignment: .leading, spacing: cell * 0.3) {
                    segment(0..<6, tint: tint)
                    segment(6..<11, tint: tint)
                }
            } else {
                segment(0..<11, tint: tint)
            }
        }
    }

    private func segment(_ range: Range<Int>, tint: DiceColor) -> some View {
        HStack(alignment: .top, spacing: cell * 0.1) {
            ForEach(range, id: \.self) { i in
                let mult = CleverLayout.orangeMultipliers[i]
                let undoable = game.isLastOrange(i)
                VStack(spacing: cell * 0.06) {
                    SheetWriteCell(
                        value: game.state.orange[i].map { $0 * mult },
                        hint: mult > 1 ? "×\(mult)" : nil,
                        tint: tint.color,
                        ink: cleverInk,
                        isNext: game.orangeNextIndex == i,
                        undoable: undoable,
                        size: cell
                    ) {
                        if undoable {
                            game.undo()
                        } else {
                            requestEntry(ValueEntry(title: "Orange die value",
                                                    allowed: game.allowedOrangeValues()) {
                                game.fillOrange($0)
                            })
                        }
                    }
                    cleverBonusSlot(CleverLayout.orangeBonus[i], game: game, size: cell * 0.42)
                }
            }
        }
    }
}

// MARK: - Purple row (strictly increasing, "<" separators)

struct CleverPurpleRow: View {
    @ObservedObject var game: CleverGame
    @ObservedObject private var diceTheme = DiceTheme.shared
    let cell: CGFloat
    var split = false
    let requestEntry: (ValueEntry) -> Void

    var body: some View {
        let tint = game.color(.purple)
        Group {
            if split {
                VStack(alignment: .leading, spacing: cell * 0.3) {
                    segment(0..<6, tint: tint)
                    segment(6..<11, tint: tint)
                }
            } else {
                segment(0..<11, tint: tint)
            }
        }
    }

    private func segment(_ range: Range<Int>, tint: DiceColor) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(range, id: \.self) { i in
                if i > range.lowerBound {
                    Text("<")
                        .font(.system(size: cell * 0.26, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: cell * 0.12, height: cell)
                }
                let undoable = game.isLastPurple(i)
                VStack(spacing: cell * 0.06) {
                    SheetWriteCell(
                        value: game.state.purple[i],
                        tint: tint.color,
                        ink: cleverInk,
                        isNext: game.purpleNextIndex == i,
                        undoable: undoable,
                        size: cell
                    ) {
                        if undoable {
                            game.undo()
                        } else {
                            requestEntry(ValueEntry(title: "Purple die value (> previous)",
                                                    allowed: game.allowedPurpleValues()) {
                                game.fillPurple($0)
                            })
                        }
                    }
                    cleverBonusSlot(CleverLayout.purpleBonus[i], game: game, size: cell * 0.42)
                }
            }
        }
    }
}

/// A fixed-size slot for a printed bonus icon (keeps columns aligned when a
/// cell has no bonus).
@MainActor @ViewBuilder
func cleverBonusSlot(_ icon: BonusIcon?, game: CleverGame, size: CGFloat) -> some View {
    if let icon {
        BonusBadge(icon: icon, game: game, size: size)
    } else {
        Color.clear.frame(width: size, height: size)
    }
}

// MARK: - Editor sheet (big, comfortable, paged)

struct CleverEditorSheet: View {
    @ObservedObject var game: CleverGame
    @ObservedObject private var diceTheme = DiceTheme.shared
    @Binding var selection: CleverSheetSection

    @State private var entry: ValueEntry?

    var body: some View {
        SheetEditorPager(
            sections: CleverSheetSection.allCases,
            selection: $selection,
            title: { $0.title },
            tint: { tint(for: $0) },
            accessory: {
                Button { game.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(!game.canUndo)
                    .opacity(game.canUndo ? 1 : 0.4)
                    .accessibilityLabel("Undo")
            }
        ) { section in
            page(section)
        }
        .background(cleverPaper.ignoresSafeArea())
        .preferredColorScheme(.light)
        .presentationDetents([.large])
        .cleverValueEntry($entry)
    }

    private func tint(for section: CleverSheetSection) -> Color {
        section.area.map { game.color($0).color } ?? Color(white: 0.5)
    }

    private func page(_ section: CleverSheetSection) -> some View {
        VStack(spacing: 12) {
            CleverBonusBanner(game: game)
            ScaledSheet {
                pageContent(section)
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(section == .tracks ? cleverSheetGrey : tint(for: section))
                    )
            }
            footer(section)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 34) // clear the page dots
    }

    @ViewBuilder private func pageContent(_ section: CleverSheetSection) -> some View {
        switch section {
        case .yellow:
            CleverYellowGrid(game: game, cell: 56)
        case .blue:
            CleverBluePanel(game: game, cell: 54, showCounts: true)
        case .green:
            CleverGreenRow(game: game, cell: 54, split: true)
        case .orange:
            CleverOrangeRow(game: game, cell: 54, split: true) { entry = $0 }
        case .purple:
            CleverPurpleRow(game: game, cell: 54, split: true) { entry = $0 }
        case .tracks:
            tracksContent
        }
    }

    private var tracksContent: some View {
        HStack(alignment: .top, spacing: 14) {
            SheetScratchBoxes(count: 3, box: 54, ink: cleverInk)
            VStack(spacing: 10) {
                SheetRoundsBar(rounds: 6, darkFrom: 4, cell: 42, ink: cleverInk) { r in
                    cleverRoundBadge(r, game: game, size: 21)
                }
                SheetCircleTrack(slots: CleverLayout.rerollTrackSlots,
                                 used: game.state.rerollUsed,
                                 diameter: 26, ink: cleverInk,
                                 icon: { BonusBadge(icon: .reroll, game: game, size: 30) },
                                 tap: { game.toggleReroll($0) })
                SheetCircleTrack(slots: CleverLayout.extraDieTrackSlots,
                                 used: game.state.extraDieUsed,
                                 diameter: 26, ink: cleverInk,
                                 icon: { BonusBadge(icon: .plusOne, game: game, size: 30) },
                                 tap: { game.toggleExtraDie($0) })
            }
        }
    }

    @ViewBuilder private func footer(_ section: CleverSheetSection) -> some View {
        if let area = section.area {
            HStack {
                Text(LocalizedStringKey(area.title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(game.score(for: area))")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(cleverInk)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            VStack(spacing: 2) {
                Text("🦊 Foxes earned: \(game.foxCount)")
                Text("Foxes score the lowest area (\(game.lowestAreaScore)) each")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

// MARK: - Earned-bonus banner

/// Advisories for bonuses the player must act on themselves (re-rolls, +1s,
/// free marks of the player's choice). Shared by the overview and the editor.
struct CleverBonusBanner: View {
    @ObservedObject var game: CleverGame

    var body: some View {
        if !game.earnedBonuses.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "gift.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(game.earnedBonuses.suffix(4).enumerated()), id: \.offset) { _, msg in
                        Text(msg).font(.caption.weight(.medium)).foregroundStyle(cleverInk)
                    }
                }
                Spacer(minLength: 0)
                Button { game.clearEarnedBonuses() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.black.opacity(0.08), lineWidth: 1)
            )
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Value entry (orange/purple write-in dialog)

struct ValueEntry: Identifiable {
    let id = UUID()
    /// Localisation KEY for the dialog title (looked up at presentation).
    let title: String
    let allowed: [Int]
    let commit: (Int) -> Void
}

extension View {
    /// Presents the die-value picker for a pending `ValueEntry` request.
    func cleverValueEntry(_ entry: Binding<ValueEntry?>) -> some View {
        confirmationDialog(
            Text(LocalizedStringKey(entry.wrappedValue?.title ?? "")),
            isPresented: Binding(
                get: { entry.wrappedValue != nil },
                set: { if !$0 { entry.wrappedValue = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(entry.wrappedValue?.allowed ?? [], id: \.self) { v in
                Button("\(v)") {
                    entry.wrappedValue?.commit(v)
                    entry.wrappedValue = nil
                }
            }
            Button("Cancel", role: .cancel) { entry.wrappedValue = nil }
        }
    }
}

// MARK: - Bonus badge (printed bonus circles)

struct BonusBadge: View {
    let icon: BonusIcon
    @ObservedObject var game: CleverGame
    /// Observed so badges recolour with the app-wide dice palette.
    @ObservedObject private var diceTheme = DiceTheme.shared
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(background)
            Circle().strokeBorder(.white.opacity(0.85), lineWidth: size * 0.06)
            content
        }
        .frame(width: size, height: size)
    }

    private var background: Color {
        switch icon {
        case .reroll, .plusOne, .fox: return cleverInk
        case let .mark(area): return game.color(area).color
        case let .number(area, _): return game.color(area).color
        }
    }

    @ViewBuilder private var content: some View {
        switch icon {
        case .reroll:
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(.white)
        case .plusOne:
            Text("+1")
                .font(.system(size: size * 0.45, weight: .black))
                .foregroundStyle(.white)
        case .fox:
            Text("🦊").font(.system(size: size * 0.62))
        case let .mark(area):
            Text("✗")
                .font(.system(size: size * 0.55, weight: .black))
                .foregroundStyle(game.color(area).textColor)
        case let .number(area, n):
            Text("\(n)")
                .font(.system(size: size * 0.55, weight: .black))
                .foregroundStyle(game.color(area).textColor)
        }
    }
}
