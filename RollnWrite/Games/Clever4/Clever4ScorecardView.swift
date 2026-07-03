//
//  Clever4ScorecardView.swift
//  RollnWrite – Clever4
//
//  Interactive "Clever 4ever" scorecard, rebuilt to the canonical Clever "v3"
//  concept. Presentation + touch only; all rules and scoring live in
//  `Clever4Game`.
//
//  Layout model (mirrors `CleverV3ScorecardView` + `CleverScorecardView`):
//  • DEFAULT (sheet): an orientation switch. Portrait shows a faithful
//    one-screen MINIATURE of the printed sheet (art. 49424) — rounds bar +
//    fox stepper, yellow beside blue, then the full-width grey / green / pink
//    bands and the total strip; tapping an area's chrome opens a paged editor
//    (`SheetEditorPager`) with one big page per area. Landscape reflows the
//    same pieces into two directly-tappable columns filling the screen —
//    no editor, no totals strip (owner precedent).
//  • LIST: one vertical scrolling list of full-size area cards (inline
//    editing — the owner-approved exception to the no-scroll rule), exactly
//    like Clever 1's list layout.
//  • Tap-to-undo rides the engine's per-row "clear last" operations (yellow
//    rows, green triangles, pink); blue/grey cells toggle freely.
//
//  Area pieces live in `Clever4SheetPieces.swift`.
//

import SwiftUI

// MARK: - Sheet sections

/// The tappable regions of the sheet — one editor page each. Sheet order:
/// the five areas, then the rounds / foxes header extras.
enum Clever4SheetSection: String, CaseIterable, Identifiable, Hashable {
    case yellow, blue, grey, green, pink, extras

    var id: String { rawValue }

    /// The scoring area behind this section (`nil` for the header extras).
    var area: Clever4Area? { Clever4Area(rawValue: rawValue) }

    /// Localisation KEY for the editor page title.
    var title: String { area?.title ?? "Rounds & foxes" }
}

// MARK: - Board layout (sheet default / scrolling list option)

/// The two board layouts, mirroring Clever 1's `CleverBoardLayout`: the
/// faithful sheet miniature with the v3 landscape reflow (default) versus one
/// vertical scrolling list of full-size areas.
enum Clever4BoardLayout: String {
    case sheet, list
    static let storageKey = "clever4.layout"
}

// MARK: - Scorecard (scaffold wrapper)

public struct Clever4ScorecardView: View {
    @StateObject private var game = Clever4Game()
    let rules: RulesDocument

    @State private var confirmNewGame = false
    @AppStorage(Clever4BoardLayout.storageKey) private var layoutRaw = Clever4BoardLayout.sheet.rawValue

    public init(rules: RulesDocument) {
        self.rules = rules
    }

    private var layout: Clever4BoardLayout { Clever4BoardLayout(rawValue: layoutRaw) ?? .sheet }

    public var body: some View {
        ScorecardScaffold(
            title: "Clever 4ever",
            rules: rules,
            // Both orientations scale to fit — let the screen rotate freely.
            locksLandscape: false,
            board: {
                Group {
                    switch layout {
                    case .sheet: Clever4BoardView(game: game)
                    case .list: Clever4ListBoardView(game: game)
                    }
                }
            },
            headerAccessory: {
                HStack(spacing: 16) {
                    Button {
                        layoutRaw = (layout == .sheet ? Clever4BoardLayout.list : .sheet).rawValue
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

// MARK: - Orientation switch

/// Landscape → the two-column reflow; portrait → the sheet miniature.
struct Clever4BoardView: View {
    @ObservedObject var game: Clever4Game

    init(game: Clever4Game) {
        self.game = game
    }

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > geo.size.height {
                Clever4LandscapeBoard(game: game)
            } else {
                Clever4SheetBoardView(game: game)
            }
        }
    }
}

// MARK: - Portrait board (the faithful miniature)

struct Clever4SheetBoardView: View {
    @ObservedObject var game: Clever4Game
    /// Observed so an open board recolours when Settings changes the palette.
    @ObservedObject var diceTheme = DiceTheme.shared

    @State private var editorSection: Clever4SheetSection = .yellow
    @State private var showEditor = false
    @State private var entry: ValueEntry?

    /// Explicit init: the private `@State`s above make the synthesized
    /// memberwise init non-internal.
    init(game: Clever4Game) {
        self.game = game
    }

    // Design-space constants (pre-scale points). The sheet is laid out at a
    // fixed "natural" WIDTH; `ScaledSheet` stretches its heights to consume
    // the available aspect (portrait) and then scales the whole sheet to fit.
    // 640 (vs Clever 1's 580) because Clever 4ever is the densest sheet in
    // the family — the grey band alone is 16 columns — and the extra design
    // width keeps every derived cell ≥ ~33 pt before scaling.
    private let sheetW: CGFloat = 640
    /// Yellow/blue panels sit side by side: (sheet 640 − 2×14 sheet padding
    /// − 10 gap) / 2 = 301 per panel; minus the panel's own 2×10 padding
    /// = 281 of content width each.
    private var panelContentW: CGFloat { (sheetW - 28 - 10) / 2 - 20 }
    /// Yellow: 14 (arrow) + 5×(0.22c sign + c cell) + 0.95c seal slot
    /// + 6 gaps of 0.1c  ⇒  14 + 7.65c = panelContentW  ⇒  c ≈ 34.9.
    private var yellowCell: CGFloat { (panelContentW - 14) / 7.65 }
    /// Blue: c label + 6c cells + 0.9c badge slot + 7 gaps of 0.1c
    /// ⇒ 8.6c = panelContentW  ⇒  c ≈ 32.7.
    private var blueCell: CGFloat { panelContentW / 8.6 }
    /// Grey band spans the full sheet: content = 640 − 28 − 2×8 band padding
    /// = 596; 16 cells + 15 gaps of 0.1c = 17.5c  ⇒  c ≈ 34.
    private var greyCell: CGFloat { (sheetW - 28 - 16) / 17.5 }
    /// Green/pink row bands: content = 640 − 28 − 2×8 padding − 14 chevron
    /// − 6 spacing = 576.
    private var bandContentW: CGFloat { sheetW - 28 - 16 - 14 - 6 }
    /// Green: 11 cells + 10 gaps of 0.1c = 12c  ⇒  c = 48.
    private var greenCell: CGFloat { bandContentW / 12 }
    /// Pink: 12 cells + 11 gaps of 0.1c = 13.1c  ⇒  c ≈ 44.
    private var pinkCell: CGFloat { bandContentW / 13.1 }

    var body: some View {
        ScaledSheet(maxStretch: 1.6) { stretch in sheet(stretch) }
            .padding(6)
            .overlay(alignment: .top) {
                C4BonusBanner(game: game)
                    .padding(.horizontal, 12)
            }
            .sheet(isPresented: $showEditor) {
                Clever4EditorSheet(game: game, selection: $editorSection)
            }
            .cleverValueEntry($entry)
    }

    private func open(_ section: Clever4SheetSection) {
        editorSection = section
        showEditor = true
    }

    // MARK: The sheet

    private func sheet(_ stretch: CGFloat) -> some View {
        VStack(spacing: 10 * stretch) {
            headerBand(stretch)
            HStack(alignment: .top, spacing: 10) {
                panel(.yellow, stretch) {
                    C4YellowPanel(game: game, cell: yellowCell, stretch: stretch) { entry = $0 }
                }
                panel(.blue, stretch) {
                    C4BluePanel(game: game, cell: blueCell, stretch: stretch)
                }
            }
            greyBand(stretch)
            rowBand(.green, stretch) {
                C4GreenBand(game: game, cell: greenCell, stretch: stretch) { entry = $0 }
            }
            rowBand(.pink, stretch) {
                C4PinkBand(game: game, cell: pinkCell, stretch: stretch) { entry = $0 }
            }
            clever4TotalStrip(game: game, height: 44 * min(stretch, 1.25))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14 * stretch)
        .frame(width: sheetW)
        .background(
            RoundedRectangle(cornerRadius: SheetRadius.card, style: .continuous)
                .fill(cleverSheetGrey)
        )
    }

    // MARK: Header band (rounds + fox stepper)

    /// The printed round track (bonuses under rounds 1–4, player-count
    /// markers under 5–6). `Clever4Game` keeps no round/track state, so the
    /// bar is display-only reference chrome; the fox stepper beside it is the
    /// one live header control.
    private func headerBand(_ stretch: CGFloat) -> some View {
        HStack(spacing: 10) {
            SheetRoundsBar(rounds: 6, darkFrom: 4, cell: 30, ink: cleverInk,
                           stretch: stretch) { r in
                c4RoundBadge(r, game: game, size: 16)
            }
            C4FoxStepper(game: game, diameter: 20, stretch: stretch)
        }
        .contentShape(Rectangle())
        .onTapGesture { open(.extras) }
    }

    // MARK: Area containers (tap outside the cells opens the editor)

    private func panel<Content: View>(
        _ section: Clever4SheetSection, _ stretch: CGFloat, @ViewBuilder content: () -> Content
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

    /// The grey band has no leading chevron on the printed sheet (crossing
    /// starts anywhere inside a region), so it gets its own full-width
    /// container instead of `rowBand`.
    private func greyBand(_ stretch: CGFloat) -> some View {
        C4GreyPanel(game: game, cell: greyCell, stretch: stretch)
            .padding(.horizontal, 8)
            .padding(.vertical, 8 * stretch)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: SheetRadius.panel, style: .continuous)
                    .fill(game.color(.grey).color)
            )
            .contentShape(RoundedRectangle(cornerRadius: SheetRadius.panel, style: .continuous))
            .onTapGesture { open(.grey) }
    }

    private func rowBand<Content: View>(
        _ section: Clever4SheetSection, _ stretch: CGFloat, @ViewBuilder content: () -> Content
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

struct Clever4LandscapeBoard: View {
    @ObservedObject var game: Clever4Game
    /// Observed so an open board recolours when Settings changes the palette.
    @ObservedObject var diceTheme = DiceTheme.shared

    @State private var entry: ValueEntry?

    /// Explicit init: the private `@State` above makes the synthesized
    /// memberwise init non-internal.
    init(game: Clever4Game) {
        self.game = game
    }

    // Design-space constants (pre-scale points). Each column is laid out at a
    // fixed natural width; its `ScaledSheet` stretches heights toward the
    // slot's aspect and then scales the whole piece uniformly to fit.
    private let leftW: CGFloat = 300
    private let rightW: CGFloat = 640
    /// Left panels: 300 − 2×10 panel padding = 280 of content width.
    private var leftContentW: CGFloat { leftW - 20 }
    /// Yellow: 14 + 7.65c = 280  ⇒  c ≈ 34.8 (same derivation as portrait).
    private var yellowCell: CGFloat { (leftContentW - 14) / 7.65 }
    /// Blue: 8.6c = 280  ⇒  c ≈ 32.6.
    private var blueCell: CGFloat { leftContentW / 8.6 }
    /// Grey: 640 − 2×8 band padding = 624; 17.5c  ⇒  c ≈ 35.7.
    private var greyCell: CGFloat { (rightW - 16) / 17.5 }
    /// Green/pink bands: 640 − 16 − 14 chevron − 6 spacing = 604.
    private var bandContentW: CGFloat { rightW - 16 - 14 - 6 }
    /// Green: 12c  ⇒  c ≈ 50.
    private var greenCell: CGFloat { bandContentW / 12 }
    /// Pink: 13.1c  ⇒  c ≈ 46.
    private var pinkCell: CGFloat { bandContentW / 13.1 }

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .top, spacing: 10) {
                // Leading-anchored: width slack (when the fit is height-bound)
                // lands between the columns, keeping the outer margin tight.
                ScaledSheet(maxStretch: 1.4, anchor: .topLeading) { stretch in leftColumn(stretch) }
                    .frame(width: geo.size.width * 0.32)
                ScaledSheet(maxStretch: 1.5) { stretch in rightColumn(stretch) }
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
            C4BonusBanner(game: game)
                .padding(.horizontal, 12)
        }
        .cleverValueEntry($entry)
    }

    // MARK: Left column — yellow above blue

    private func leftColumn(_ stretch: CGFloat) -> some View {
        VStack(spacing: 10 * stretch) {
            panel(.yellow, stretch) {
                C4YellowPanel(game: game, cell: yellowCell, stretch: stretch) { entry = $0 }
            }
            panel(.blue, stretch) {
                C4BluePanel(game: game, cell: blueCell, stretch: stretch)
            }
        }
        .frame(width: leftW)
    }

    // MARK: Right column — rounds/fox strip, then the three big bands

    private func rightColumn(_ stretch: CGFloat) -> some View {
        VStack(spacing: 10 * stretch) {
            // Compact header strip: the display-only round track plus the fox
            // stepper — the stepper stays reachable in landscape here.
            HStack(spacing: 10) {
                SheetRoundsBar(rounds: 6, darkFrom: 4, cell: 26, ink: cleverInk,
                               stretch: stretch) { r in
                    c4RoundBadge(r, game: game, size: 15)
                }
                C4FoxStepper(game: game, diameter: 19, stretch: stretch)
            }
            greyBand(stretch)
            rowBand(.green, stretch) {
                C4GreenBand(game: game, cell: greenCell, stretch: stretch) { entry = $0 }
            }
            rowBand(.pink, stretch) {
                C4PinkBand(game: game, cell: pinkCell, stretch: stretch) { entry = $0 }
            }
            // No totals strip in landscape (owner precedent): scoring only
            // matters at game end, and the freed height goes to the bands.
        }
        .frame(width: rightW)
    }

    // MARK: Area containers (direct interaction — no editor to open)

    private func panel<Content: View>(
        _ area: Clever4Area, _ stretch: CGFloat, @ViewBuilder content: () -> Content
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

    private func greyBand(_ stretch: CGFloat) -> some View {
        C4GreyPanel(game: game, cell: greyCell, stretch: stretch)
            .padding(.horizontal, 8)
            .padding(.vertical, 8 * stretch)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: SheetRadius.panel, style: .continuous)
                    .fill(game.color(.grey).color)
            )
    }

    private func rowBand<Content: View>(
        _ area: Clever4Area, _ stretch: CGFloat, @ViewBuilder content: () -> Content
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

// MARK: - List layout: one scrolling list of full-size areas

/// The "list" side of the layout toggle, mirroring Clever 1's
/// `CleverListBoardView`: every area stacked in ONE vertical scrolling list
/// at full interactive size — inline editing, no modal. (The ScrollView is
/// the owner-approved exception to the no-scroll rule.) Each card scales down
/// to the screen width via `WidthScaledCard`.
struct Clever4ListBoardView: View {
    @ObservedObject var game: Clever4Game
    /// Observed so an open board recolours when Settings changes the palette.
    @ObservedObject var diceTheme = DiceTheme.shared

    @State private var entry: ValueEntry?

    /// Explicit init: the private `@State` above makes the synthesized
    /// memberwise init non-internal.
    init(game: Clever4Game) {
        self.game = game
    }

    var body: some View {
        GeometryReader { geo in
            let cardW = geo.size.width - 24
            ScrollView {
                VStack(spacing: 14) {
                    C4BonusBanner(game: game)
                    card(.extras, width: cardW) { extrasContent }
                    card(.yellow, width: cardW) {
                        C4YellowPanel(game: game, cell: 54) { entry = $0 }
                    }
                    card(.blue, width: cardW) {
                        C4BluePanel(game: game, cell: 48)
                    }
                    card(.grey, width: cardW) {
                        C4GreyPanel(game: game, cell: 44, split: true)
                    }
                    card(.green, width: cardW) {
                        C4GreenBand(game: game, cell: 52, split: true) { entry = $0 }
                    }
                    card(.pink, width: cardW) {
                        C4PinkBand(game: game, cell: 52, split: true) { entry = $0 }
                    }
                    WidthScaledCard(width: cardW) {
                        clever4TotalStrip(game: game, height: 46)
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
        _ section: Clever4SheetSection, width: CGFloat,
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

    private var extrasContent: some View {
        VStack(spacing: 10) {
            SheetRoundsBar(rounds: 6, darkFrom: 4, cell: 42, ink: cleverInk) { r in
                c4RoundBadge(r, game: game, size: 21)
            }
            C4FoxStepper(game: game, diameter: 26)
        }
        // A definite design width (just past the bar's natural size) so the
        // round tiles DISTRIBUTE evenly across their pills instead of hugging
        // the leading edge; the enclosing WidthScaledCard scales to fit.
        .frame(width: 380)
    }
}

// MARK: - Editor sheet (big, comfortable, paged)

struct Clever4EditorSheet: View {
    @ObservedObject var game: Clever4Game
    @ObservedObject var diceTheme = DiceTheme.shared
    @Binding var selection: Clever4SheetSection

    @State private var entry: ValueEntry?

    /// Explicit init: the private `@State` above makes the synthesized
    /// memberwise init non-internal.
    init(game: Clever4Game, selection: Binding<Clever4SheetSection>) {
        self.game = game
        self._selection = selection
    }

    var body: some View {
        SheetEditorPager(
            sections: Clever4SheetSection.allCases,
            selection: $selection,
            title: { $0.title },
            tint: { tint(for: $0) },
            accessory: {}
        ) { section in
            page(section)
        }
        .background(cleverPaper.ignoresSafeArea())
        .preferredColorScheme(.light)
        .environment(\.colorScheme, .light)
        // Hug the content, like Clever 1's editor: the tallest pages (grey's
        // two 8-column halves, blue's 6 rows) need ≈ 500 pt at these design
        // cells; `.large` remains as an expand option.
        .presentationDetents([.height(520), .large])
        .presentationDragIndicator(.hidden)
        .cleverValueEntry($entry)
    }

    private func tint(for section: Clever4SheetSection) -> Color {
        section.area.map { game.color($0).color } ?? Color(white: 0.5)
    }

    private func page(_ section: Clever4SheetSection) -> some View {
        VStack(spacing: 12) {
            C4BonusBanner(game: game)
            ScaledSheet {
                pageContent(section)
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: SheetRadius.panel, style: .continuous)
                            .fill(section == .extras ? cleverSheetGrey : tint(for: section))
                    )
            }
            footer(section)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 34) // clear the page dots
    }

    @ViewBuilder private func pageContent(_ section: Clever4SheetSection) -> some View {
        switch section {
        case .yellow:
            C4YellowPanel(game: game, cell: 50) { entry = $0 }
        case .blue:
            C4BluePanel(game: game, cell: 46)
        case .grey:
            C4GreyPanel(game: game, cell: 40, split: true)
        case .green:
            C4GreenBand(game: game, cell: 52, split: true) { entry = $0 }
        case .pink:
            C4PinkBand(game: game, cell: 50, split: true) { entry = $0 }
        case .extras:
            extrasContent
        }
    }

    private var extrasContent: some View {
        VStack(spacing: 10) {
            SheetRoundsBar(rounds: 6, darkFrom: 4, cell: 42, ink: cleverInk) { r in
                c4RoundBadge(r, game: game, size: 21)
            }
            C4FoxStepper(game: game, diameter: 26)
        }
        // A definite design width (just past the bar's natural size) so the
        // round tiles DISTRIBUTE evenly; the enclosing ScaledSheet scales it.
        .frame(width: 380)
    }

    @ViewBuilder private func footer(_ section: Clever4SheetSection) -> some View {
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
