//
//  CleverV3ScorecardView.swift
//  RollnWrite – Clever
//
//  EXPERIMENTAL third Clever 1 layout ("v3"): a landscape-optimised REFLOW of
//  the printed score sheet, built entirely from the existing sheet pieces.
//
//  Landscape — two columns filling the screen, everything directly tappable
//  (no editor modal):
//  • LEFT (~38% width): the yellow 4×4 panel stacked above the blue panel.
//  • RIGHT: a compact header strip (rounds bar + reroll / +1 tracks), then the
//    three 11-cell rows (green, orange, purple) at LARGE cell size, then the
//    totals strip (y+b+g+o+p+fox = Total).
//  Each column is one `ScaledSheet`: the column is laid out at a fixed design
//  width, stretched vertically toward its slot's aspect, then scaled uniformly
//  to fit — cells fill the slot with no scrolling and no glyph distortion.
//
//  Portrait — falls back to the standard v2 sheet miniature
//  (`CleverSheetBoardView`) unchanged; v3 is a landscape reflow, not a new
//  portrait design.
//
//  Same engine and the SAME persistence key as the regular catalogue entry:
//  the two entries are two lenses on ONE running game.
//

import SwiftUI

// MARK: - Scorecard (scaffold wrapper)

public struct CleverV3ScorecardView: View {
    /// Default persistence key — deliberately shared with the regular
    /// "That's Pretty Clever" entry, so both boards show the same game.
    @StateObject private var game = CleverGame()
    let rules: RulesDocument

    @State private var confirmNewGame = false

    public init(rules: RulesDocument) {
        self.rules = rules
    }

    public var body: some View {
        ScorecardScaffold(
            title: "That's Pretty Clever (v3)",
            rules: rules,
            // Both orientations scale to fit — let the screen rotate freely.
            locksLandscape: false,
            board: { CleverV3BoardView(game: game) },
            headerAccessory: {
                HStack(spacing: 16) {
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
        .tint(Color(red: 0.55, green: 0.28, blue: 0.72))
        .confirmationDialog("Start a new game?", isPresented: $confirmNewGame, titleVisibility: .visible) {
            Button("New game", role: .destructive) { game.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears the scorecard.")
        }
    }
}

// MARK: - Orientation switch

/// Landscape → the two-column reflow; portrait → the v2 sheet miniature.
struct CleverV3BoardView: View {
    @ObservedObject var game: CleverGame

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > geo.size.height {
                CleverV3LandscapeBoard(game: game)
            } else {
                // The v2 board carries its own bonus banner, editor sheet and
                // value-entry plumbing — reused unchanged.
                CleverSheetBoardView(game: game)
            }
        }
    }
}

// MARK: - Landscape reflow (two columns)

struct CleverV3LandscapeBoard: View {
    @ObservedObject var game: CleverGame
    /// Observed so an open board recolours when Settings changes the palette.
    @ObservedObject private var diceTheme = DiceTheme.shared
    @State private var entry: ValueEntry?

    // Design-space constants (pre-scale points). Each column is laid out at a
    // fixed natural width; its `ScaledSheet` stretches heights toward the
    // slot's aspect and then scales the whole column uniformly to fit.
    private let leftW: CGFloat = 240
    private let rightW: CGFloat = 560
    private let panelCell: CGFloat = 36
    private let rowCell: CGFloat = 40

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .top, spacing: 10) {
                ScaledSheet(maxStretch: 1.4) { stretch in leftColumn(stretch) }
                    .frame(width: geo.size.width * 0.38)
                ScaledSheet(maxStretch: 1.6) { stretch in rightColumn(stretch) }
                    .frame(maxWidth: .infinity)
            }
            .padding(12)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cleverSheetGrey)
                    .padding(4)
            )
        }
        .overlay(alignment: .top) {
            CleverBonusBanner(game: game)
                .padding(.horizontal, 12)
        }
        .cleverValueEntry($entry)
    }

    // MARK: Left column — yellow above blue

    private func leftColumn(_ stretch: CGFloat) -> some View {
        VStack(spacing: 10 * stretch) {
            panel(.yellow, stretch) {
                CleverYellowGrid(game: game, cell: panelCell, stretch: stretch)
            }
            panel(.blue, stretch) {
                CleverBluePanel(game: game, cell: panelCell - 2, stretch: stretch)
            }
        }
        .frame(width: leftW)
    }

    // MARK: Right column — header strip, three big rows, totals

    private func rightColumn(_ stretch: CGFloat) -> some View {
        VStack(spacing: 10 * stretch) {
            headerStrip(stretch)
            rowBand(.green, stretch) {
                CleverGreenRow(game: game, cell: rowCell, stretch: stretch)
            }
            rowBand(.orange, stretch) {
                CleverOrangeRow(game: game, cell: rowCell, stretch: stretch) { entry = $0 }
            }
            rowBand(.purple, stretch) {
                CleverPurpleRow(game: game, cell: rowCell, stretch: stretch) { entry = $0 }
            }
            cleverTotalStrip(game: game, height: 44 * min(stretch, 1.25))
        }
        .frame(width: rightW)
    }

    /// Rounds bar 1–6 with the reroll and +1 circle tracks tightly stacked
    /// beside it — one compact strip, all directly tappable.
    private func headerStrip(_ stretch: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 12) {
            SheetRoundsBar(rounds: 6, darkFrom: 4, cell: 26, ink: cleverInk, stretch: stretch) { r in
                cleverRoundBadge(r, game: game, size: 15)
            }
            VStack(spacing: 4 * stretch) {
                SheetCircleTrack(slots: CleverLayout.rerollTrackSlots,
                                 used: game.state.rerollUsed,
                                 diameter: 15, ink: cleverInk, stretch: stretch,
                                 icon: { BonusBadge(icon: .reroll, game: game, size: 19) },
                                 tap: { game.toggleReroll($0) })
                SheetCircleTrack(slots: CleverLayout.extraDieTrackSlots,
                                 used: game.state.extraDieUsed,
                                 diameter: 15, ink: cleverInk, stretch: stretch,
                                 icon: { BonusBadge(icon: .plusOne, game: game, size: 19) },
                                 tap: { game.toggleExtraDie($0) })
            }
            // Hug the tracks so the (flexible) rounds bar takes the slack.
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    // MARK: Area containers (direct interaction — no editor to open)

    private func panel<Content: View>(
        _ area: CleverArea, _ stretch: CGFloat, @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, 10)
            .padding(.vertical, 10 * stretch)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(game.color(area).color)
            )
    }

    private func rowBand<Content: View>(
        _ area: CleverArea, _ stretch: CGFloat, @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white)
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8 * stretch)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(game.color(area).color)
        )
    }
}
