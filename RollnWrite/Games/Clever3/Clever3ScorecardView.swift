//
//  Clever3ScorecardView.swift
//  RollnWrite – Clever3
//
//  "Clever Cubed" scorecard, rebuilt to the canonical Clever v3 concept on the
//  shared sheet piece library (`CleverSheetComponents.swift`). Presentation +
//  touch only — all rules, scoring, bonuses and foxes live in `Clever3Game`.
//
//  Layouts (header toggle, like Clever 1):
//  • SHEET (default) — an orientation switch:
//    – PORTRAIT: a faithful one-screen miniature of the official Clever hoch
//      Drei score sheet (Schmidt Spiele art. 49384): header (1–6 rounds bar +
//      the three printed action tracks), yellow | turquoise side by side, the
//      full-width blue ±1 band, the brown row, the pink row, the manual fox
//      stepper and the totals strip. Tapping an area's chrome (outside its
//      cells) opens a paged editor (`SheetEditorPager`).
//    – LANDSCAPE: a direct-tap reflow — a vertical rounds rail, the yellow +
//      turquoise grids stacked in a left column (with the fox stepper), and
//      the action tracks + blue/brown/pink bands filling the right column at
//      large cell sizes. No editor modal and no totals strip here (owner
//      precedent — scoring only matters at game end).
//  • LIST — every area stacked in ONE vertical scrolling list of full-size
//    cards (inline editing, owner-approved exception to the no-scroll rule),
//    mirroring `CleverListBoardView`.
//
//  NOTE on the rounds bar and action tracks: unlike Clever 1, the Clever 3
//  engine does not persist rounds/action bookkeeping, and engines are
//  read-only in this design pass — so the crossable rounds bar and the three
//  action tracks are SESSION-ONLY view state (`C3Tracks`): pure pen strokes,
//  never a game move, cleared when the scorecard is left.
//

import SwiftUI

// MARK: - Board layout (sheet vs scrolling list)

/// The two Clever 3 board layouts, mirroring Clever 1's `CleverBoardLayout`:
/// the v3 sheet (portrait miniature / landscape reflow) versus one vertical
/// scrolling list of full-size areas.
enum Clever3BoardLayout: String {
    case sheet, list
    static let storageKey = "clever3.layout"
}

// MARK: - Sheet sections

/// The tappable regions of the sheet — one editor page each. Sheet order:
/// the five areas, then the rounds / action-track header.
enum C3SheetSection: String, CaseIterable, Identifiable, Hashable {
    case yellow, turquoise, blue, brown, pink, tracks

    var id: String { rawValue }

    /// The scoring area behind this section (`nil` for the header tracks).
    var area: Clever3Area? { Clever3Area(rawValue: rawValue) }

    /// Localisation KEY for the editor page title.
    var title: String { area?.title ?? "Rounds & bonuses" }
}

// MARK: - Session-only bookkeeping (rounds + action tracks)

/// Pen strokes on the printed header that `Clever3Game` does not model:
/// crossed rounds and the three action tracks (each slot cycles blank →
/// circled/earned → crossed/used, exactly how the physical sheet is used).
/// Deliberately NOT persisted — engines are read-only in this design pass
/// and no new stored state is allowed.
struct C3Tracks {
    var rounds: Set<Int> = []
    var reroll: [Int] = Array(repeating: 0, count: 7)
    var joker: [Int] = Array(repeating: 0, count: 7)
    var extra: [Int] = Array(repeating: 0, count: 7)
}

// MARK: - Printed sheet art (badges, grey/tinted cells)
//
// Transcribed from the official rulebook's sheet render (Schmidt Spiele,
// art. 49384, "BONI" page). Purely decorative here — the engine surfaces the
// corresponding advisory messages itself when completions trigger.

enum C3SheetArt {
    /// Badges printed under rounds 1–4 (rounds 5/6 carry player-count marks).
    static let roundBadges: [Int: C3BonusIcon] = [
        0: .reroll, 1: .extraDie, 2: .joker, 3: .pick(nil),
    ]
    /// Yellow: the six grey "passive player" cells (row-major over 3×6):
    /// row I cols 5–6, row II cols 3–4, row III cols 1–2.
    static let yellowGreyCells: Set<Int> = [4, 5, 8, 9, 12, 13]
    /// Yellow: bonus badges printed on the two row dividers (one per column).
    static let yellowDividerBonuses: [[C3BonusIcon]] = [
        [.reroll, .joker, .pick(.pink), .extraDie, .pick(.turquoise), .fox],
        [.joker, .pick(.turquoise), .pick(.blue), .pick(.brown), .pick(.yellow), .extraDie],
    ]
    /// Turquoise: how many leading cells of each row are tinted ("normal");
    /// the rest print white (only reachable via extra matching dice).
    static let turquoiseTintedPerRow = [6, 5, 3, 2, 1]
    /// Turquoise: row-end badges (after a printed ▶) and column-foot badges.
    static let turquoiseRowEnd: [C3BonusIcon?] = [.fox, .extraDie, .pick(.brown), .pick(.turquoise), nil]
    static let turquoiseColFoot: [C3BonusIcon] = [
        .pick(.brown), .pick(.pink), .pick(.yellow), .joker, .pick(.blue), .reroll,
    ]
    /// Blue: badges under track positions (index 0 innermost … 5 outermost).
    static let blueLeftBadges: [Int: C3BonusIcon] = [
        5: .extraDie, 4: .pick(.pink), 2: .pick(.yellow), 1: .joker,
    ]
    static let blueRightBadges: [Int: C3BonusIcon] = [
        1: .reroll, 2: .pick(.brown), 4: .pick(.turquoise), 5: .fox,
    ]
    /// Brown/pink: badge printed in the gap BEFORE cell `key` (it fires when
    /// both neighbours are reached — matching the engine's attach-to-later-
    /// cell advisory model).
    static let brownGapBadges: [Int: C3BonusIcon] = [
        1: .joker, 2: .pick(.pink), 4: .reroll, 5: .pick(.turquoise),
        7: .extraDie, 8: .pick(.blue), 10: .pick(.yellow), 11: .fox,
    ]
    static let pinkGapBadges: [Int: C3BonusIcon] = [
        1: .reroll, 2: .pick(.blue), 3: .extraDie, 4: .joker, 5: .pick(.yellow),
        6: .pick(.brown), 7: .reroll, 8: .fox, 9: .pick(.blue), 10: .pick(.turquoise),
    ]
}

// MARK: - Scorecard (scaffold wrapper)

public struct Clever3ScorecardView: View {
    @StateObject private var game = Clever3Game()
    let rules: RulesDocument

    @State private var confirmNewGame = false
    /// Session-only rounds/action-track pen strokes (see the header note).
    @State private var tracks = C3Tracks()
    @AppStorage(Clever3BoardLayout.storageKey) private var layoutRaw = Clever3BoardLayout.sheet.rawValue

    public init(rules: RulesDocument) {
        self.rules = rules
    }

    private var layout: Clever3BoardLayout { Clever3BoardLayout(rawValue: layoutRaw) ?? .sheet }

    public var body: some View {
        ScorecardScaffold(
            title: "Clever Cubed",
            rules: rules,
            // Both orientations scale to fit — let the screen rotate freely.
            locksLandscape: false,
            board: {
                Group {
                    switch layout {
                    case .sheet: Clever3BoardView(game: game, tracks: $tracks)
                    case .list: C3ListBoardView(game: game, tracks: $tracks)
                    }
                }
            },
            headerAccessory: {
                HStack(spacing: 16) {
                    Button {
                        layoutRaw = (layout == .sheet ? Clever3BoardLayout.list : .sheet).rawValue
                    } label: {
                        // The icon shows the layout the tap switches TO.
                        Image(systemName: layout == .sheet ? "list.bullet" : "rectangle.grid.1x2")
                    }
                    .accessibilityLabel(layout == .sheet ? "List layout" : "Sheet layout")
                    // Clever 3 has no LIFO history (`canUndo` is always false;
                    // undo happens by tapping marks directly) — the button is
                    // kept for family consistency and stays disabled.
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
        .tint(Color(red: 0.10, green: 0.60, blue: 0.55))
        .confirmationDialog("Start a new game?", isPresented: $confirmNewGame, titleVisibility: .visible) {
            Button("New game", role: .destructive) {
                game.reset()
                tracks = C3Tracks()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears the scorecard.")
        }
    }
}

// MARK: - Orientation switch (the "sheet" layout)

/// Landscape → the direct-tap reflow; portrait → the sheet miniature.
struct Clever3BoardView: View {
    @ObservedObject var game: Clever3Game
    @Binding var tracks: C3Tracks

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > geo.size.height {
                C3LandscapeBoard(game: game, tracks: $tracks)
            } else {
                C3SheetBoardView(game: game, tracks: $tracks)
            }
        }
    }
}

// MARK: - Portrait board (the faithful miniature)

struct C3SheetBoardView: View {
    @ObservedObject var game: Clever3Game
    /// Observed so an open board recolours when Settings changes the palette.
    @ObservedObject var diceTheme = DiceTheme.shared
    @Binding var tracks: C3Tracks

    @State private var editorSection: C3SheetSection = .yellow
    @State private var showEditor = false
    @State private var entry: ValueEntry?

    /// Explicit init: the private `@State`s above make the synthesized
    /// memberwise init non-internal, and sibling views construct this board.
    init(game: Clever3Game, tracks: Binding<C3Tracks>) {
        self.game = game
        self._tracks = tracks
    }

    // Design-space constants (pre-scale points). The sheet is laid out at a
    // fixed "natural" WIDTH; `ScaledSheet` stretches its heights to consume
    // the available aspect (portrait) and then scales the whole sheet to fit.
    private let sheetW: CGFloat = 580
    /// Yellow/turquoise grid cell. Yellow row = label 0.55c + 0.15c spacing +
    /// 6 cells + 5 gaps of 0.1c = 7.2c; turquoise row = 6c + 0.5c gaps +
    /// 0.12c + trailing badge slot 0.9c = 7.52c. Panel content width =
    /// (580 − 28 sheet pad − 10 gap)/2 − 20 panel pad = 251, so cell 32 keeps
    /// both grids inside (7.52 × 32 = 241 ≤ 251).
    private let gridCell: CGFloat = 32
    /// Width available to a row band's CELLS: the sheet width minus the
    /// sheet's horizontal padding (2×14), the band's own padding (2×8), the
    /// fixed-width chevron (14) and its spacing (6). Cell sizes are derived
    /// from it so the last cell ends flush with the band — no trailing gap.
    private var bandContentW: CGFloat { sheetW - 28 - 16 - 14 - 6 }
    /// Blue: 13 tiles (6 + centre 7 + 6) + 12 ±1 separators of 0.3c = 16.6c.
    private var blueCell: CGFloat { bandContentW / 16.6 }
    /// Brown: 12 cells + 11 badge gaps of 0.5c = 17.5c.
    private var brownCell: CGFloat { bandContentW / 17.5 }
    /// Pink: 11 cells + 10 badge gaps of 0.5c = 16c.
    private var pinkCell: CGFloat { bandContentW / 16 }

    var body: some View {
        ScaledSheet(maxStretch: 1.6) { stretch in sheet(stretch) }
            .padding(6)
            .overlay(alignment: .top) {
                C3BonusBanner(game: game)
                    .padding(.horizontal, 12)
            }
            .sheet(isPresented: $showEditor) {
                C3EditorSheet(game: game, tracks: $tracks, selection: $editorSection)
            }
            .cleverValueEntry($entry)
    }

    private func open(_ section: C3SheetSection) {
        editorSection = section
        showEditor = true
    }

    // MARK: The sheet

    private func sheet(_ stretch: CGFloat) -> some View {
        VStack(spacing: 10 * stretch) {
            headerBand(stretch)
            HStack(alignment: .top, spacing: 10) {
                panel(.yellow, stretch) {
                    C3YellowGrid(game: game, cell: gridCell, stretch: stretch)
                }
                panel(.turquoise, stretch) {
                    C3TurquoiseGrid(game: game, cell: gridCell, stretch: stretch)
                }
            }
            rowBand(.blue, stretch) {
                C3BlueTrack(game: game, cell: blueCell, stretch: stretch) { entry = $0 }
            }
            rowBand(.brown, stretch) {
                C3BrownRow(game: game, cell: brownCell, stretch: stretch)
            }
            rowBand(.pink, stretch) {
                C3PinkRow(game: game, cell: pinkCell, stretch: stretch) { entry = $0 }
            }
            C3FoxRow(game: game, stretch: stretch)
            c3TotalStrip(game: game, height: 44 * min(stretch, 1.25))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14 * stretch)
        .frame(width: sheetW)
        .background(
            RoundedRectangle(cornerRadius: SheetRadius.card, style: .continuous)
                .fill(cleverSheetGrey)
        )
    }

    // MARK: Header band (rounds bar + the three action tracks)

    private func headerBand(_ stretch: CGFloat) -> some View {
        C3TracksPanel(game: game, tracks: $tracks, roundCell: 30, diameter: 15, stretch: stretch)
            .contentShape(Rectangle())
            .onTapGesture { open(.tracks) }
    }

    // MARK: Area containers (tap outside the cells opens the editor)

    private func panel<Content: View>(
        _ section: C3SheetSection, _ stretch: CGFloat, @ViewBuilder content: () -> Content
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
        _ section: C3SheetSection, _ stretch: CGFloat, @ViewBuilder content: () -> Content
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

/// The bottom summary strip (per-area scores + foxes + total) — shared by the
/// sheet overview and the list layout.
@MainActor
func c3TotalStrip(game: Clever3Game, height: CGFloat) -> some View {
    var entries: [SheetTotalStrip.Entry] = Clever3Area.allCases.map {
        SheetTotalStrip.Entry(value: "\(game.score(for: $0))", tint: game.color($0).color)
    }
    entries.append(SheetTotalStrip.Entry(value: "\(game.foxScore)",
                                         caption: "🦊×\(game.state.foxes)", tint: .red))
    return SheetTotalStrip(entries: entries, total: game.totalScore,
                           ink: cleverInk, height: height)
}

// MARK: - Round badges (printed bonuses + player-count markers)

/// The badge under a round number: the printed start-of-round bonus for
/// rounds 1–4, player-count end markers for rounds 5–6 (3 players → 5
/// rounds; 1–2 players → 6 rounds; 4 players stop after round 4). Every
/// branch occupies the identical `size`×`size` box so round tiles keep equal
/// heights everywhere rounds render (header bar, list/editor bars, rail).
@MainActor
func c3RoundBadge(_ round: Int, game: Clever3Game, size: CGFloat) -> some View {
    Group {
        if let icon = C3SheetArt.roundBadges[round] {
            C3BonusBadge(icon: icon, game: game, size: size)
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

// MARK: - Landscape reflow (rail + two columns, all direct-tap)

struct C3LandscapeBoard: View {
    @ObservedObject var game: Clever3Game
    /// Observed so an open board recolours when Settings changes the palette.
    @ObservedObject var diceTheme = DiceTheme.shared
    @Binding var tracks: C3Tracks
    @State private var entry: ValueEntry?

    /// Explicit init (private `@State` above).
    init(game: Clever3Game, tracks: Binding<C3Tracks>) {
        self.game = game
        self._tracks = tracks
    }

    // Design-space constants (pre-scale points). Each piece is laid out at a
    // fixed natural width; its `ScaledSheet` stretches heights toward the
    // slot's aspect and then scales the whole piece uniformly to fit.
    private let railW: CGFloat = 46
    /// Left column: grids at cell 30 — the wider turquoise row (7.52c = 226)
    /// fits the 250 − 20 panel padding = 230 content width.
    private let leftW: CGFloat = 250
    private let gridCell: CGFloat = 30
    private let rightW: CGFloat = 560
    /// Width available to a row band's CELLS: the column width minus the
    /// band's padding (2×8), the fixed-width chevron (14) and its spacing (6).
    private var bandContentW: CGFloat { rightW - 16 - 14 - 6 }
    /// Blue: 13 tiles + 12 ±1 separators of 0.3c = 16.6c.
    private var blueCell: CGFloat { bandContentW / 16.6 }
    /// Brown: 12 cells + 11 badge gaps of 0.5c = 17.5c.
    private var brownCell: CGFloat { bandContentW / 17.5 }
    /// Pink: 11 cells + 10 badge gaps of 0.5c = 16c.
    private var pinkCell: CGFloat { bandContentW / 16 }

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .top, spacing: 10) {
                // Trailing-anchored: when the rail's fit is height-bound the
                // width slack lands at the OUTER screen edge, so the gutter
                // between the rail and the yellow panel stays exactly the
                // standard 10 pt inter-panel gap.
                ScaledSheet(maxStretch: 1.5, anchor: .topTrailing) { stretch in roundsRail(stretch) }
                    .frame(width: 52)
                ScaledSheet(maxStretch: 1.35, anchor: .topLeading) { stretch in leftColumn(stretch) }
                    .frame(width: geo.size.width * 0.3)
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
            C3BonusBanner(game: game)
                .padding(.horizontal, 12)
        }
        .cleverValueEntry($entry)
    }

    // MARK: Rounds rail — the 1–6 rounds as a vertical left-edge column

    /// Vertical counterpart of `SheetRoundsBar`: one dark tile per round with
    /// an upright number and the printed badge underneath. Crossing a round
    /// is session-only bookkeeping — never a game move.
    private func roundsRail(_ stretch: CGFloat) -> some View {
        VStack(spacing: 6 * stretch) {
            ForEach(0..<6, id: \.self) { r in
                VStack(spacing: 4 * stretch) {
                    Button { toggleRound(r) } label: {
                        ZStack {
                            // 0.2 × tile width — the shared cell radius.
                            RoundedRectangle(cornerRadius: (railW - 12) * 0.2, style: .continuous)
                                .fill(Color.white)
                            Text("\(r + 1)")
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                                .foregroundStyle(cleverInk)
                            if tracks.rounds.contains(r) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundStyle(cleverInk.opacity(0.88))
                                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                            }
                        }
                        .frame(width: railW - 12, height: 30 * stretch)
                        .animation(.spring(response: 0.26, dampingFraction: 0.6),
                                   value: tracks.rounds.contains(r))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Round \(r + 1)"))
                    .accessibilityValue(tracks.rounds.contains(r) ? "marked" : "available")
                    c3RoundBadge(r, game: game, size: 18)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6 * stretch)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: SheetRadius.pill, style: .continuous)
                        .fill(r >= 4 ? Color.black : Color(white: 0.3))
                )
            }
        }
        .frame(width: railW)
    }

    private func toggleRound(_ r: Int) {
        if tracks.rounds.contains(r) { tracks.rounds.remove(r) } else { tracks.rounds.insert(r) }
    }

    // MARK: Left column — yellow above turquoise, fox stepper below

    private func leftColumn(_ stretch: CGFloat) -> some View {
        VStack(spacing: 10 * stretch) {
            panel(.yellow, stretch) {
                C3YellowGrid(game: game, cell: gridCell, stretch: stretch)
            }
            panel(.turquoise, stretch) {
                C3TurquoiseGrid(game: game, cell: gridCell, stretch: stretch)
            }
            // The manual fox stepper stays reachable in landscape — a compact
            // pill under the grids (no totals strip in this orientation).
            C3FoxRow(game: game, stretch: stretch)
        }
        .frame(width: leftW)
    }

    // MARK: Right column — action tracks, then the three big bands

    private func rightColumn(_ stretch: CGFloat) -> some View {
        VStack(spacing: 10 * stretch) {
            tracksRow(stretch)
            rowBand(.blue, stretch) {
                C3BlueTrack(game: game, cell: blueCell, stretch: stretch) { entry = $0 }
            }
            rowBand(.brown, stretch) {
                C3BrownRow(game: game, cell: brownCell, stretch: stretch)
            }
            rowBand(.pink, stretch) {
                C3PinkRow(game: game, cell: pinkCell, stretch: stretch) { entry = $0 }
            }
            // No totals strip in landscape (owner call): scoring only matters
            // at game end, and the freed height goes to the three bands.
        }
        .frame(width: rightW)
    }

    /// The three action tracks side by side — one short strip where the
    /// rounds bar would sit, all directly tappable.
    private func tracksRow(_ stretch: CGFloat) -> some View {
        HStack(spacing: 10) {
            c3ActionTrack(.reroll, slots: $tracks.reroll, game: game, diameter: 14, stretch: stretch)
            c3ActionTrack(.joker, slots: $tracks.joker, game: game, diameter: 14, stretch: stretch)
            c3ActionTrack(.extra, slots: $tracks.extra, game: game, diameter: 14, stretch: stretch)
        }
    }

    // MARK: Area containers (direct interaction — no editor to open)

    private func panel<Content: View>(
        _ area: Clever3Area, _ stretch: CGFloat, @ViewBuilder content: () -> Content
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
        _ area: Clever3Area, _ stretch: CGFloat, @ViewBuilder content: () -> Content
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

/// The "list" layout: every area stacked in ONE vertical scrolling list at
/// full interactive size — inline editing, no modal (an owner-approved
/// exception to the no-scroll rule, mirroring `CleverListBoardView`). Uses
/// the SAME area views as the editor pages; each card scales down to the
/// screen width via `WidthScaledCard`.
struct C3ListBoardView: View {
    @ObservedObject var game: Clever3Game
    /// Observed so an open board recolours when Settings changes the palette.
    @ObservedObject var diceTheme = DiceTheme.shared
    @Binding var tracks: C3Tracks
    @State private var entry: ValueEntry?

    /// Explicit init (private `@State` above).
    init(game: Clever3Game, tracks: Binding<C3Tracks>) {
        self.game = game
        self._tracks = tracks
    }

    var body: some View {
        GeometryReader { geo in
            let cardW = geo.size.width - 24
            ScrollView {
                VStack(spacing: 14) {
                    C3BonusBanner(game: game)
                    card(.tracks, width: cardW) {
                        C3TracksPanel(game: game, tracks: $tracks,
                                      roundCell: 42, diameter: 26, showFox: true)
                            // A definite design width (just past the bars'
                            // natural size) so the round tiles and circles
                            // DISTRIBUTE evenly across their pills.
                            .frame(width: 390)
                    }
                    card(.yellow, width: cardW) {
                        C3YellowGrid(game: game, cell: 52)
                    }
                    card(.turquoise, width: cardW) {
                        C3TurquoiseGrid(game: game, cell: 46)
                    }
                    card(.blue, width: cardW) {
                        C3BlueTrack(game: game, cell: 46, split: true) { entry = $0 }
                    }
                    card(.brown, width: cardW) {
                        C3BrownRow(game: game, cell: 46, split: true)
                    }
                    card(.pink, width: cardW) {
                        C3PinkRow(game: game, cell: 48, split: true) { entry = $0 }
                    }
                    WidthScaledCard(width: cardW) {
                        c3TotalStrip(game: game, height: 46)
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
        _ section: C3SheetSection, width: CGFloat,
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
}

// MARK: - Editor sheet (big, comfortable, paged)

struct C3EditorSheet: View {
    @ObservedObject var game: Clever3Game
    @ObservedObject var diceTheme = DiceTheme.shared
    @Binding var tracks: C3Tracks
    @Binding var selection: C3SheetSection

    @State private var entry: ValueEntry?

    /// Explicit init (private `@State` above).
    init(game: Clever3Game, tracks: Binding<C3Tracks>, selection: Binding<C3SheetSection>) {
        self.game = game
        self._tracks = tracks
        self._selection = selection
    }

    var body: some View {
        SheetEditorPager(
            sections: C3SheetSection.allCases,
            selection: $selection,
            title: { $0.title },
            tint: { tint(for: $0) },
            // Clever 3 has no LIFO history — undo is tapping marks directly,
            // so the header carries no accessory.
            accessory: { EmptyView() }
        ) { section in
            page(section)
        }
        .background(cleverPaper.ignoresSafeArea())
        .preferredColorScheme(.light)
        .environment(\.colorScheme, .light)
        // Hug the content: the pages are laid out from fixed design constants
        // (cells of 44–52 pt), so the tallest page (turquoise: 5 rows + scale
        // + foot chrome) needs ≈ 500 pt. `.large` remains as an expand option.
        .presentationDetents([.height(520), .large])
        .presentationDragIndicator(.hidden)
        .cleverValueEntry($entry)
    }

    private func tint(for section: C3SheetSection) -> Color {
        section.area.map { game.color($0).color } ?? Color(white: 0.5)
    }

    private func page(_ section: C3SheetSection) -> some View {
        VStack(spacing: 12) {
            C3BonusBanner(game: game)
            ScaledSheet {
                pageContent(section)
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: SheetRadius.panel, style: .continuous)
                            .fill(section == .tracks ? cleverSheetGrey : tint(for: section))
                    )
            }
            if section == .blue {
                Text("Outermost left + outermost right + 4 per 2/3/4/10/11/12.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if section == .pink {
                Text("Enter the value you wrote (die × the shown multiplier, or the halved bonus value).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            footer(section)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 34) // clear the page dots
    }

    @ViewBuilder private func pageContent(_ section: C3SheetSection) -> some View {
        switch section {
        case .yellow:
            C3YellowGrid(game: game, cell: 52)
        case .turquoise:
            C3TurquoiseGrid(game: game, cell: 46)
        case .blue:
            C3BlueTrack(game: game, cell: 46, split: true) { entry = $0 }
        case .brown:
            C3BrownRow(game: game, cell: 46, split: true)
        case .pink:
            C3PinkRow(game: game, cell: 48, split: true) { entry = $0 }
        case .tracks:
            C3TracksPanel(game: game, tracks: $tracks,
                          roundCell: 42, diameter: 24, showFox: true)
                // A definite design width so the tiles/circles distribute.
                .frame(width: 390)
        }
    }

    @ViewBuilder private func footer(_ section: C3SheetSection) -> some View {
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

// MARK: - Rounds + action tracks panel (header, list card and editor page)

/// The printed header block: the 1–6 rounds bar (printed round bonuses via
/// `c3RoundBadge`) above the three action tracks (re-roll, number joker,
/// extra die). Backed by the session-only `C3Tracks` state. The official
/// sheet's three dice-slot boxes (I/II/III) are pen-and-paper artifacts and
/// are deliberately omitted — same call as Clever 1's scratch boxes.
struct C3TracksPanel: View {
    @ObservedObject var game: Clever3Game
    @Binding var tracks: C3Tracks
    let roundCell: CGFloat
    let diameter: CGFloat
    var showFox = false
    var stretch: CGFloat = 1

    var body: some View {
        VStack(spacing: 6 * stretch) {
            SheetRoundsBar(rounds: 6, darkFrom: 4, cell: roundCell, ink: cleverInk, stretch: stretch,
                           crossed: tracks.rounds,
                           tap: { r in
                               if tracks.rounds.contains(r) {
                                   tracks.rounds.remove(r)
                               } else {
                                   tracks.rounds.insert(r)
                               }
                           }) { r in
                c3RoundBadge(r, game: game, size: roundCell * 0.5)
            }
            c3ActionTrack(.reroll, slots: $tracks.reroll, game: game, diameter: diameter, stretch: stretch)
            c3ActionTrack(.joker, slots: $tracks.joker, game: game, diameter: diameter, stretch: stretch)
            c3ActionTrack(.extra, slots: $tracks.extra, game: game, diameter: diameter, stretch: stretch)
            if showFox {
                C3FoxRow(game: game, stretch: stretch)
            }
        }
    }
}

// MARK: - Action tracks (3-state circles: blank → circled → crossed)

/// The three printed actions, with their leading icon, printed circle labels
/// (the number-joker track prints 3 4 5 6 ? ? ?) and the bonus badge at the
/// track's end (earned by circling the last field).
enum C3TrackKind {
    case reroll, joker, extra

    var labels: [String?] {
        switch self {
        case .joker: return ["3", "4", "5", "6", "?", "?", "?"]
        default: return Array(repeating: nil, count: 7)
        }
    }

    var icon: C3BonusIcon {
        switch self {
        case .reroll: return .reroll
        case .joker: return .joker
        case .extra: return .extraDie
        }
    }

    var endBadge: C3BonusIcon {
        switch self {
        case .reroll: return .fox
        case .joker: return .pick(.pink)
        case .extra: return .pick(.brown)
        }
    }
}

/// Builds one action track with its Clever 3 icon and end badge.
@MainActor
func c3ActionTrack(_ kind: C3TrackKind, slots: Binding<[Int]>, game: Clever3Game,
                   diameter: CGFloat, stretch: CGFloat = 1) -> some View {
    C3ActionTrack(slots: slots, labels: kind.labels, diameter: diameter, stretch: stretch,
                  icon: { C3BonusBadge(icon: kind.icon, game: game, size: diameter * 1.3) },
                  end: { C3BonusBadge(icon: kind.endBadge, game: game, size: diameter * 0.85) })
}

/// A grey action track in the `SheetCircleTrack` idiom (same pill, paddings
/// and circle states), but with THREE states per slot — on the official pad
/// a field is first CIRCLED when earned, then CROSSED when used. Each tap
/// cycles blank → circled (earned) → crossed (used) → blank. Session-only
/// bookkeeping; never a game move.
struct C3ActionTrack<Icon: View, End: View>: View {
    @Binding private var slots: [Int]
    private let labels: [String?]
    private let diameter: CGFloat
    private let ink: Color
    private let stretch: CGFloat
    private let icon: Icon
    private let end: End

    init(slots: Binding<[Int]>, labels: [String?], diameter: CGFloat,
         ink: Color = cleverInk, stretch: CGFloat = 1,
         @ViewBuilder icon: () -> Icon, @ViewBuilder end: () -> End) {
        self._slots = slots
        self.labels = labels
        self.diameter = diameter
        self.ink = ink
        self.stretch = stretch
        self.icon = icon()
        self.end = end()
    }

    var body: some View {
        // Equal flexible gaps DISTRIBUTE the circles evenly across the pill's
        // full width; in fixed-size contexts (probes, width-scaled cards) the
        // spacers collapse to their minimum — same as `SheetCircleTrack`.
        HStack(spacing: 0) {
            icon
            ForEach(slots.indices, id: \.self) { s in
                Spacer(minLength: diameter * 0.4)
                slotButton(s)
            }
            Spacer(minLength: diameter * 0.35)
            end
        }
        .padding(.horizontal, diameter * 0.45)
        .padding(.vertical, diameter * 0.3 * stretch)
        .background(
            RoundedRectangle(cornerRadius: SheetRadius.pill, style: .continuous)
                .fill(Color(white: 0.62))
        )
    }

    private func slotButton(_ s: Int) -> some View {
        let state = slots[s]
        let label = labels.indices.contains(s) ? labels[s] : nil
        return Button {
            slots[s] = (state + 1) % 3
        } label: {
            ZStack {
                if state == 2 {
                    // USED: ink fill + white rim + ✗.
                    Circle().fill(ink)
                    Circle().strokeBorder(Color.white, lineWidth: SheetStroke.medium)
                    Image(systemName: "xmark")
                        .font(.system(size: diameter * 0.5, weight: .black))
                        .foregroundStyle(.white)
                } else if state == 1 {
                    // EARNED (circled): near-white fill + solid ink ring.
                    Circle().fill(Color.white.opacity(0.9))
                    Circle().strokeBorder(ink, lineWidth: SheetStroke.medium)
                } else {
                    // BLANK: faint ghost of the printed circle.
                    Circle().fill(Color.white.opacity(0.15))
                    Circle().strokeBorder(Color.white.opacity(0.45),
                                          lineWidth: SheetStroke.medium)
                }
                if state < 2, let label {
                    Text(label)
                        .font(.system(size: diameter * 0.42, weight: .heavy, design: .rounded))
                        .foregroundStyle(state == 1 ? ink : ink.opacity(0.55))
                }
            }
            .frame(width: diameter, height: diameter)
            .animation(.snappy, value: state)
        }
        .buttonStyle(.plain)
        .accessibilityValue(state == 2 ? "marked" : (state == 1 ? "available" : "not earned yet"))
    }
}

// MARK: - Yellow area (3 rows × 6, grey passive cells, divider bonuses)

struct C3YellowGrid: View {
    @ObservedObject var game: Clever3Game
    @ObservedObject var diceTheme = DiceTheme.shared
    let cell: CGFloat
    /// Vertical stretch — multiplies cell heights and vertical gaps only.
    var stretch: CGFloat = 1

    private var gap: CGFloat { cell * 0.1 }
    private var labelW: CGFloat { cell * 0.55 }
    private static let romans = ["I", "II", "III"]

    var body: some View {
        let tint = game.color(.yellow)
        VStack(spacing: gap * stretch) {
            scaleStrip(tint)
            divider
            ForEach(0..<Clever3Layout.yellowRows, id: \.self) { row in
                gridRow(row, tint: tint)
                if row < Clever3Layout.yellowRows - 1 {
                    badgeRow(C3SheetArt.yellowDividerBonuses[row])
                }
            }
        }
    }

    /// The printed "crosses → points" scale (1:2 … 6:42); the seal of any
    /// row's current cross-count lights up.
    private func scaleStrip(_ tint: DiceColor) -> some View {
        HStack(spacing: cell * 0.15) {
            Color.clear.frame(width: labelW, height: 1)
            HStack(spacing: gap) {
                ForEach(1...Clever3Layout.yellowCols, id: \.self) { n in
                    HStack(spacing: 1) {
                        Text("\(n)")
                            .font(.system(size: cell * 0.24, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                        SheetPointsBadge(
                            value: Clever3Layout.yellowRowScale[n], tint: tint.color,
                            size: cell * 0.48,
                            highlighted: (0..<Clever3Layout.yellowRows).contains {
                                game.yellowMarks(inRow: $0) == n
                            }
                        )
                    }
                    .frame(width: cell)
                }
            }
        }
        .padding(.vertical, cell * 0.04)
        .background(Capsule().fill(.white.opacity(0.35)))
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.5))
            .frame(height: SheetStroke.small)
    }

    private func gridRow(_ row: Int, tint: DiceColor) -> some View {
        HStack(spacing: cell * 0.15) {
            Text(Self.romans[row])
                .font(.system(size: cell * 0.34, weight: .black, design: .rounded))
                .italic()
                .foregroundStyle(.white)
                .frame(width: labelW)
            HStack(spacing: gap) {
                ForEach(0..<Clever3Layout.yellowCols, id: \.self) { col in
                    let idx = row * Clever3Layout.yellowCols + col
                    SheetCell(
                        label: "\(col + 1)",
                        tint: tint.color,
                        ink: cleverInk,
                        marked: game.state.yellow.contains(idx),
                        // Free toggling: every cell is legal and tapping a
                        // crossed cell un-crosses it (the engine's own undo).
                        legal: true,
                        size: cell,
                        height: cell * stretch
                    ) {
                        game.toggleYellow(idx)
                    }
                    .overlay(
                        // "Grau unterlegt": the six printed passive-player
                        // cells get a grey wash (presentation only).
                        RoundedRectangle(cornerRadius: cell * 0.2, style: .continuous)
                            .fill(Color.black.opacity(
                                C3SheetArt.yellowGreyCells.contains(idx) ? 0.16 : 0))
                            .allowsHitTesting(false)
                    )
                }
            }
        }
    }

    /// The bonus badges printed on a row divider (one per column).
    private func badgeRow(_ icons: [C3BonusIcon]) -> some View {
        HStack(spacing: cell * 0.15) {
            Color.clear.frame(width: labelW, height: 1)
            HStack(spacing: gap) {
                ForEach(icons.indices, id: \.self) { c in
                    C3BonusBadge(icon: icons[c], game: game, size: cell * 0.5)
                        .frame(width: cell, height: cell * 0.55 * stretch)
                }
            }
        }
    }
}

// MARK: - Turquoise area (5 rows × 6, tinted staircase, row/column bonuses)

struct C3TurquoiseGrid: View {
    @ObservedObject var game: Clever3Game
    @ObservedObject var diceTheme = DiceTheme.shared
    let cell: CGFloat
    /// Vertical stretch — multiplies cell heights and vertical gaps only.
    var stretch: CGFloat = 1

    private var gap: CGFloat { cell * 0.1 }
    /// The trailing row-end slot: arrow 0.24c + 0.06c spacing + badge 0.6c.
    private var trailW: CGFloat { cell * 0.9 }

    var body: some View {
        let tint = game.color(.turquoise)
        VStack(spacing: gap * stretch) {
            scaleStrip(tint)
            divider
            ForEach(0..<Clever3Layout.turquoiseRows, id: \.self) { row in
                gridRow(row, tint: tint)
            }
            footRow
        }
    }

    private func scaleStrip(_ tint: DiceColor) -> some View {
        HStack(spacing: cell * 0.12) {
            HStack(spacing: gap) {
                ForEach(1...Clever3Layout.turquoiseCols, id: \.self) { n in
                    HStack(spacing: 1) {
                        Text("\(n)")
                            .font(.system(size: cell * 0.24, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                        SheetPointsBadge(
                            value: Clever3Layout.turquoiseRowScale[n], tint: tint.color,
                            size: cell * 0.48,
                            highlighted: (0..<Clever3Layout.turquoiseRows).contains {
                                game.turquoiseMarks(inRow: $0) == n
                            }
                        )
                    }
                    .frame(width: cell)
                }
            }
            .padding(.vertical, cell * 0.04)
            .background(Capsule().fill(.white.opacity(0.35)))
            Color.clear.frame(width: trailW, height: 1)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.5))
            .frame(height: SheetStroke.small)
    }

    private func gridRow(_ row: Int, tint: DiceColor) -> some View {
        HStack(spacing: cell * 0.12) {
            HStack(spacing: gap) {
                ForEach(0..<Clever3Layout.turquoiseCols, id: \.self) { col in
                    let idx = row * Clever3Layout.turquoiseCols + col
                    SheetCell(
                        label: "\(col + 1)",
                        tint: tint.color,
                        ink: cleverInk,
                        marked: game.state.turquoise.contains(idx),
                        legal: true, // free toggling, as in yellow
                        size: cell,
                        height: cell * stretch
                    ) {
                        game.toggleTurquoise(idx)
                    }
                    .overlay(
                        // The printed tinted staircase ("türkis unterlegt");
                        // the remaining white cells are only reachable via
                        // extra matching dice. Presentation only.
                        RoundedRectangle(cornerRadius: cell * 0.2, style: .continuous)
                            .fill(tint.color.opacity(
                                col < C3SheetArt.turquoiseTintedPerRow[row] ? 0.3 : 0))
                            .allowsHitTesting(false)
                    )
                }
            }
            rowEnd(row)
        }
    }

    private func rowEnd(_ row: Int) -> some View {
        HStack(spacing: cell * 0.06) {
            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: cell * 0.2, weight: .black))
                .foregroundStyle(.black.opacity(0.55))
                .frame(width: cell * 0.24)
                .opacity(C3SheetArt.turquoiseRowEnd[row] != nil ? 1 : 0)
            c3BonusSlot(C3SheetArt.turquoiseRowEnd[row], game: game, size: cell * 0.6)
        }
        .frame(width: trailW, height: cell * stretch)
    }

    /// The column-foot bonuses (a ▼ over each badge), as printed.
    private var footRow: some View {
        HStack(spacing: cell * 0.12) {
            HStack(spacing: gap) {
                ForEach(C3SheetArt.turquoiseColFoot.indices, id: \.self) { c in
                    VStack(spacing: 1) {
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: cell * 0.16, weight: .black))
                            .foregroundStyle(.black.opacity(0.55))
                        C3BonusBadge(icon: C3SheetArt.turquoiseColFoot[c], game: game, size: cell * 0.5)
                    }
                    .frame(width: cell)
                }
            }
            .padding(.vertical, cell * 0.05)
            .background(Capsule().fill(.white.opacity(0.35)))
            Color.clear.frame(width: trailW, height: 1)
        }
    }
}

// MARK: - Blue area (±1 track around the central 7)

struct C3BlueTrack: View {
    @ObservedObject var game: Clever3Game
    @ObservedObject var diceTheme = DiceTheme.shared
    let cell: CGFloat
    /// Wrap into two lines (left side + 7, then the right side) — used by
    /// the big editor page and the list cards.
    var split = false
    /// Vertical stretch — multiplies cell heights and vertical gaps only.
    var stretch: CGFloat = 1
    let requestEntry: (ValueEntry) -> Void

    private var n: Int { Clever3Layout.blueSideCells }

    var body: some View {
        let tint = game.color(.blue)
        VStack(alignment: .leading, spacing: cell * 0.16 * stretch) {
            if split {
                leftLine(tint)
                rightLine(tint)
            } else {
                HStack(spacing: 0) {
                    leftLine(tint)
                    rightLine(tint)
                }
            }
            legend
        }
    }

    /// Outermost-left … innermost-left, each followed by a "−1", then the
    /// pre-printed central 7 (the start point, reroll bonus below).
    private func leftLine(_ tint: DiceColor) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<n, id: \.self) { k in
                column(left: true, index: n - 1 - k, tint: tint)
                separator("-1")
            }
            centerColumn(tint)
        }
    }

    /// "+1" separators then innermost-right … outermost-right.
    private func rightLine(_ tint: DiceColor) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<n, id: \.self) { k in
                separator("+1")
                column(left: false, index: k, tint: tint)
            }
        }
    }

    private func column(left: Bool, index i: Int, tint: DiceColor) -> some View {
        let value = left ? game.state.blueLeft[i] : game.state.blueRight[i]
        let isNext = (left ? game.blueLeftNext : game.blueRightNext) == i
        let badge = left ? C3SheetArt.blueLeftBadges[i] : C3SheetArt.blueRightBadges[i]
        let reached = (left ? game.state.blueLeft : game.state.blueRight)
            .lastIndex(where: { $0 != nil })
        return VStack(spacing: cell * 0.08 * stretch) {
            // The printed points seal for this position — the outermost
            // written position (the one that scores) lights up.
            SheetPointsBadge(value: Clever3Layout.bluePositionScale[i], tint: tint.color,
                             size: cell * 0.5, highlighted: reached == i)
                .frame(height: cell * 0.6)
            SheetWriteCell(
                value: value,
                tint: tint.color,
                ink: cleverInk,
                isNext: isNext,
                size: cell,
                height: cell * stretch
            ) {
                // The engine has no per-cell blue undo (values only fill
                // outward), so only the next free cell is tappable.
                guard isNext else { return }
                let allowed = game.allowedBlue(left: left)
                guard !allowed.isEmpty else { return }
                requestEntry(ValueEntry(title: "Blue value", allowed: allowed) {
                    game.fillBlue(left: left, $0)
                })
            }
            c3BonusSlot(badge, game: game, size: cell * 0.5)
        }
    }

    private func centerColumn(_ tint: DiceColor) -> some View {
        VStack(spacing: cell * 0.08 * stretch) {
            Color.clear.frame(width: cell * 0.5, height: cell * 0.6)
            ZStack {
                RoundedRectangle(cornerRadius: cell * 0.2, style: .continuous)
                    .fill(cleverInk.opacity(0.85))
                Text("7")
                    .font(.system(size: cell * 0.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: cell, height: cell * stretch)
            .accessibilityHidden(true)
            c3BonusSlot(C3BonusIcon.reroll, game: game, size: cell * 0.5)
        }
    }

    /// A "−1"/"+1" printed between neighbouring tiles, on the cells' line.
    private func separator(_ label: String) -> some View {
        VStack(spacing: cell * 0.08 * stretch) {
            Color.clear.frame(width: cell * 0.3, height: cell * 0.6)
            Text(label)
                .font(.system(size: cell * 0.26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: cell * 0.3, height: cell * stretch)
            Color.clear.frame(width: cell * 0.3, height: cell * 0.5)
        }
    }

    /// The printed rule reminders: "blue die + white die" and the +4 values.
    private var legend: some View {
        HStack(spacing: cell * 0.3) {
            HStack(spacing: 2) {
                Image(systemName: "die.face.5.fill")
                Image(systemName: "plus")
                Image(systemName: "die.face.2")
            }
            .font(.system(size: cell * 0.3, weight: .bold))
            .foregroundStyle(.white)
            .accessibilityHidden(true)
            Spacer(minLength: 0)
            legendPill("2 · 3 · 4")
            legendPill("10 · 11 · 12")
            legendPill("+4")
        }
    }

    private func legendPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: cell * 0.26, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, cell * 0.2)
            .padding(.vertical, cell * 0.06)
            .background(Capsule().fill(.black.opacity(0.32)))
    }
}

// MARK: - Brown area (one row of 12, left→right with skips)

struct C3BrownRow: View {
    @ObservedObject var game: Clever3Game
    @ObservedObject var diceTheme = DiceTheme.shared
    let cell: CGFloat
    /// Wrap into two lines (6 + 6) — used by the big editor page.
    var split = false
    /// Vertical stretch — multiplies cell heights and vertical gaps only.
    var stretch: CGFloat = 1

    var body: some View {
        let tint = game.color(.brown)
        Group {
            if split {
                VStack(alignment: .leading, spacing: cell * 0.3) {
                    segment(0..<6, tint: tint)
                    segment(6..<Clever3Layout.brownNumbers.count, tint: tint)
                }
            } else {
                segment(0..<Clever3Layout.brownNumbers.count, tint: tint)
            }
        }
    }

    private func segment(_ range: Range<Int>, tint: DiceColor) -> some View {
        HStack(spacing: 0) {
            ForEach(range, id: \.self) { i in
                if i > range.lowerBound {
                    gapSlot(C3SheetArt.brownGapBadges[i])
                }
                cellColumn(i, tint: tint)
            }
        }
    }

    private func cellColumn(_ i: Int, tint: DiceColor) -> some View {
        let crossed = game.state.brown.contains(i)
        let undoable = crossed && i == game.state.brown.max()
        return VStack(spacing: cell * 0.08 * stretch) {
            // "n crosses → points" seal above each cell; the seal of the
            // current cross-count lights up.
            HStack(spacing: 1) {
                Text("\(i + 1)")
                    .font(.system(size: cell * 0.2, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                SheetPointsBadge(value: Clever3Layout.brownScale[i + 1], tint: tint.color,
                                 size: cell * 0.46,
                                 highlighted: game.state.brown.count == i + 1)
            }
            .frame(height: cell * 0.56)
            SheetCell(
                label: "\(Clever3Layout.brownNumbers[i])",
                tint: tint.color,
                ink: cleverInk,
                marked: crossed,
                legal: game.canCrossBrown(i),
                undoable: undoable,
                size: cell,
                height: cell * stretch
            ) {
                // The engine crosses forward and un-crosses only the
                // rightmost mark — exactly the tap-to-undo contract.
                game.toggleBrown(i)
            }
        }
    }

    /// The gap between neighbouring cells, holding the printed bonus badge
    /// (earned when the cell after the gap is reached).
    private func gapSlot(_ icon: C3BonusIcon?) -> some View {
        VStack(spacing: cell * 0.08 * stretch) {
            Color.clear.frame(width: cell * 0.5, height: cell * 0.56)
            ZStack {
                c3BonusSlot(icon, game: game, size: cell * 0.45)
            }
            .frame(width: cell * 0.5, height: cell * stretch)
        }
    }
}

// MARK: - Pink area (11 write-in cells, die × multiplier or halved bonus)

struct C3PinkRow: View {
    @ObservedObject var game: Clever3Game
    @ObservedObject var diceTheme = DiceTheme.shared
    let cell: CGFloat
    /// Wrap into two lines (6 + 5) — used by the big editor page.
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
                    segment(6..<Clever3Layout.pinkCells, tint: tint)
                }
            } else {
                segment(0..<Clever3Layout.pinkCells, tint: tint)
            }
        }
    }

    private func segment(_ range: Range<Int>, tint: DiceColor) -> some View {
        HStack(spacing: 0) {
            ForEach(range, id: \.self) { i in
                if i > range.lowerBound {
                    gapSlot(C3SheetArt.pinkGapBadges[i])
                }
                cellColumn(i, tint: tint)
            }
        }
    }

    private func cellColumn(_ i: Int, tint: DiceColor) -> some View {
        let isNext = game.state.pink.firstIndex(where: { $0 == nil }) == i
        let lastFilled = game.state.pink.lastIndex(where: { $0 != nil })
        let undoable = lastFilled == i
        return VStack(spacing: cell * 0.08 * stretch) {
            multiplierSeal(Clever3Layout.pinkMultipliers[i], tint: tint)
            SheetWriteCell(
                value: game.state.pink[i],
                // The printed "halve the die" watermark inside empty cells.
                hint: "½",
                tint: tint.color,
                ink: cleverInk,
                isNext: isNext,
                undoable: undoable,
                size: cell,
                height: cell * stretch
            ) {
                if undoable {
                    // Tap-to-undo on the most recent written value — the
                    // engine's `setPink(_, nil)` is its per-cell undo.
                    game.setPink(i, nil)
                } else if isNext {
                    let mult = Clever3Layout.pinkMultipliers[i]
                    requestEntry(ValueEntry(title: "Pink written value",
                                            allowed: c3PinkAllowedValues(mult)) {
                        game.setPink(i, $0)
                    })
                }
            }
        }
    }

    /// The printed "×n" multiplier seal above each cell.
    private func multiplierSeal(_ m: Int, tint: DiceColor) -> some View {
        ZStack {
            Image(systemName: "seal.fill")
                .font(.system(size: cell * 0.46, weight: .black))
                .foregroundStyle(.white)
            Text("×\(m)")
                .font(.system(size: cell * 0.19, weight: .heavy, design: .rounded))
                .foregroundStyle(tint.color)
        }
        .frame(height: cell * 0.56)
    }

    private func gapSlot(_ icon: C3BonusIcon?) -> some View {
        VStack(spacing: cell * 0.08 * stretch) {
            Color.clear.frame(width: cell * 0.5, height: cell * 0.56)
            ZStack {
                c3BonusSlot(icon, game: game, size: cell * 0.45)
            }
            .frame(width: cell * 0.5, height: cell * stretch)
        }
    }
}

/// The values a pink cell can hold: die × the printed multiplier (points) or
/// the halved die rounded up (the bonus option). Presentation of the possible
/// pen strokes only — the engine accepts any written value.
func c3PinkAllowedValues(_ multiplier: Int) -> [Int] {
    var values = Set<Int>()
    for die in 1...6 {
        values.insert(die * multiplier)
        values.insert((die + 1) / 2)
    }
    return values.sorted()
}

// MARK: - Fox stepper (manual, per the Clever 2/3 fox model)

/// A compact sheet-styled fox counter: foxes are MANUAL in Clever Cubed
/// (their triggers are spread across many completions), each scoring the
/// lowest area at game end.
struct C3FoxRow: View {
    @ObservedObject var game: Clever3Game
    var stretch: CGFloat = 1

    var body: some View {
        HStack(spacing: 12) {
            Text("🦊")
                .font(.system(size: 18))
            Text("×\(game.state.foxes)")
                .font(.system(size: 17, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(cleverInk)
                .contentTransition(.numericText())
            Spacer(minLength: 12)
            Button { game.removeFox() } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(cleverInk)
            }
            .buttonStyle(.plain)
            .disabled(game.state.foxes == 0)
            .opacity(game.state.foxes == 0 ? 0.4 : 1)
            .accessibilityLabel("Remove fox")
            Button { game.addFox() } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(cleverInk)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add fox")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5 * stretch)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: SheetRadius.pill, style: .continuous)
                .fill(Color.white.opacity(0.55))
        )
        .animation(.snappy, value: game.state.foxes)
    }
}

// MARK: - Earned-bonus banner

/// Advisories for bonuses the player must act on themselves (re-rolls,
/// jokers, extra dice, free "?" marks) — every Clever Cubed bonus is a player
/// choice. Clever 3 twin of `CleverBonusBanner` (that one takes a
/// `CleverGame`); shared by the overview boards, the list and the editor.
struct C3BonusBanner: View {
    @ObservedObject var game: Clever3Game

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

// MARK: - Bonus badges (printed bonus circles)

/// A bonus printed on the Clever Cubed sheet, as DRAWN (the engine's
/// advisory model is `C3Bonus` in `Clever3Models.swift`): the three actions
/// (re-roll circle-arrows, "+1" extra die, "?"-die number joker), the fox,
/// and the "?" free-value marks (`nil` area = the black any-colour "?").
enum C3BonusIcon: Equatable {
    case reroll
    case extraDie
    case joker
    case fox
    case pick(Clever3Area?)
}

/// Clever 3 twin of `BonusBadge` (that one takes a `CleverGame`) — identical
/// chrome: circle fill, thin white rim, glyph.
struct C3BonusBadge: View {
    let icon: C3BonusIcon
    @ObservedObject var game: Clever3Game
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
        if case let .pick(.some(area)) = icon { return game.color(area).color }
        return cleverInk
    }

    @ViewBuilder private var content: some View {
        switch icon {
        case .reroll:
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(.white)
        case .extraDie:
            Text("+1")
                .font(.system(size: size * 0.45, weight: .black))
                .foregroundStyle(.white)
        case .joker:
            Image(systemName: "dice")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(.white)
        case .fox:
            Text("🦊").font(.system(size: size * 0.62))
        case let .pick(area):
            Text("?")
                .font(.system(size: size * 0.55, weight: .black))
                .foregroundStyle(area.map { game.color($0).textColor } ?? .white)
        }
    }
}

/// A fixed-size slot for a printed bonus icon (keeps columns aligned when a
/// cell has no bonus).
@MainActor @ViewBuilder
func c3BonusSlot(_ icon: C3BonusIcon?, game: Clever3Game, size: CGFloat) -> some View {
    if let icon {
        C3BonusBadge(icon: icon, game: game, size: size)
            .frame(width: size, height: size)
    } else {
        Color.clear.frame(width: size, height: size)
    }
}
