//
//  CleverScorecardView.swift
//  RollnWrite – Clever
//
//  Interactive "That's Pretty Clever" scorecard, rebuilt to look like the
//  printed sheet. Presentation + touch only; all rules and scoring live in
//  `CleverGame`.
//
//  Layout model (the CANONICAL v3 concept for the whole Clever family —
//  the owner's verdict after the three-layout on-device comparison):
//  • PORTRAIT: a faithful one-screen MINIATURE of the sheet — header
//    (rounds bar, reroll/+1 tracks), yellow + blue side by side, full-width
//    green/orange/purple bands, and the bottom total strip. `ScaledSheet`
//    scales the whole sheet uniformly to fit — no scrolling. The miniature
//    is directly interactive; tapping anywhere else in an area opens a paged
//    EDITOR sheet (`SheetEditorPager`) with a big, comfortable page per
//    area — swipe to move between areas without closing.
//  • LANDSCAPE: the direct-tap two-column reflow (`CleverV3LandscapeBoard`
//    in CleverV3ScorecardView.swift) — no editor needed at that cell size.
//  • Tapping the most-recent mark un-checks it (LIFO undo), as everywhere.
//

import SwiftUI

/// Cream "paper" background behind the sheet. Internal (not `private`) so the
/// v3 layout experiment (`CleverV3ScorecardView.swift`) shares the exact values.
let cleverPaper = Color(red: 0.97, green: 0.96, blue: 0.93)
let cleverInk = Color(red: 0.13, green: 0.13, blue: 0.15)
/// The sheet's light-grey card colour.
let cleverSheetGrey = Color(white: 0.82)

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

// MARK: - Board layout (v3 default + list option)

/// The two board layouts: `.sheet` is the canonical v3 board (portrait sheet
/// miniature, landscape direct-tap reflow) and `.list` is one vertical
/// scrolling list of full-size areas (inline editing — an owner-approved
/// exception to the no-scroll rule; kept as an option by owner request).
/// The raw values predate v3, so stored preferences carry over unchanged.
enum CleverBoardLayout: String {
    case sheet, list
    static let storageKey = "clever.layout"
}

// MARK: - Scorecard (scaffold wrapper)

public struct CleverScorecardView: View {
    @StateObject private var game = CleverGame()
    /// Independent second engine for the across-the-table mirror (same
    /// pattern as the Qwixx variant owners' `.p2.state` engines).
    @StateObject private var opponent = CleverGame(persistenceKey: "rollnwrite.clever1.p2.state")
    let rules: RulesDocument

    @State private var confirmNewGame = false
    @AppStorage(CleverBoardLayout.storageKey) private var layoutRaw = CleverBoardLayout.sheet.rawValue

    public init(rules: RulesDocument) {
        self.rules = rules
    }

    private var layout: CleverBoardLayout { CleverBoardLayout(rawValue: layoutRaw) ?? .sheet }

    public var body: some View {
        ScorecardScaffold(
            title: "That's Pretty Clever",
            rules: rules,
            // Both orientations scale to fit — let the screen rotate freely.
            locksLandscape: false,
            board: {
                Group {
                    switch layout {
                    case .sheet: CleverV3BoardView(game: game)
                    case .list: CleverListBoardView(game: game)
                    }
                }
            },
            // Two-player: in landscape each half is a portrait-aspect slot, so
            // the orientation switch renders two SHEET miniatures side by side
            // (the opponent's flipped); portrait stacks two landscape reflows.
            opponent: {
                Group {
                    switch layout {
                    case .sheet: CleverV3BoardView(game: opponent)
                    case .list: CleverListBoardView(game: opponent)
                    }
                }
            },
            headerAccessory: {
                HStack(spacing: 16) {
                    Button {
                        layoutRaw = (layout == .sheet ? CleverBoardLayout.list : .sheet).rawValue
                    } label: {
                        // The icon shows the layout the tap switches TO.
                        Image(systemName: layout == .sheet ? "list.bullet" : "rectangle.grid.1x2")
                    }
                    .accessibilityLabel(layout == .sheet ? "List layout" : "Sheet layout")
                    Button { game.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                        .disabled(!game.canUndo)
                        .opacity(game.canUndo ? 1 : 0.5)
                        .accessibilityLabel("Undo")
                    Button(role: .destructive) { confirmNewGame = true } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("New game")
                }
            }
        )
        .background(cleverPaper.ignoresSafeArea())
        // Force LIGHT resolution of every dynamic colour on this screen. The
        // app root applies its own `.preferredColorScheme` (the Settings
        // appearance) and the OUTERMOST preference wins, so a nested
        // `.preferredColorScheme(.light)` is ignored in dark mode — `.primary`
        // in the scaffold header then resolved to near-white on the cream
        // paper (the washed-out header). Setting the environment directly is
        // deterministic and scoped to this subtree only.
        .environment(\.colorScheme, .light)
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
    @ObservedObject var diceTheme = DiceTheme.shared

    @State private var editorSection: CleverSheetSection = .yellow
    @State private var showEditor = false
    @State private var entry: ValueEntry?

    /// Explicit init: the private `@State`s above make the synthesized
    /// memberwise init non-internal, and the v3 layout experiment (a separate
    /// file) reuses this board as its portrait fallback.
    init(game: CleverGame) {
        self.game = game
    }

    // Design-space constants (pre-scale points). The sheet is laid out at a
    // fixed "natural" WIDTH; `ScaledSheet` stretches its heights to consume
    // the available aspect (portrait) and then scales the whole sheet to fit.
    private let sheetW: CGFloat = 580
    private let midCell: CGFloat = 36
    /// Width available to a row band's CELLS: the sheet width minus the
    /// sheet's horizontal padding (2×14), the band's own padding (2×8), the
    /// fixed-width chevron (14) and its spacing (6). Cell sizes are derived
    /// from it so the 11th cell ends flush with the band — no trailing gap.
    private var bandContentW: CGFloat { sheetW - 28 - 16 - 14 - 6 }
    /// Green/orange rows: 11 cells + 10 gaps of 0.1×cell = 12 cell widths.
    private var rowCell: CGFloat { bandContentW / 12 }
    /// Purple row: 11 cells + 10 "<" separators of 0.24×cell = 13.4 widths.
    private var purpleRowCell: CGFloat { bandContentW / 13.4 }

    var body: some View {
        ScaledSheet(maxStretch: 1.6) { stretch in sheet(stretch) }
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

    private func sheet(_ stretch: CGFloat) -> some View {
        VStack(spacing: 10 * stretch) {
            headerBand(stretch)
            HStack(alignment: .top, spacing: 10) {
                panel(.yellow, stretch) { CleverYellowGrid(game: game, cell: midCell, stretch: stretch) }
                panel(.blue, stretch) { CleverBluePanel(game: game, cell: midCell, stretch: stretch) }
            }
            rowBand(.green, stretch) {
                CleverGreenRow(game: game, cell: rowCell, stretch: stretch)
            }
            rowBand(.orange, stretch) {
                CleverOrangeRow(game: game, cell: rowCell, stretch: stretch) { entry = $0 }
            }
            rowBand(.purple, stretch) {
                // `bonusCell: rowCell` — one shared badge size + cell→badge
                // baseline distance across the green/orange/purple bands.
                CleverPurpleRow(game: game, cell: purpleRowCell, stretch: stretch,
                                bonusCell: rowCell) { entry = $0 }
            }
            cleverTotalStrip(game: game, height: 44 * min(stretch, 1.25))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14 * stretch)
        .frame(width: sheetW)
        .background(
            RoundedRectangle(cornerRadius: SheetRadius.card, style: .continuous)
                .fill(cleverSheetGrey)
        )
    }

    // MARK: Header band (rounds + tracks)

    private func headerBand(_ stretch: CGFloat) -> some View {
        VStack(spacing: 6 * stretch) {
            SheetRoundsBar(rounds: 6, darkFrom: 4, cell: 30, ink: cleverInk, stretch: stretch,
                           crossed: game.state.roundsCrossed,
                           tap: { game.toggleRound($0) }) { r in
                cleverRoundBadge(r, game: game, size: 16)
            }
            SheetCircleTrack(slots: CleverLayout.rerollTrackSlots,
                             used: game.state.rerollUsed,
                             earned: game.rerollsEarned,
                             diameter: 17, ink: cleverInk, stretch: stretch,
                             icon: { BonusBadge(icon: .reroll, game: game, size: 21) },
                             tap: { game.toggleReroll($0) })
            SheetCircleTrack(slots: CleverLayout.extraDieTrackSlots,
                             used: game.state.extraDieUsed,
                             earned: game.extraDiceEarned,
                             diameter: 17, ink: cleverInk, stretch: stretch,
                             icon: { BonusBadge(icon: .plusOne, game: game, size: 21) },
                             tap: { game.toggleExtraDie($0) })
        }
        .contentShape(Rectangle())
        .onTapGesture { open(.tracks) }
    }

    // MARK: Area containers (tap outside the cells opens the editor)

    private func panel<Content: View>(
        _ section: CleverSheetSection, _ stretch: CGFloat, @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, 10)
            .padding(.vertical, 10 * stretch)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: SheetRadius.panel, style: .continuous)
                    .fill(game.color(section.area!).color)
            )
            .contentShape(RoundedRectangle(cornerRadius: SheetRadius.panel, style: .continuous))
            .onTapGesture { open(section) }
    }

    private func rowBand<Content: View>(
        _ section: CleverSheetSection, _ stretch: CGFloat, @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 14) // fixed so `bandContentW` is exact
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8 * stretch)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SheetRadius.panel, style: .continuous)
                .fill(game.color(section.area!).color)
        )
        .contentShape(RoundedRectangle(cornerRadius: SheetRadius.panel, style: .continuous))
        .onTapGesture { open(section) }
    }
}

/// The bottom summary strip (per-area scores + foxes + total).
@MainActor
func cleverTotalStrip(game: CleverGame, height: CGFloat) -> some View {
    var entries: [SheetTotalStrip.Entry] = CleverArea.allCases.map {
        SheetTotalStrip.Entry(value: "\(game.score(for: $0))", tint: game.color($0).color)
    }
    entries.append(SheetTotalStrip.Entry(value: "\(game.foxScore)",
                                         caption: "🦊×\(game.foxCount)", tint: .red))
    return SheetTotalStrip(entries: entries, total: game.totalScore,
                           ink: cleverInk, height: height)
}

// MARK: - Round badges (bonus icons + player-count markers)

/// The badge under a round number: the printed start-of-round bonus for
/// rounds 1–3 (`CleverLayout.roundBonuses`), round 4's printed "✗ | 6" badge
/// (`CleverLayout.roundFourBonus` — kept separate from `roundBonuses` so it
/// never feeds the reroll/+1 earned counts), and player-count end markers for
/// rounds 5–6 (3 players → 5 rounds; 1–2 players → 6 rounds). Every branch
/// occupies the identical `size`×`size` box, so round tiles keep equal
/// heights everywhere rounds render (header bar, list/editor bars, v3 rail).
@MainActor
func cleverRoundBadge(_ round: Int, game: CleverGame, size: CGFloat) -> some View {
    Group {
        if let bonus = CleverLayout.roundBonuses[round] {
            BonusBadge(icon: bonus, game: game, size: size)
        } else if round == 3 {
            BonusBadge(icon: CleverLayout.roundFourBonus, game: game, size: size)
        } else if round == 4 {
            Image(systemName: "person.3.fill")
                .font(.system(size: size * 0.55, weight: .bold))
                .foregroundStyle(.white)
        } else if round == 5 {
            Image(systemName: "person.2.fill")
                .font(.system(size: size * 0.6, weight: .bold))
                .foregroundStyle(.white)
        } else {
            Color.clear
        }
    }
    .frame(width: size, height: size)
}

// MARK: - Yellow area (4×4 grid + row bonuses + column points)

struct CleverYellowGrid: View {
    @ObservedObject var game: CleverGame
    @ObservedObject var diceTheme = DiceTheme.shared
    let cell: CGFloat
    /// Vertical stretch — multiplies cell heights and vertical gaps only.
    var stretch: CGFloat = 1

    private var gap: CGFloat { cell * 0.1 }
    private var vgap: CGFloat { gap * stretch }
    private var cellH: CGFloat { cell * stretch }
    // The trailing row-bonus column is ONE fixed-width column: an arrow slot,
    // a gap and an equal badge box — every ▶+badge pair (and the +1 below)
    // shares the same centreline.
    private var arrowW: CGFloat { cell * 0.26 }
    private var badgeBox: CGFloat { cell * 0.78 }
    private var bonusColW: CGFloat { arrowW + cell * 0.06 + badgeBox }

    var body: some View {
        let tint = game.color(.yellow)
        HStack(alignment: .top, spacing: cell * 0.18) {
            VStack(spacing: vgap) {
                grid(tint)
                pointsRow(tint)
            }
            VStack(spacing: vgap) {
                ForEach(0..<4, id: \.self) { r in
                    HStack(spacing: cell * 0.06) {
                        Image(systemName: "arrowtriangle.right.fill")
                            .font(.system(size: cell * 0.22, weight: .black))
                            .foregroundStyle(.black.opacity(0.55))
                            .frame(width: arrowW)
                        BonusBadge(icon: CleverLayout.yellowRowBonus[r], game: game, size: badgeBox)
                            .frame(width: badgeBox, height: badgeBox)
                    }
                    // Vertically centred against its grid row (same height).
                    .frame(width: bonusColW, height: cellH)
                }
                // The main-diagonal +1 bonus, aligned with the points row and
                // on the badges' shared centreline (empty arrow slot).
                HStack(spacing: cell * 0.06) {
                    Color.clear.frame(width: arrowW, height: 1)
                    BonusBadge(icon: .plusOne, game: game, size: cell * 0.7)
                        .frame(width: badgeBox, height: badgeBox)
                }
                .frame(width: bonusColW, height: cell * 0.9)
            }
            .frame(width: bonusColW)
        }
    }

    private func grid(_ tint: DiceColor) -> some View {
        VStack(spacing: vgap) {
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
                            size: cell,
                            height: cellH
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
                .stroke(style: StrokeStyle(lineWidth: SheetStroke.medium, lineCap: .round,
                                           dash: [cell * 0.14, cell * 0.12]))
                .foregroundStyle(.black.opacity(0.4))
                .allowsHitTesting(false)
        }
        .overlay { CleverGridConnectors(cols: 4, rows: 4, hGap: gap, vGap: vgap) }
    }

    private func pointsRow(_ tint: DiceColor) -> some View {
        VStack(spacing: 0) {
            // Down-arrows chaining each column into its points seal below,
            // as printed. Same glyph/size as the row-end arrows for one
            // consistent connector language.
            HStack(spacing: gap) {
                ForEach(0..<4, id: \.self) { _ in
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: cell * 0.22, weight: .black))
                        .foregroundStyle(.black.opacity(0.55))
                        .frame(width: cell)
                }
            }
            .frame(height: cell * 0.24)
            .allowsHitTesting(false)
            HStack(spacing: gap) {
                ForEach(0..<4, id: \.self) { col in
                    let done = Set(CleverLayout.yellowColumns[col]).isSubset(of: game.state.yellowCrossed)
                    SheetPointsBadge(value: CleverLayout.yellowColumnValues[col],
                                     tint: tint.color, size: cell * 0.78, highlighted: done)
                        .frame(width: cell)
                }
            }
            .padding(.vertical, cell * 0.06)
            .background(Capsule().fill(.white.opacity(0.4)))
        }
    }
}

/// The printed grid's dark connector dashes: a small rounded tab centred in
/// EVERY gap between horizontally- or vertically-adjacent cells (the "chain"
/// linking every cell, as on the pad). Purely decorative print detail —
/// non-interactive, drawn as an overlay sized to the EXACT grid footprint via
/// `GeometryReader` (rather than replicating the sibling `HStack`/`VStack`
/// spacer maths by hand, which would drift out of sync if that layout ever
/// changes). Cell/gap centres follow directly from the reader's measured
/// size: for `n` cells with `n-1` gaps of width `gap` in a span `total`,
/// `cell = (total - (n-1)·gap) / n`; the i-th gap's centre sits at
/// `i·(cell+gap) + cell + gap/2`. Subtle: dark ink at ~0.55 opacity, matching
/// the row/column arrow glyphs.
struct CleverGridConnectors: View {
    let cols: Int
    let rows: Int
    let hGap: CGFloat
    let vGap: CGFloat
    /// Horizontal gaps to skip (e.g. the blue grid's row-0 dice-hint cell has
    /// no printed connector into "2"): `(row, gapIndex)` where `gapIndex` is
    /// the gap before column `gapIndex + 1`. Empty for grids with no non-cell
    /// tiles (yellow).
    var skipHGaps: Set<GridGap> = []

    struct GridGap: Hashable { let row: Int; let gapIndex: Int }

    var body: some View {
        GeometryReader { geo in
            let cellW = (geo.size.width - CGFloat(cols - 1) * hGap) / CGFloat(cols)
            let cellHgt = (geo.size.height - CGFloat(rows - 1) * vGap) / CGFloat(rows)
            let tabW = min(hGap, vGap) * 1.6
            let tabH = min(hGap, vGap) * 1.6

            // Horizontal tabs: centred in each internal column gap, once per row.
            ForEach(0..<rows, id: \.self) { r in
                ForEach(0..<(cols - 1), id: \.self) { c in
                    if !skipHGaps.contains(GridGap(row: r, gapIndex: c)) {
                        let cx = CGFloat(c + 1) * (cellW + hGap) - hGap / 2
                        let cy = CGFloat(r) * (cellHgt + vGap) + cellHgt / 2
                        RoundedRectangle(cornerRadius: tabH * 0.3, style: .continuous)
                            .fill(.black.opacity(0.55))
                            .frame(width: hGap, height: tabH)
                            .position(x: cx, y: cy)
                    }
                }
            }
            // Vertical tabs: centred in each internal row gap, once per column.
            ForEach(0..<(rows - 1), id: \.self) { r in
                ForEach(0..<cols, id: \.self) { c in
                    let cx = CGFloat(c) * (cellW + hGap) + cellW / 2
                    let cy = CGFloat(r + 1) * (cellHgt + vGap) - vGap / 2
                    RoundedRectangle(cornerRadius: tabW * 0.3, style: .continuous)
                        .fill(.black.opacity(0.55))
                        .frame(width: tabW, height: vGap)
                        .position(x: cx, y: cy)
                }
            }
        }
        .allowsHitTesting(false)
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
    @ObservedObject var diceTheme = DiceTheme.shared
    let cell: CGFloat
    /// Show the cross-count under each scale badge (used in the big editor).
    var showCounts = false
    /// Vertical stretch — multiplies cell heights and vertical gaps only.
    var stretch: CGFloat = 1

    private var gap: CGFloat { cell * 0.1 }
    private var vgap: CGFloat { gap * stretch }
    private var cellH: CGFloat { cell * stretch }
    // Same fixed-width row-bonus column as the yellow grid (shared centreline).
    private var arrowW: CGFloat { cell * 0.26 }
    private var badgeBox: CGFloat { cell * 0.78 }
    private var bonusColW: CGFloat { arrowW + cell * 0.06 + badgeBox }

    var body: some View {
        let tint = game.color(.blue)
        VStack(spacing: cell * 0.16 * stretch) {
            scaleRow(tint)
            HStack(alignment: .top, spacing: cell * 0.18) {
                VStack(spacing: vgap) {
                    grid(tint)
                    columnBonusRow
                }
                VStack(spacing: vgap) {
                    ForEach(0..<3, id: \.self) { r in
                        HStack(spacing: cell * 0.06) {
                            Image(systemName: "arrowtriangle.right.fill")
                                .font(.system(size: cell * 0.22, weight: .black))
                                .foregroundStyle(.black.opacity(0.55))
                                .frame(width: arrowW)
                            BonusBadge(icon: CleverLayout.blueRowBonus[r], game: game, size: badgeBox)
                                .frame(width: badgeBox, height: badgeBox)
                        }
                        .frame(width: bonusColW, height: cellH)
                    }
                    Color.clear.frame(width: bonusColW, height: cell * 0.6)
                }
                .frame(width: bonusColW)
            }
        }
    }

    private func scaleRow(_ tint: DiceColor) -> some View {
        let count = game.state.blueCrossed.count
        // Seals slightly OVERLAP (negative spacing), like the printed strip —
        // that is what lets them grow ~1.25× and still fit 11-across.
        return HStack(spacing: -2) {
            ForEach(1...11, id: \.self) { i in
                VStack(spacing: 0) {
                    SheetPointsBadge(value: CleverLayout.bluePointScale[i],
                                     tint: tint.color, size: cell * 0.52, highlighted: i == count)
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
        .padding(.horizontal, cell * 0.1)
        .background(
            RoundedRectangle(cornerRadius: SheetRadius.pill, style: .continuous)
                .fill(.black.opacity(0.32))
        )
        // Inset the strip clear of the surrounding panel's corner rounding
        // (panel radius 14 − panel content padding 10), so seal #1 never
        // tucks under the top-left curve.
        .padding(.horizontal, SheetRadius.panel - 10)
    }

    private func grid(_ tint: DiceColor) -> some View {
        VStack(spacing: vgap) {
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
                                size: cell,
                                height: cellH
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
        .overlay {
            // Same connector language as yellow, except the row-0 dice-hint
            // tile is not a real cell — the pad prints no dash leading into
            // "2", so that one gap (row 0, gap index 0) is skipped.
            CleverGridConnectors(cols: 4, rows: 3, hGap: gap, vGap: vgap,
                                 skipHGaps: [.init(row: 0, gapIndex: 0)])
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
        .frame(width: cell, height: cellH)
        .accessibilityHidden(true)
    }

    private var columnBonusRow: some View {
        VStack(spacing: 0) {
            // Down-arrows chaining each column into its bonus badge below,
            // as printed — same glyph/size as the yellow grid's.
            HStack(spacing: gap) {
                ForEach(0..<4, id: \.self) { _ in
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: cell * 0.22, weight: .black))
                        .foregroundStyle(.black.opacity(0.55))
                        .frame(width: cell)
                }
            }
            .frame(height: cell * 0.24)
            .allowsHitTesting(false)
            HStack(spacing: gap) {
                ForEach(0..<4, id: \.self) { c in
                    BonusBadge(icon: CleverLayout.blueColBonus[c], game: game, size: cell * 0.78)
                        .frame(width: cell)
                }
            }
            .padding(.vertical, cell * 0.06)
            .background(Capsule().fill(.white.opacity(0.35)))
        }
    }
}

// MARK: - Green row (11 cells, left→right, points scale above)

struct CleverGreenRow: View {
    @ObservedObject var game: CleverGame
    @ObservedObject var diceTheme = DiceTheme.shared
    let cell: CGFloat
    /// Wrap into two lines (6 + 5) — used by the big editor page.
    var split = false
    /// Vertical stretch — multiplies cell heights and vertical gaps only.
    var stretch: CGFloat = 1

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
                VStack(spacing: cell * 0.06 * stretch) {
                    SheetPointsBadge(value: CleverLayout.greenScale[i], tint: tint.color,
                                     size: cell * 0.62,
                                     highlighted: i == game.state.greenCount - 1)
                    SheetCell(
                        // Near-full tint: the cell's own blocked-state dimming
                        // (×0.55) lands the ghost "≥n" at readable placeholder
                        // strength instead of double-fading it to invisible.
                        label: "≥\(CleverLayout.greenThresholds[i])",
                        tint: tint.color.opacity(0.85),
                        ink: cleverInk,
                        marked: i < game.state.greenCount,
                        legal: i == game.state.greenCount,
                        undoable: undoable,
                        size: cell,
                        height: cell * stretch,
                        fontScale: 0.48
                    ) {
                        if undoable { game.undo() } else { game.markGreen() }
                    }
                    cleverBonusSlot(CleverLayout.greenBonus[i], game: game, size: cell * 0.6)
                }
            }
        }
    }
}

// MARK: - Orange row (write die × multiplier, left→right)

struct CleverOrangeRow: View {
    @ObservedObject var game: CleverGame
    @ObservedObject var diceTheme = DiceTheme.shared
    let cell: CGFloat
    var split = false
    /// Vertical stretch — multiplies cell heights and vertical gaps only.
    var stretch: CGFloat = 1
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
                VStack(spacing: cell * 0.06 * stretch) {
                    SheetWriteCell(
                        value: game.state.orange[i].map { $0 * mult },
                        hint: mult > 1 ? "×\(mult)" : nil,
                        tint: tint.color,
                        ink: cleverInk,
                        isNext: game.orangeNextIndex == i,
                        undoable: undoable,
                        size: cell,
                        height: cell * stretch
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
                    cleverBonusSlot(CleverLayout.orangeBonus[i], game: game, size: cell * 0.6)
                }
            }
        }
    }
}

// MARK: - Purple row (strictly increasing, "<" separators)

struct CleverPurpleRow: View {
    @ObservedObject var game: CleverGame
    @ObservedObject var diceTheme = DiceTheme.shared
    let cell: CGFloat
    var split = false
    /// Vertical stretch — multiplies cell heights and vertical gaps only.
    var stretch: CGFloat = 1
    /// Metric for the under-cell bonus badges (size + baseline distance).
    /// Purple's cells are narrower than green/orange's (the "<" separators);
    /// pass the sibling bands' cell so all three bands share ONE badge size
    /// and ONE cell→badge distance. Defaults to `cell`.
    var bonusCell: CGFloat? = nil
    let requestEntry: (ValueEntry) -> Void

    private var bCell: CGFloat { bonusCell ?? cell }

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
                    // Real horizontal room (0.24×cell) so the glyph is never
                    // clipped, and full-contrast white to match the bonuses.
                    Text("<")
                        .font(.system(size: cell * 0.34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: cell * 0.24, height: cell * stretch)
                }
                let undoable = game.isLastPurple(i)
                VStack(spacing: bCell * 0.06 * stretch) {
                    SheetWriteCell(
                        value: game.state.purple[i],
                        tint: tint.color,
                        ink: cleverInk,
                        isNext: game.purpleNextIndex == i,
                        undoable: undoable,
                        size: cell,
                        height: cell * stretch
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
                    cleverBonusSlot(CleverLayout.purpleBonus[i], game: game, size: bCell * 0.6)
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

// MARK: - Layout option: one scrolling list of full-size areas

/// The "list" layout option: every area stacked in ONE vertical scrolling
/// list at full interactive size — inline editing, no modal. (A ScrollView
/// here is an owner-approved exception to the no-scroll rule; the owner keeps
/// this layout as a first-class option alongside the v3 board.) Uses the SAME
/// area views as the editor pages; each card scales down to the screen width
/// via `WidthScaledCard` (a `ScaledSheet` cannot measure available space
/// inside a scroll view).
struct CleverListBoardView: View {
    @ObservedObject var game: CleverGame
    /// Observed so an open board recolours when Settings changes the palette.
    @ObservedObject var diceTheme = DiceTheme.shared
    @State private var entry: ValueEntry?

    var body: some View {
        GeometryReader { geo in
            let cardW = geo.size.width - 24
            ScrollView {
                VStack(spacing: 14) {
                    CleverBonusBanner(game: game)
                    card(.tracks, width: cardW) { tracksContent }
                    card(.yellow, width: cardW) {
                        CleverYellowGrid(game: game, cell: 54)
                    }
                    card(.blue, width: cardW) {
                        CleverBluePanel(game: game, cell: 52, showCounts: true)
                    }
                    card(.green, width: cardW) {
                        CleverGreenRow(game: game, cell: 52, split: true)
                    }
                    card(.orange, width: cardW) {
                        CleverOrangeRow(game: game, cell: 52, split: true) { entry = $0 }
                    }
                    card(.purple, width: cardW) {
                        CleverPurpleRow(game: game, cell: 52, split: true) { entry = $0 }
                    }
                    WidthScaledCard(width: cardW) {
                        cleverTotalStrip(game: game, height: 46)
                            .padding(12)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: SheetRadius.panel, style: .continuous)
                            .fill(cleverSheetGrey)
                    )
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
        }
        .cleverValueEntry($entry)
    }

    /// One list card: the area's title + live score above the area content on
    /// its coloured panel — the editor-page look, inline in the list.
    private func card<Content: View>(
        _ section: CleverSheetSection, width: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(LocalizedStringKey(section.title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let area = section.area {
                    Text("\(game.score(for: area))")
                        .font(.headline.monospacedDigit())
                }
            }
            .padding(.horizontal, 4)
            WidthScaledCard(width: width) {
                content()
                    .padding(14)
            }
            .background(
                RoundedRectangle(cornerRadius: SheetRadius.panel, style: .continuous)
                    .fill(section.area.map { game.color($0).color } ?? cleverSheetGrey)
            )
        }
    }

    private var tracksContent: some View {
        VStack(spacing: 10) {
            SheetRoundsBar(rounds: 6, darkFrom: 4, cell: 42, ink: cleverInk,
                           crossed: game.state.roundsCrossed,
                           tap: { game.toggleRound($0) }) { r in
                cleverRoundBadge(r, game: game, size: 21)
            }
            SheetCircleTrack(slots: CleverLayout.rerollTrackSlots,
                             used: game.state.rerollUsed,
                             earned: game.rerollsEarned,
                             diameter: 26, ink: cleverInk,
                             icon: { BonusBadge(icon: .reroll, game: game, size: 30) },
                             tap: { game.toggleReroll($0) })
            SheetCircleTrack(slots: CleverLayout.extraDieTrackSlots,
                             used: game.state.extraDieUsed,
                             earned: game.extraDiceEarned,
                             diameter: 26, ink: cleverInk,
                             icon: { BonusBadge(icon: .plusOne, game: game, size: 30) },
                             tap: { game.toggleExtraDie($0) })
        }
        // A definite design width (just past the bars' natural size) so the
        // round tiles and the track circles DISTRIBUTE evenly across their
        // pills instead of hugging the leading edge; the enclosing
        // ScaledSheet/WidthScaledCard scales the block to fit as usual.
        .frame(width: 360)
    }
}

// MARK: - Editor sheet (big, comfortable, paged)

struct CleverEditorSheet: View {
    @ObservedObject var game: CleverGame
    @ObservedObject var diceTheme = DiceTheme.shared
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
                    .opacity(game.canUndo ? 1 : 0.5)
                    .accessibilityLabel("Undo")
            }
        ) { section in
            page(section)
        }
        .background(cleverPaper.ignoresSafeArea())
        .preferredColorScheme(.light)
        .environment(\.colorScheme, .light)
        // Hug the content: the pages are laid out from fixed design constants
        // (cells of 54/56 pt), so the tallest page (yellow: 4 rows + points
        // row + chrome) needs ≈ 500 pt. The sheet covers only that — no more
        // full-screen dead space — with `.large` as an expand option.
        .presentationDetents([.height(520), .large])
        .presentationDragIndicator(.hidden)
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
                        RoundedRectangle(cornerRadius: SheetRadius.panel, style: .continuous)
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
        // The printed sheet's three scratch boxes are pen-and-paper artifacts
        // and are deliberately omitted (owner request) — rounds + tracks only.
        VStack(spacing: 10) {
            SheetRoundsBar(rounds: 6, darkFrom: 4, cell: 42, ink: cleverInk,
                           crossed: game.state.roundsCrossed,
                           tap: { game.toggleRound($0) }) { r in
                cleverRoundBadge(r, game: game, size: 21)
            }
            SheetCircleTrack(slots: CleverLayout.rerollTrackSlots,
                             used: game.state.rerollUsed,
                             earned: game.rerollsEarned,
                             diameter: 26, ink: cleverInk,
                             icon: { BonusBadge(icon: .reroll, game: game, size: 30) },
                             tap: { game.toggleReroll($0) })
            SheetCircleTrack(slots: CleverLayout.extraDieTrackSlots,
                             used: game.state.extraDieUsed,
                             earned: game.extraDiceEarned,
                             diameter: 26, ink: cleverInk,
                             icon: { BonusBadge(icon: .plusOne, game: game, size: 30) },
                             tap: { game.toggleExtraDie($0) })
        }
        // A definite design width (just past the bars' natural size) so the
        // round tiles and the track circles DISTRIBUTE evenly across their
        // pills instead of hugging the leading edge; the enclosing
        // ScaledSheet scales the block to fit as usual.
        .frame(width: 360)
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
            .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: SheetRadius.pill, style: .continuous))
        } else {
            VStack(spacing: 2) {
                Text("🦊 Foxes earned: \(game.foxCount)")
                Text("Foxes score the lowest area (\(game.lowestAreaScore)) each")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: SheetRadius.pill, style: .continuous))
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
            .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: SheetRadius.pill, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SheetRadius.pill, style: .continuous)
                    .strokeBorder(.black.opacity(0.08), lineWidth: SheetStroke.small)
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
    ///
    /// TestFlight bug: confirmationDialog buttons render in the presentation
    /// context's TINT, so the 1–6 option digits picked up whatever colour the
    /// screen behind them was tinted to (an area colour, sometimes near-white
    /// on a light sheet) and became unreadable. `confirmationDialog` reads
    /// the tint from the view it is attached to at presentation time, so a
    /// `.tint(...)` placed here — AFTER (i.e. chained onto the result of)
    /// `confirmationDialog`, overriding whatever `.tint` the screen applied
    /// upstream — reaches the dialog's own buttons with a fixed, high-contrast
    /// colour independent of the screen/dice tint. Never applied to the
    /// screen itself, so the rest of the UI keeps its normal tint.
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
        .tint(cleverInk)
    }
}

// MARK: - Bonus badge (printed bonus circles)

struct BonusBadge: View {
    let icon: BonusIcon
    @ObservedObject var game: CleverGame
    /// Observed so badges recolour with the app-wide dice palette.
    @ObservedObject var diceTheme = DiceTheme.shared
    let size: CGFloat

    var body: some View {
        if case .crossOrSix = icon {
            // Printed as TWO small circles side by side (✗ | 6), split by a
            // thin divider — unlike every other icon, which is one circle.
            // Each sub-circle is sized to fit two-across in the same
            // `size`×`size` slot every other round badge occupies.
            HStack(spacing: size * 0.06) {
                miniCircle { Text("✗").font(.system(size: size * 0.34, weight: .black))
                    .foregroundStyle(.white) }
                Rectangle().fill(.white.opacity(0.6)).frame(width: 1, height: size * 0.5)
                miniCircle { Text("6").font(.system(size: size * 0.34, weight: .black))
                    .foregroundStyle(.white) }
            }
            .frame(width: size, height: size)
        } else {
            ZStack {
                Circle().fill(background)
                Circle().strokeBorder(.white.opacity(0.85), lineWidth: SheetStroke.small)
                content
            }
            .frame(width: size, height: size)
        }
    }

    /// One half of the `.crossOrSix` badge: a small ink circle with its own
    /// thin rim, matching the single-icon badges' styling at half width.
    private func miniCircle<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            Circle().fill(cleverInk)
            Circle().strokeBorder(.white.opacity(0.85), lineWidth: SheetStroke.small)
            content()
        }
        .frame(width: size * 0.47, height: size * 0.47)
    }

    private var background: Color {
        switch icon {
        case .reroll, .plusOne, .fox, .crossOrSix: return cleverInk
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
        case .crossOrSix:
            EmptyView() // handled by `body`'s dedicated two-circle layout
        }
    }
}
