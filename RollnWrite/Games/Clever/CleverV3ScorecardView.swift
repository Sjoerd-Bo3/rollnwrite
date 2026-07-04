//
//  CleverV3ScorecardView.swift
//  RollnWrite – Clever
//
//  The CANONICAL Clever board ("v3" — the owner's verdict from the on-device
//  three-layout comparison): a landscape-optimised REFLOW of the printed
//  score sheet, built entirely from the existing sheet pieces, with portrait
//  falling back to the sheet miniature. Hosted by `CleverScorecardView`;
//  Clever 2/3/4 mirror this concept in their own modules.
//
//  Landscape — a rounds rail plus two columns filling the screen, everything
//  directly tappable (no editor modal):
//  • LEFT EDGE: the 1–6 rounds as a narrow VERTICAL rail (numbers upright,
//    the printed bonus badge under each number tile).
//  • LEFT COLUMN (~27% width): the yellow 4×4 panel stacked above blue.
//  • RIGHT: the reroll and +1 tracks side by side (one short strip), then the
//    three 11-cell rows (green, orange, purple) at LARGE cell size, sized so
//    the cells run flush to the band edge. No totals strip here — scoring is
//    only interesting at game end (owner call); per-area scores stay visible
//    in the portrait sheet and the editor.
//  Each piece is one `ScaledSheet`: laid out at a fixed design width,
//  stretched vertically toward its slot's aspect, then scaled uniformly to
//  fit — cells fill the slot with no scrolling and no glyph distortion.
//
//  Portrait — falls back to the standard v2 sheet miniature
//  (`CleverSheetBoardView`) unchanged; v3 is a landscape reflow, not a new
//  portrait design.
//
//

import SwiftUI

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

    // Design-space constants (pre-scale points). Each piece is laid out at a
    // fixed natural width; its `ScaledSheet` stretches heights toward the
    // slot's aspect and then scales the whole piece uniformly to fit.
    private let railW: CGFloat = 46
    private let leftW: CGFloat = 240
    private let rightW: CGFloat = 560
    private let panelCell: CGFloat = 36
    /// Width available to a row band's CELLS: the column width minus the
    /// band's padding (2×8), the fixed-width chevron (14) and its spacing (6).
    /// Cell sizes derive from it so the 11th cell ends flush with the band.
    private var bandContentW: CGFloat { rightW - 16 - 14 - 6 }
    /// Green/orange rows: 11 cells + 10 gaps of 0.1×cell = 12 cell widths.
    private var rowCell: CGFloat { bandContentW / 12 }
    /// Purple row: 11 cells + 10 "<" separators of 0.24×cell = 13.4 widths.
    private var purpleRowCell: CGFloat { bandContentW / 13.4 }

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .top, spacing: 10) {
                // Trailing-anchored: when the rail's fit is height-bound the
                // width slack lands at the OUTER screen edge, so the gutter
                // between the rail and the yellow panel stays exactly the
                // standard 10 pt inter-panel gap.
                ScaledSheet(maxStretch: 1.5, anchor: .topTrailing) { stretch in roundsRail(stretch) }
                    .frame(width: 52)
                ScaledSheet(maxStretch: 1.4, anchor: .topLeading) { stretch in leftColumn(stretch) }
                    .frame(width: geo.size.width * 0.27)
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
        .cleverValueEntry($entry)
    }

    // MARK: Rounds rail — the 1–6 rounds as a vertical left-edge column

    /// Vertical counterpart of `SheetRoundsBar`: one dark tile per round with
    /// an upright number and the printed bonus badge underneath. Tiles are
    /// crossable (bookkeeping only — never a game move); crossing rounds 1–3
    /// feeds the reroll/+1 earned counts.
    private func roundsRail(_ stretch: CGFloat) -> some View {
        // Equal vertical rhythm: every tile is number tile + one identical
        // 18×18 badge slot (`cleverRoundBadge` frames every branch — badge,
        // player icon, or round 4's empty spacer — to the same box), with the
        // same paddings, so all six rail tiles share one height.
        VStack(spacing: 6 * stretch) {
            ForEach(0..<6, id: \.self) { r in
                VStack(spacing: 4 * stretch) {
                    Button { game.toggleRound(r) } label: {
                        ZStack {
                            // 0.2 × tile width — the shared cell radius.
                            RoundedRectangle(cornerRadius: (railW - 12) * 0.2, style: .continuous)
                                .fill(Color.white)
                            Text("\(r + 1)")
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                                .foregroundStyle(cleverInk)
                            if game.state.roundsCrossed.contains(r) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundStyle(cleverInk.opacity(0.88))
                                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                            }
                        }
                        .frame(width: railW - 12, height: 30 * stretch)
                        .animation(.spring(response: 0.26, dampingFraction: 0.6),
                                   value: game.state.roundsCrossed.contains(r))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Round \(r + 1)"))
                    .accessibilityValue(game.state.roundsCrossed.contains(r) ? "marked" : "available")
                    cleverRoundBadge(r, game: game, size: 18)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6 * stretch)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: SheetRadius.pill, style: .continuous)
                        .fill(r >= game.roundsBarDarkFrom ? Color.black : Color(white: 0.3))
                )
            }
        }
        .frame(width: railW)
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

    // MARK: Right column — reroll/+1 tracks, then three big rows

    private func rightColumn(_ stretch: CGFloat) -> some View {
        VStack(spacing: 10 * stretch) {
            tracksRow(stretch)
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
            // No totals strip in landscape (owner call): scoring only matters
            // at game end, and the freed height goes to the three rows.
        }
        .frame(width: rightW)
    }

    /// The reroll and +1 circle tracks side by side — one short strip where
    /// the rounds bar used to sit, both directly tappable.
    private func tracksRow(_ stretch: CGFloat) -> some View {
        HStack(spacing: 10) {
            SheetCircleTrack(slots: CleverLayout.rerollTrackSlots,
                             used: game.state.rerollUsed,
                             earned: game.rerollsEarned,
                             diameter: 19, ink: cleverInk, stretch: stretch,
                             icon: { BonusBadge(icon: .reroll, game: game, size: 24) },
                             tap: { game.toggleReroll($0) })
                .cleverFlyDest(.reroll)
            SheetCircleTrack(slots: CleverLayout.extraDieTrackSlots,
                             used: game.state.extraDieUsed,
                             earned: game.extraDiceEarned,
                             diameter: 19, ink: cleverInk, stretch: stretch,
                             icon: { BonusBadge(icon: .plusOne, game: game, size: 24) },
                             tap: { game.toggleExtraDie($0) })
                .cleverFlyDest(.extraDie)
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
                RoundedRectangle(cornerRadius: SheetRadius.panel, style: .continuous)
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
