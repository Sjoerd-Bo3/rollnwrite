//
//  Clever2ScorecardView.swift
//  RollnWrite – Clever2
//
//  Interactive "Twice as Clever" scorecard, rebuilt to the Clever v3 concept.
//  Presentation + touch only; all rules and scoring live in `Clever2Game`.
//
//  Layout model (the canonical Clever design, from CleverV3ScorecardView):
//  • DEFAULT ("sheet"): an orientation switch. PORTRAIT is a faithful
//    one-screen MINIATURE of the official printed sheet (Schmidt Spiele art.
//    88234) — header band (rounds bar + the reroll / return / extra-die
//    tracks), silver + yellow side by side, then the blue / green / pink
//    arrow bands, the manual fox stepper and the bottom total strip.
//    Tapping an area's chrome (outside its cells) opens a paged editor.
//    LANDSCAPE reflows the same pieces into two columns at large cell sizes,
//    everything directly tappable — no editor, no totals strip (owner
//    precedent: scoring only matters at game end).
//  • "list": one vertical scrolling list of full-size area cards (inline
//    editing — the owner-approved exception to the no-scroll rule),
//    mirroring Clever 1's `CleverListBoardView`.
//  • Tapping the most-recent mark un-checks it (LIFO undo), as everywhere.
//
//  Sheet-arrangement source: the official rulebook PDF
//  (schmidtspiele.de/files/Retail/72dpi_PNG/88234_Twice_as_clever_GB.pdf),
//  whose page-1 diagram labels the sheet: round track on top, the reroll /
//  return / extra-dice action bars under it, silver area mid-left, yellow
//  area mid-right, then the blue, green and pink bands ("Three areas (blue,
//  green, pink) show an arrow on the left"). The top-left pen-and-paper dice
//  fields are deliberately omitted (Clever 1 precedent: scratch boxes are
//  pen artifacts). Rounds are NOT engine state in Clever 2, so the rounds
//  bar is printed chrome (display-only) — no new persisted state.
//

import SwiftUI

// MARK: - Sheet sections

/// The tappable regions of the sheet — one editor page each. Sheet order:
/// the five areas, then the rounds / action-track header.
enum Clever2SheetSection: String, CaseIterable, Identifiable, Hashable {
    case silver, yellow, blue, green, pink, tracks

    var id: String { rawValue }

    /// The scoring area behind this section (`nil` for the header tracks).
    var area: Clever2Area? { Clever2Area(rawValue: rawValue) }

    /// Localisation KEY for the editor page title.
    var title: String { area?.title ?? "Rounds & bonuses" }
}

// MARK: - Board layout (sheet vs list, mirroring Clever 1)

/// The two board layouts: the v3 sheet (portrait miniature / landscape
/// reflow) versus one vertical scrolling list of full-size areas.
enum Clever2BoardLayout: String {
    case sheet, list
    static let storageKey = "clever2.layout"
}

// MARK: - Scorecard (scaffold wrapper)

public struct Clever2ScorecardView: View {
    @StateObject private var game = Clever2Game()
    let rules: RulesDocument

    @State private var confirmNewGame = false
    @AppStorage(Clever2BoardLayout.storageKey) private var layoutRaw = Clever2BoardLayout.sheet.rawValue

    public init(rules: RulesDocument) {
        self.rules = rules
    }

    private var layout: Clever2BoardLayout { Clever2BoardLayout(rawValue: layoutRaw) ?? .sheet }

    public var body: some View {
        ScorecardScaffold(
            title: "Twice as Clever",
            rules: rules,
            // Both orientations scale to fit — let the screen rotate freely.
            locksLandscape: false,
            board: {
                Group {
                    switch layout {
                    case .sheet: Clever2BoardView(game: game)
                    case .list: Clever2ListBoardView(game: game)
                    }
                }
            },
            headerAccessory: {
                HStack(spacing: 16) {
                    Button {
                        layoutRaw = (layout == .sheet ? Clever2BoardLayout.list : .sheet).rawValue
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
        // Force LIGHT resolution of dynamic colours on the cream paper — same
        // reasoning as `CleverScorecardView` (the app root's outer
        // `.preferredColorScheme` would otherwise win in dark mode).
        .environment(\.colorScheme, .light)
        .tint(Color(red: 0.86, green: 0.28, blue: 0.56))
        .confirmationDialog("Start a new game?", isPresented: $confirmNewGame, titleVisibility: .visible) {
            Button("New game", role: .destructive) { game.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears the scorecard.")
        }
    }
}

// MARK: - Orientation switch (the v3 concept)

/// Landscape → the two-column reflow; portrait → the sheet miniature.
struct Clever2BoardView: View {
    @ObservedObject var game: Clever2Game

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > geo.size.height {
                Clever2LandscapeBoard(game: game)
            } else {
                Clever2SheetBoardView(game: game)
            }
        }
    }
}

// MARK: - Portrait board (the faithful miniature)

struct Clever2SheetBoardView: View {
    @ObservedObject var game: Clever2Game
    /// Observed so an open board recolours when Settings changes the palette.
    @ObservedObject var diceTheme = DiceTheme.shared

    @State private var editorSection: Clever2SheetSection = .silver
    @State private var showEditor = false
    @State private var entry: ValueEntry?

    /// Explicit init: the private `@State`s above make the synthesized
    /// memberwise init non-internal (see `CleverSheetBoardView`).
    init(game: Clever2Game) {
        self.game = game
    }

    // Design-space constants (pre-scale points). The sheet is laid out at a
    // fixed "natural" WIDTH; `ScaledSheet` stretches its heights to consume
    // the available aspect (portrait) and then scales the whole sheet to fit.
    private let sheetW: CGFloat = 580
    /// Inner content width: the sheet width minus its horizontal padding
    /// (2×14) → 552.
    private let innerW: CGFloat = 552
    /// The silver panel's fixed width; yellow takes the rest
    /// (552 − 310 − 10 gap = 232).
    private let silverPanelW: CGFloat = 310
    /// Silver cells: panel content = 310 − 2×10 padding = 290; a row is
    /// 6 cells + 5 gaps of 0.1×cell = 6.5 cell widths → 44 (286 used).
    private let silverCell: CGFloat = 44
    /// Yellow cells: panel content = 232 − 2×10 = 212; the staggered grid is
    /// 4 columns + 3 gaps of 0.1×cell = 4.3 cell widths → 48 (206 used).
    private let yellowCell: CGFloat = 48
    /// Width available to a row band's CELLS: the inner width minus the
    /// band's own padding (2×8), the fixed-width chevron (14) and its
    /// spacing (6) → 516. Cell sizes are derived from it so the last cell
    /// ends flush with the band — no trailing gap.
    private var bandContentW: CGFloat { innerW - 16 - 14 - 6 }
    /// Blue/pink rows: 12 cells + 11 gaps of 0.1×cell = 13.1 cell widths.
    private var blueCell: CGFloat { bandContentW / 13.1 }
    /// Green row: 6 pairs of (2 cells + one "−" separator of 0.24×cell) plus
    /// 5 inter-pair gaps of 0.4×cell = 12 + 1.44 + 2.0 = 15.44 cell widths.
    private var greenCell: CGFloat { bandContentW / 15.44 }

    var body: some View {
        ScaledSheet(maxStretch: 1.6) { stretch in sheet(stretch) }
            .padding(6)
            .overlay(alignment: .top) {
                Clever2BonusBanner(game: game)
                    .padding(.horizontal, 12)
            }
            .sheet(isPresented: $showEditor) {
                Clever2EditorSheet(game: game, selection: $editorSection)
            }
            .cleverValueEntry($entry)
    }

    private func open(_ section: Clever2SheetSection) {
        editorSection = section
        showEditor = true
    }

    // MARK: The sheet

    private func sheet(_ stretch: CGFloat) -> some View {
        VStack(spacing: 10 * stretch) {
            headerBand(stretch)
            HStack(alignment: .top, spacing: 10) {
                panel(.silver, stretch) {
                    Clever2SilverGrid(game: game, cell: silverCell, stretch: stretch)
                }
                .frame(width: silverPanelW)
                panel(.yellow, stretch) {
                    Clever2YellowGrid(game: game, cell: yellowCell, stretch: stretch)
                }
            }
            rowBand(.blue, stretch) {
                Clever2BlueRow(game: game, cell: blueCell, stretch: stretch) { entry = $0 }
            }
            rowBand(.green, stretch) {
                Clever2GreenRow(game: game, cell: greenCell, stretch: stretch) { entry = $0 }
            }
            rowBand(.pink, stretch) {
                Clever2PinkRow(game: game, cell: blueCell, stretch: stretch) { entry = $0 }
            }
            Clever2FoxStepper(game: game, height: 32, stretch: min(stretch, 1.25))
            clever2TotalStrip(game: game, height: 44 * min(stretch, 1.25))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14 * stretch)
        .frame(width: sheetW)
        .background(
            RoundedRectangle(cornerRadius: SheetRadius.card, style: .continuous)
                .fill(cleverSheetGrey)
        )
    }

    // MARK: Header band (rounds + the three action tracks)

    private func headerBand(_ stretch: CGFloat) -> some View {
        Clever2TracksBlock(game: game, roundCell: 30, badgeSize: 16,
                           diameter: 17, iconSize: 21, stretch: stretch)
            .contentShape(Rectangle())
            .onTapGesture { open(.tracks) }
    }

    // MARK: Area containers (tap outside the cells opens the editor)

    private func panel<Content: View>(
        _ section: Clever2SheetSection, _ stretch: CGFloat, @ViewBuilder content: () -> Content
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
        _ section: Clever2SheetSection, _ stretch: CGFloat, @ViewBuilder content: () -> Content
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

// MARK: - Landscape reflow (two columns, everything directly tappable)

struct Clever2LandscapeBoard: View {
    @ObservedObject var game: Clever2Game
    /// Observed so an open board recolours when Settings changes the palette.
    @ObservedObject var diceTheme = DiceTheme.shared
    @State private var entry: ValueEntry?

    // Design-space constants (pre-scale points). Each column is one
    // `ScaledSheet`: laid out at a fixed natural width, stretched vertically
    // toward its slot's aspect, then scaled uniformly to fit.
    private let leftW: CGFloat = 260
    private let rightW: CGFloat = 560
    /// Silver cells: column content = 260 − 2×10 panel padding = 240; a row
    /// is 6.5 cell widths (6 cells + 5 gaps of 0.1×cell) → 36 (234 used).
    private let silverCell: CGFloat = 36
    /// Yellow cells: 4.3 cell widths (4 columns + 3 gaps) into 240 → 52
    /// (223.6 used).
    private let yellowCell: CGFloat = 52
    /// Band cell math as in portrait: 560 − 16 − 14 − 6 = 524 content width.
    private var bandContentW: CGFloat { rightW - 16 - 14 - 6 }
    /// Blue/pink rows: 12 cells + 11 gaps of 0.1×cell = 13.1 cell widths.
    private var blueCell: CGFloat { bandContentW / 13.1 }
    /// Green row: 15.44 cell widths (see the portrait derivation).
    private var greenCell: CGFloat { bandContentW / 15.44 }

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .top, spacing: 10) {
                ScaledSheet(maxStretch: 1.4, anchor: .topLeading) { stretch in leftColumn(stretch) }
                    .frame(width: geo.size.width * 0.30)
                ScaledSheet(maxStretch: 1.6) { stretch in rightColumn(stretch) }
                    .frame(maxWidth: .infinity)
            }
            .padding(12)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: SheetRadius.card, style: .continuous)
                    .fill(cleverSheetGrey)
                    .padding(4)
            )
        }
        .overlay(alignment: .top) {
            Clever2BonusBanner(game: game)
                .padding(.horizontal, 12)
        }
        .cleverValueEntry($entry)
    }

    // MARK: Left column — silver above yellow (the sheet's two grid areas)

    private func leftColumn(_ stretch: CGFloat) -> some View {
        VStack(spacing: 10 * stretch) {
            panel(.silver, stretch) {
                Clever2SilverGrid(game: game, cell: silverCell, stretch: stretch)
            }
            panel(.yellow, stretch) {
                Clever2YellowGrid(game: game, cell: yellowCell, stretch: stretch)
            }
        }
        .frame(width: leftW)
    }

    // MARK: Right column — action tracks + fox, then the three write bands

    private func rightColumn(_ stretch: CGFloat) -> some View {
        VStack(spacing: 10 * stretch) {
            // Compact header strip in place of the printed round track (the
            // rounds bar is display-only chrome here — Clever 2 tracks no
            // round state — so landscape spends the height on the areas).
            HStack(spacing: 10) {
                track(.reroll, slots: Clever2Layout.rerollTrackSlots,
                      used: game.state.rerollUsed, stretch: stretch) { game.toggleReroll($0) }
                track(.returnDie, slots: Clever2Layout.returnTrackSlots,
                      used: game.state.returnUsed, stretch: stretch) { game.toggleReturn($0) }
            }
            HStack(spacing: 10) {
                track(.plusOne, slots: Clever2Layout.extraDieTrackSlots,
                      used: game.state.extraDieUsed, stretch: stretch) { game.toggleExtraDie($0) }
                // The manual fox stepper stays reachable in landscape.
                Clever2FoxStepper(game: game, height: 26, stretch: stretch)
                    .fixedSize()
            }
            rowBand(.blue, stretch) {
                Clever2BlueRow(game: game, cell: blueCell, stretch: stretch) { entry = $0 }
            }
            rowBand(.green, stretch) {
                Clever2GreenRow(game: game, cell: greenCell, stretch: stretch) { entry = $0 }
            }
            rowBand(.pink, stretch) {
                Clever2PinkRow(game: game, cell: blueCell, stretch: stretch) { entry = $0 }
            }
            // No totals strip in landscape (owner call): scoring only matters
            // at game end, and the freed height goes to the three bands.
        }
        .frame(width: rightW)
    }

    private func track(_ icon: Clever2Bonus, slots: Int, used: Set<Int>, stretch: CGFloat,
                       tap: @escaping (Int) -> Void) -> some View {
        SheetCircleTrack(slots: slots, used: used,
                         diameter: 19, ink: cleverInk, stretch: stretch,
                         icon: { Clever2BonusBadge(bonus: icon, game: game, size: 24) },
                         tap: tap)
    }

    // MARK: Area containers (direct interaction — no editor to open)

    private func panel<Content: View>(
        _ area: Clever2Area, _ stretch: CGFloat, @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, 10)
            .padding(.vertical, 10 * stretch)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: SheetRadius.panel, style: .continuous)
                    .fill(game.color(area).color)
            )
    }

    private func rowBand<Content: View>(
        _ area: Clever2Area, _ stretch: CGFloat, @ViewBuilder content: () -> Content
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
                .fill(game.color(area).color)
        )
    }
}

// MARK: - Layout B: one scrolling list of full-size areas

/// The "list" side of the layout choice, mirroring `CleverListBoardView`:
/// every area stacked in ONE vertical scrolling list at full interactive
/// size — inline editing, no modal (owner-approved scroll exception). Uses
/// the SAME area views as the editor pages; each card scales down to the
/// screen width via `WidthScaledCard`.
struct Clever2ListBoardView: View {
    @ObservedObject var game: Clever2Game
    /// Observed so an open board recolours when Settings changes the palette.
    @ObservedObject var diceTheme = DiceTheme.shared
    @State private var entry: ValueEntry?

    var body: some View {
        GeometryReader { geo in
            let cardW = geo.size.width - 24
            ScrollView {
                VStack(spacing: 14) {
                    Clever2BonusBanner(game: game)
                    card(.tracks, width: cardW) { tracksContent }
                    card(.silver, width: cardW) {
                        Clever2SilverGrid(game: game, cell: 48, showRowScores: true)
                    }
                    card(.yellow, width: cardW) {
                        Clever2YellowGrid(game: game, cell: 56, showCounts: true)
                    }
                    card(.blue, width: cardW) {
                        Clever2BlueRow(game: game, cell: 52, split: true) { entry = $0 }
                    }
                    card(.green, width: cardW) {
                        Clever2GreenRow(game: game, cell: 48, split: true) { entry = $0 }
                    }
                    card(.pink, width: cardW) {
                        Clever2PinkRow(game: game, cell: 52, split: true) { entry = $0 }
                    }
                    WidthScaledCard(width: cardW) {
                        clever2TotalStrip(game: game, height: 46)
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
        _ section: Clever2SheetSection, width: CGFloat,
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
            Clever2TracksBlock(game: game, roundCell: 42, badgeSize: 21,
                               diameter: 26, iconSize: 30)
            Clever2FoxStepper(game: game, height: 38)
        }
        // A definite design width (just past the bars' natural size) so the
        // round tiles and the track circles DISTRIBUTE evenly across their
        // pills instead of hugging the leading edge; the enclosing
        // WidthScaledCard scales the block to fit as usual.
        .frame(width: 360)
    }
}

// MARK: - Editor sheet (big, comfortable, paged)

struct Clever2EditorSheet: View {
    @ObservedObject var game: Clever2Game
    @ObservedObject var diceTheme = DiceTheme.shared
    @Binding var selection: Clever2SheetSection

    @State private var entry: ValueEntry?

    var body: some View {
        SheetEditorPager(
            sections: Clever2SheetSection.allCases,
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
        // Hug the content (Clever 1 precedent): the pages are laid out from
        // fixed design constants, so the tallest page (silver: badge row +
        // 4 rows + scale row + chrome) needs ≈ 500 pt.
        .presentationDetents([.height(520), .large])
        .presentationDragIndicator(.hidden)
        .cleverValueEntry($entry)
    }

    private func tint(for section: Clever2SheetSection) -> Color {
        section.area.map { game.color($0).color } ?? Color(white: 0.5)
    }

    private func page(_ section: Clever2SheetSection) -> some View {
        VStack(spacing: 12) {
            Clever2BonusBanner(game: game)
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

    @ViewBuilder private func pageContent(_ section: Clever2SheetSection) -> some View {
        switch section {
        case .silver:
            Clever2SilverGrid(game: game, cell: 48, showRowScores: true)
        case .yellow:
            Clever2YellowGrid(game: game, cell: 56, showCounts: true)
        case .blue:
            Clever2BlueRow(game: game, cell: 52, split: true) { entry = $0 }
        case .green:
            Clever2GreenRow(game: game, cell: 48, split: true) { entry = $0 }
        case .pink:
            Clever2PinkRow(game: game, cell: 52, split: true) { entry = $0 }
        case .tracks:
            tracksContent
        }
    }

    private var tracksContent: some View {
        VStack(spacing: 10) {
            Clever2TracksBlock(game: game, roundCell: 42, badgeSize: 21,
                               diameter: 26, iconSize: 30)
            Clever2FoxStepper(game: game, height: 38)
        }
        // A definite design width so the round tiles and the track circles
        // DISTRIBUTE evenly across their pills (see the list layout).
        .frame(width: 360)
    }

    @ViewBuilder private func footer(_ section: Clever2SheetSection) -> some View {
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
                Text("🦊 Foxes earned: \(game.state.foxes)")
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

// MARK: - Shared chrome pieces

/// The bottom summary strip (per-area scores + foxes + total) — shared by the
/// portrait sheet and the list layout.
@MainActor
func clever2TotalStrip(game: Clever2Game, height: CGFloat) -> some View {
    var entries: [SheetTotalStrip.Entry] = Clever2Area.allCases.map {
        SheetTotalStrip.Entry(value: "\(game.score(for: $0))", tint: game.color($0).color)
    }
    entries.append(SheetTotalStrip.Entry(value: "\(game.foxScore)",
                                         caption: "🦊×\(game.state.foxes)", tint: .red))
    return SheetTotalStrip(entries: entries, total: game.totalScore,
                           ink: cleverInk, height: height)
}

/// The rounds bar + the three action tracks (reroll / return / extra die),
/// shared by the portrait header, the editor's tracks page and the list
/// card. The rounds bar is DISPLAY-ONLY (no `tap`): Clever 2's engine keeps
/// no round state, so the bar is printed chrome; the tracks are live.
struct Clever2TracksBlock: View {
    @ObservedObject var game: Clever2Game
    @ObservedObject var diceTheme = DiceTheme.shared
    var roundCell: CGFloat = 30
    var badgeSize: CGFloat = 16
    var diameter: CGFloat = 17
    var iconSize: CGFloat = 21
    /// Vertical stretch — multiplies tile heights and vertical paddings only.
    var stretch: CGFloat = 1

    var body: some View {
        VStack(spacing: 6 * stretch) {
            SheetRoundsBar(rounds: 6, darkFrom: 4, cell: roundCell,
                           ink: cleverInk, stretch: stretch) { r in
                clever2RoundBadge(r, game: game, size: badgeSize)
            }
            SheetCircleTrack(slots: Clever2Layout.rerollTrackSlots,
                             used: game.state.rerollUsed,
                             diameter: diameter, ink: cleverInk, stretch: stretch,
                             icon: { Clever2BonusBadge(bonus: .reroll, game: game, size: iconSize) },
                             tap: { game.toggleReroll($0) })
            SheetCircleTrack(slots: Clever2Layout.returnTrackSlots,
                             used: game.state.returnUsed,
                             diameter: diameter, ink: cleverInk, stretch: stretch,
                             icon: { Clever2BonusBadge(bonus: .returnDie, game: game, size: iconSize) },
                             tap: { game.toggleReturn($0) })
            SheetCircleTrack(slots: Clever2Layout.extraDieTrackSlots,
                             used: game.state.extraDieUsed,
                             diameter: diameter, ink: cleverInk, stretch: stretch,
                             icon: { Clever2BonusBadge(bonus: .plusOne, game: game, size: iconSize) },
                             tap: { game.toggleExtraDie($0) })
        }
    }
}

/// The badge under a round number: the printed start-of-round bonus for
/// rounds 1–3 (`Clever2Layout.roundBonuses`), the printed "?" free-choice
/// bonus for round 4 (rulebook: "At the beginning of round 4, every player
/// can freely choose a color for the black ?"), and player-count end markers
/// for rounds 5–6 (3 players → 5 rounds; 1–2 players → 6 rounds). Every
/// branch fills the identical `size`×`size` box so round tiles keep equal
/// heights.
@MainActor
func clever2RoundBadge(_ round: Int, game: Clever2Game, size: CGFloat) -> some View {
    Group {
        if let bonus = Clever2Layout.roundBonuses[round] {
            Clever2BonusBadge(bonus: bonus, game: game, size: size)
        } else if round == 3 {
            ZStack {
                Circle().fill(cleverInk)
                Circle().strokeBorder(.white.opacity(0.85), lineWidth: SheetStroke.small)
                Text("?")
                    .font(.system(size: size * 0.55, weight: .black))
                    .foregroundStyle(.white)
            }
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

/// The manual fox stepper: Clever 2's fox triggers are spread across many
/// area completions, so foxes are counted BY THE PLAYER (engine design) —
/// unlike Clever 1's auto-detection. Rendered in the sheet idiom (grey pill,
/// ink glyphs) so it sits naturally between the pink band and the totals.
struct Clever2FoxStepper: View {
    @ObservedObject var game: Clever2Game
    var height: CGFloat = 32
    /// Vertical stretch — multiplies the pill's vertical padding only.
    var stretch: CGFloat = 1

    var body: some View {
        HStack(spacing: height * 0.3) {
            Text("🦊")
                .font(.system(size: height * 0.62))
            Text("×\(game.state.foxes)")
                .font(.system(size: height * 0.46, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(cleverInk)
                .contentTransition(.numericText())
            Text("= \(game.foxScore)")
                .font(.system(size: height * 0.38, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(cleverInk.opacity(0.6))
                .contentTransition(.numericText())
            Spacer(minLength: height * 0.2)
            Button { game.removeFox() } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: height * 0.7))
            }
            .buttonStyle(.plain)
            .foregroundStyle(cleverInk)
            .disabled(game.state.foxes == 0)
            .opacity(game.state.foxes == 0 ? 0.35 : 1)
            .accessibilityLabel("Remove fox")
            Button { game.addFox() } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: height * 0.7))
            }
            .buttonStyle(.plain)
            .foregroundStyle(cleverInk)
            .accessibilityLabel("Add fox")
        }
        .padding(.horizontal, height * 0.35)
        .padding(.vertical, height * 0.2 * stretch)
        .background(
            RoundedRectangle(cornerRadius: SheetRadius.pill, style: .continuous)
                .fill(Color(white: 0.62))
        )
        .animation(.snappy, value: game.state.foxes)
    }
}

// MARK: - Silver area (4 colour rows × 6, column bonuses, per-marks scale)

struct Clever2SilverGrid: View {
    @ObservedObject var game: Clever2Game
    @ObservedObject var diceTheme = DiceTheme.shared
    let cell: CGFloat
    /// Show each row's live score at its trailing edge (editor/list pages).
    var showRowScores = false
    /// Vertical stretch — multiplies cell heights and vertical gaps only.
    var stretch: CGFloat = 1

    private var gap: CGFloat { cell * 0.1 }
    /// Width of the trailing per-row score column (editor/list only).
    private var scoreW: CGFloat { cell * 0.8 }

    var body: some View {
        VStack(spacing: gap * stretch) {
            columnBonusRow
            ForEach(0..<Clever2Layout.silverRowAreas.count, id: \.self) { r in
                row(r)
            }
            scaleRow
        }
    }

    /// The printed bonuses above the columns — earned when a whole column
    /// (all four colour rows) is crossed.
    private var columnBonusRow: some View {
        HStack(spacing: gap) {
            ForEach(0..<Clever2Layout.silverCols, id: \.self) { c in
                Clever2BonusBadge(bonus: Clever2Layout.silverColumnBonus[c],
                                  game: game, size: cell * 0.6)
                    .frame(width: cell)
            }
            if showRowScores { Color.clear.frame(width: scoreW, height: 1) }
        }
        .padding(.vertical, cell * 0.05)
        .background(Capsule().fill(.white.opacity(0.35)))
    }

    private func row(_ r: Int) -> some View {
        let rowTint = game.color(Clever2Layout.silverRowAreas[r])
        return HStack(spacing: gap) {
            ForEach(0..<Clever2Layout.silverCols, id: \.self) { c in
                let idx = r * Clever2Layout.silverCols + c
                let crossed = game.state.silver.contains(idx)
                let undoable = crossed && game.isLastSilver(idx)
                SheetCell(
                    label: "\(c + 1)",
                    tint: rowTint.color,
                    ink: cleverInk,
                    marked: crossed,
                    legal: game.canCrossSilver(idx),
                    undoable: undoable,
                    size: cell,
                    height: cell * stretch
                ) {
                    if undoable { game.undo() } else { game.crossSilver(idx) }
                }
            }
            if showRowScores {
                Text("\(Clever2Layout.silverRowScale[game.silverMarks(inRow: r)])")
                    .font(.system(size: cell * 0.34, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(cleverInk)
                    .contentTransition(.numericText())
                    .frame(width: scoreW)
            }
        }
    }

    /// The printed per-marks points scale under the grid (grey stars on the
    /// sheet: 1…6 marks in a row → 2/4/7/11/16/22). A value lights up while
    /// some row currently sits at that count.
    private var scaleRow: some View {
        let counts = Set((0..<Clever2Layout.silverRowAreas.count).map { game.silverMarks(inRow: $0) })
        return HStack(spacing: gap) {
            ForEach(0..<Clever2Layout.silverCols, id: \.self) { i in
                SheetPointsBadge(value: Clever2Layout.silverRowScale[i + 1],
                                 tint: game.color(.silver).color,
                                 size: cell * 0.55,
                                 highlighted: counts.contains(i + 1))
                    .frame(width: cell)
            }
            if showRowScores { Color.clear.frame(width: scoreW, height: 1) }
        }
        .padding(.vertical, cell * 0.05)
        .background(Capsule().fill(.white.opacity(0.4)))
    }
}

// MARK: - Yellow area (staggered columns, circle → cross, points scale)

struct Clever2YellowGrid: View {
    @ObservedObject var game: Clever2Game
    @ObservedObject var diceTheme = DiceTheme.shared
    let cell: CGFloat
    /// Show the cross-count under each scale badge (editor/list pages).
    var showCounts = false
    /// Vertical stretch — multiplies cell heights and vertical gaps only.
    var stretch: CGFloat = 1

    private var gap: CGFloat { cell * 0.1 }
    /// First flat index of each staggered column (columns are 2/3/2/3 tall).
    private var columnStarts: [Int] {
        var starts: [Int] = []
        var acc = 0
        for col in Clever2Layout.yellowColumns {
            starts.append(acc)
            acc += col.count
        }
        return starts
    }

    var body: some View {
        let tint = game.color(.yellow)
        VStack(spacing: cell * 0.16 * stretch) {
            scaleRow(tint)
            // Centre-aligned columns give the printed staggered/diamond look
            // (the 2-cell columns sit between the 3-cell columns' rows).
            HStack(alignment: .center, spacing: gap) {
                ForEach(0..<Clever2Layout.yellowColumns.count, id: \.self) { col in
                    VStack(spacing: gap * stretch) {
                        ForEach(0..<Clever2Layout.yellowColumns[col].count, id: \.self) { r in
                            yellowCell(index: columnStarts[col] + r,
                                       value: Clever2Layout.yellowColumns[col][r],
                                       tint: tint)
                        }
                    }
                }
            }
        }
    }

    /// The printed points scale above the grid (1…10 crosses →
    /// 3/10/21/36/55/75/96/118/141/165); the current count lights up.
    private func scaleRow(_ tint: DiceColor) -> some View {
        let count = game.yellowCrossedCount
        return HStack(spacing: -2) {
            ForEach(1...10, id: \.self) { i in
                VStack(spacing: 0) {
                    SheetPointsBadge(value: Clever2Layout.yellowScale[i],
                                     tint: tint.color, size: cell * 0.36, highlighted: i == count)
                    if showCounts {
                        Text("\(i)")
                            .font(.system(size: cell * 0.16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, cell * 0.05)
        .padding(.horizontal, cell * 0.06)
        .background(
            RoundedRectangle(cornerRadius: SheetRadius.pill, style: .continuous)
                .fill(.black.opacity(0.32))
        )
    }

    private func yellowCell(index: Int, value: Int, tint: DiceColor) -> some View {
        let mark = game.yellowState(index)
        let undoable = mark != .empty && game.isLastYellow(index)
        return Clever2YellowCell(
            label: "\(value)",
            tint: tint.color,
            ink: cleverInk,
            mark: mark,
            legal: game.canAdvanceYellow(index),
            undoable: undoable,
            size: cell,
            height: cell * stretch
        ) {
            if undoable { game.undo() } else { game.advanceYellow(index) }
        }
    }
}

/// Yellow's circle-then-cross cell in the `SheetCell` visual idiom: white
/// tile, tint label, ink marks, 0.2×cell radius. First tap draws the pen
/// CIRCLE around the number; the second the ink ✗ (the circle stays, as on
/// the real sheet). Disabled taps pass through like `SheetCell`.
struct Clever2YellowCell: View {
    let label: String
    let tint: Color
    var ink: Color = .black
    let mark: YellowMark
    let legal: Bool
    var undoable: Bool = false
    let size: CGFloat
    /// Cell height; defaults to `size` (square). See `SheetCell.height`.
    var height: CGFloat? = nil
    let onTap: () -> Void

    private var h: CGFloat { height ?? size }
    /// Font reference matching `SheetCell`: width, stepped up modestly
    /// (capped) as the cell stretches taller.
    private var fontBase: CGFloat { size * min(1 + 0.35 * (max(h / size, 1) - 1), 1.25) }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .fill(Color.white)
                Text(label)
                    .font(.system(size: fontBase * 0.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                if mark != .empty {
                    // The pen circle around the number (stays under the ✗).
                    Circle()
                        .strokeBorder(ink.opacity(0.88), lineWidth: SheetStroke.medium)
                        .padding(size * 0.09)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
                if mark == .crossed {
                    Image(systemName: "xmark")
                        .font(.system(size: fontBase * 0.6, weight: .black))
                        .foregroundStyle(ink.opacity(0.88))
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .frame(width: size, height: h)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .strokeBorder(ink, lineWidth: undoable ? SheetStroke.medium : 0)
            )
            .animation(.spring(response: 0.26, dampingFraction: 0.6), value: mark)
        }
        .buttonStyle(.plain)
        .disabled(!(legal || undoable))
        .opacity(mark != .empty || legal || undoable ? 1 : 0.55)
        .accessibilityLabel(label)
        .accessibilityValue(mark == .crossed ? "marked" : (mark == .circled ? "circled" : "available"))
        .accessibilityHint(undoable ? "Tap to undo" : "")
    }
}

// MARK: - Blue row (write 2–12 descending-or-equal, points scale above)

struct Clever2BlueRow: View {
    @ObservedObject var game: Clever2Game
    @ObservedObject var diceTheme = DiceTheme.shared
    let cell: CGFloat
    /// Wrap into two lines (6 + 6) — used by the big editor/list pages.
    var split = false
    /// Vertical stretch — multiplies cell heights and vertical gaps only.
    var stretch: CGFloat = 1
    let requestEntry: (ValueEntry) -> Void

    var body: some View {
        let tint = game.color(.blue)
        Group {
            if split {
                VStack(alignment: .leading, spacing: cell * 0.3) {
                    segment(0..<6, tint: tint)
                    segment(6..<12, tint: tint)
                }
            } else {
                segment(0..<Clever2Layout.blueCount, tint: tint)
            }
        }
    }

    private func segment(_ range: Range<Int>, tint: DiceColor) -> some View {
        HStack(alignment: .top, spacing: cell * 0.1) {
            ForEach(range, id: \.self) { i in
                let undoable = game.isLastBlue(i)
                VStack(spacing: cell * 0.06 * stretch) {
                    // The printed scale seal above each box ("the white number
                    // in the star above the last filled box" is the score).
                    SheetPointsBadge(value: Clever2Layout.blueScale[i + 1],
                                     tint: tint.color, size: cell * 0.56,
                                     highlighted: i == game.blueFilledCount - 1)
                    SheetWriteCell(
                        value: game.state.blue[i],
                        tint: tint.color,
                        ink: cleverInk,
                        isNext: game.blueNextIndex == i,
                        undoable: undoable,
                        size: cell,
                        height: cell * stretch
                    ) {
                        if undoable {
                            game.undo()
                        } else {
                            requestEntry(ValueEntry(title: "Blue sum (≤ previous)",
                                                    allowed: game.allowedBlueValues()) {
                                game.fillBlue($0)
                            })
                        }
                    }
                    clever2BonusSlot(Clever2Layout.blueBonus[i], game: game, size: cell * 0.6)
                }
            }
        }
    }
}

// MARK: - Green row (6 pairs, die × multiplier, pair scores first − second)

struct Clever2GreenRow: View {
    @ObservedObject var game: Clever2Game
    @ObservedObject var diceTheme = DiceTheme.shared
    let cell: CGFloat
    /// Wrap into two lines (3 + 3 pairs) — used by the big editor/list pages.
    var split = false
    /// Vertical stretch — multiplies cell heights and vertical gaps only.
    var stretch: CGFloat = 1
    let requestEntry: (ValueEntry) -> Void

    var body: some View {
        let tint = game.color(.green)
        Group {
            if split {
                VStack(alignment: .leading, spacing: cell * 0.3) {
                    segment(0..<3, tint: tint)
                    segment(3..<6, tint: tint)
                }
            } else {
                segment(0..<6, tint: tint)
            }
        }
    }

    private func segment(_ pairs: Range<Int>, tint: DiceColor) -> some View {
        HStack(alignment: .top, spacing: cell * 0.4) {
            ForEach(pairs, id: \.self) { p in
                pairView(p, tint: tint)
            }
        }
    }

    private func pairView(_ pair: Int, tint: DiceColor) -> some View {
        VStack(spacing: cell * 0.06 * stretch) {
            resultSeal(pair, tint: tint)
            HStack(alignment: .top, spacing: 0) {
                member(pair * 2, tint: tint)
                // The printed "first − second" minus between the pair cells.
                Text("−")
                    .font(.system(size: cell * 0.4, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: cell * 0.24, height: cell * stretch)
                member(pair * 2 + 1, tint: tint)
            }
        }
    }

    /// The green star above each pair: the pair's live result once both
    /// cells are written, an empty printed seal until then.
    @ViewBuilder private func resultSeal(_ pair: Int, tint: DiceColor) -> some View {
        if let a = game.greenWritten(pair * 2), let b = game.greenWritten(pair * 2 + 1) {
            SheetPointsBadge(value: a - b, tint: tint.color,
                             size: cell * 0.56, highlighted: true)
        } else {
            Image(systemName: "seal.fill")
                .font(.system(size: cell * 0.56, weight: .black))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: cell * 0.56 * 1.15, height: cell * 0.56 * 1.15)
        }
    }

    private func member(_ i: Int, tint: DiceColor) -> some View {
        let mult = Clever2Layout.greenMultipliers[i]
        let undoable = game.isLastGreen(i)
        return VStack(spacing: cell * 0.06 * stretch) {
            SheetWriteCell(
                value: game.greenWritten(i),
                hint: "×\(mult)",
                tint: tint.color,
                ink: cleverInk,
                isNext: game.greenNextIndex == i,
                undoable: undoable,
                size: cell,
                height: cell * stretch
            ) {
                if undoable {
                    game.undo()
                } else {
                    requestEntry(ValueEntry(title: "Green die value",
                                            allowed: game.allowedGreenValues()) {
                        game.fillGreen($0)
                    })
                }
            }
            clever2BonusSlot(Clever2Layout.greenBonus[i], game: game, size: cell * 0.6)
        }
    }
}

// MARK: - Pink row (write any die value, sum; thresholds gate bonuses)

struct Clever2PinkRow: View {
    @ObservedObject var game: Clever2Game
    @ObservedObject var diceTheme = DiceTheme.shared
    let cell: CGFloat
    /// Wrap into two lines (6 + 6) — used by the big editor/list pages.
    var split = false
    /// Vertical stretch — multiplies cell heights and vertical gaps only.
    var stretch: CGFloat = 1
    let requestEntry: (ValueEntry) -> Void

    var body: some View {
        let tint = game.color(.pink)
        Group {
            if split {
                VStack(alignment: .leading, spacing: cell * 0.3) {
                    segment(0..<6, tint: tint)
                    segment(6..<12, tint: tint)
                }
            } else {
                segment(0..<12, tint: tint)
            }
        }
    }

    private func segment(_ range: Range<Int>, tint: DiceColor) -> some View {
        HStack(alignment: .top, spacing: cell * 0.1) {
            ForEach(range, id: \.self) { i in
                let undoable = game.isLastPink(i)
                VStack(spacing: cell * 0.06 * stretch) {
                    SheetWriteCell(
                        value: game.state.pink[i],
                        // The printed "≥n" minimum that gates this box's bonus.
                        hint: Clever2Layout.pinkThresholds[i].map { "≥\($0)" },
                        tint: tint.color,
                        ink: cleverInk,
                        isNext: game.pinkNextIndex == i,
                        undoable: undoable,
                        size: cell,
                        height: cell * stretch
                    ) {
                        if undoable {
                            game.undo()
                        } else {
                            requestEntry(ValueEntry(title: "Pink die value",
                                                    allowed: game.allowedPinkValues()) {
                                game.fillPink($0)
                            })
                        }
                    }
                    clever2BonusSlot(Clever2Layout.pinkBonus[i], game: game, size: cell * 0.6)
                }
            }
        }
    }
}

// MARK: - Earned-bonus banner

/// Advisories for bonuses the player must act on themselves (dice actions,
/// free marks, foxes). Clever 2 counterpart of `CleverBonusBanner` (which is
/// bound to `CleverGame` and cannot be reused) — identical look.
struct Clever2BonusBanner: View {
    @ObservedObject var game: Clever2Game

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

// MARK: - Bonus badge (printed bonus circles)

/// Clever 2 counterpart of Clever 1's `BonusBadge` (which takes a
/// `CleverGame` and cannot be reused) — identical look: ink or area-coloured
/// circle with a hairline white rim.
struct Clever2BonusBadge: View {
    let bonus: Clever2Bonus
    @ObservedObject var game: Clever2Game
    /// Observed so badges recolour with the app-wide dice palette.
    @ObservedObject var diceTheme = DiceTheme.shared
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(background)
            Circle().strokeBorder(.white.opacity(0.85), lineWidth: SheetStroke.small)
            content
        }
        .frame(width: size, height: size)
    }

    private var background: Color {
        switch bonus {
        case .reroll, .returnDie, .plusOne, .fox: return cleverInk
        case let .mark(area): return game.color(area).color
        case let .number(area, _): return game.color(area).color
        }
    }

    @ViewBuilder private var content: some View {
        switch bonus {
        case .reroll:
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(.white)
        case .returnDie:
            Image(systemName: "arrow.uturn.left")
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

/// A fixed-size slot for a printed bonus icon (keeps columns aligned when a
/// cell has no bonus).
@MainActor @ViewBuilder
func clever2BonusSlot(_ bonus: Clever2Bonus?, game: Clever2Game, size: CGFloat) -> some View {
    if let bonus {
        Clever2BonusBadge(bonus: bonus, game: game, size: size)
    } else {
        Color.clear.frame(width: size, height: size)
    }
}
