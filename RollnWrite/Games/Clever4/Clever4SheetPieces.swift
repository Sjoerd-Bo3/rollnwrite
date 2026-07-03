//
//  Clever4SheetPieces.swift
//  RollnWrite – Clever4
//
//  The "printed sheet" area pieces for the Clever 4ever scorecard, built from
//  the game-agnostic sheet library (`CleverSheetComponents.swift`). Each piece
//  renders one area of the OFFICIAL Clever 4ever score sheet (art. 49424) as a
//  faithful, directly-interactive miniature; the boards in
//  `Clever4ScorecardView.swift` compose them at different cell sizes
//  (sheet miniature / landscape reflow / list cards / editor pages).
//
//  Spatial layout transcribed from the official Schmidt Spiele rulebook
//  (49424_Clever_4ever_DE.pdf, "DIE FARBBEREICHE" schematic on p. 4 and the
//  per-area pages 5–9): yellow (top-left) beside blue (top-right), then the
//  full-width grey, green and pink bands. All grid numbers/values come from
//  `Clever4Layout` (the transcription source of truth).
//

import SwiftUI

// MARK: - Printed fox badges
//
// The `Clever4Layout` bonus maps deliberately OMIT the printed foxes (foxes
// are the manual stepper, and listing them would double-count against it).
// For a faithful sheet they must still be PRINTED — these are the positions
// read from the official sheet, used for display only.
enum C4PrintedFox {
    static let yellowTopCol = 4
    static let blueRow = 5
    static let greenField = 9
    static let pinkField = 7
}

// MARK: - Bonus badge (printed bonus circles)

/// Clever 4ever's printed bonus circle — the Clever 4 counterpart of
/// Clever 1's `BonusBadge` (which takes a `CleverGame`), matching its look.
struct C4Badge: View {
    let bonus: C4Bonus
    @ObservedObject var game: Clever4Game
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
        case .reroll, .plusOne, .fox: return cleverInk
        case .extraDie: return Color(white: 0.45)
        case let .pick(a): return game.color(a).color
        }
    }

    @ViewBuilder private var content: some View {
        switch bonus {
        case .reroll:
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(.white)
        case .plusOne:
            Text(verbatim: "+1")
                .font(.system(size: size * 0.45, weight: .black))
                .foregroundStyle(.white)
        case .extraDie:
            // The printed "○" — use the extra (white) die.
            Circle()
                .fill(.white)
                .frame(width: size * 0.45, height: size * 0.45)
        case .fox:
            Text(verbatim: "🦊").font(.system(size: size * 0.62))
        case let .pick(a):
            Text(verbatim: "?")
                .font(.system(size: size * 0.55, weight: .black))
                .foregroundStyle(game.color(a).textColor)
        }
    }
}

/// A fixed-size slot for a printed bonus icon (keeps columns aligned when a
/// cell has no bonus) — mirrors Clever 1's `cleverBonusSlot`.
@MainActor @ViewBuilder
func c4BonusSlot(_ bonus: C4Bonus?, game: Clever4Game, size: CGFloat) -> some View {
    if let bonus {
        C4Badge(bonus: bonus, game: game, size: size)
    } else {
        Color.clear.frame(width: size, height: size)
    }
}

// MARK: - Round badges

/// The badge under a round number, as printed on the Clever 4ever round
/// track: rounds 1–4 grant a bonus at the start of the round (re-roll, +1,
/// extra die, black "?" = any colour); rounds 5–6 carry player-count end
/// markers (4 players → 4 rounds; 3 → 5; 1–2 → 6). Every branch occupies the
/// identical `size`×`size` box so round tiles keep equal heights.
@MainActor
func c4RoundBadge(_ round: Int, game: Clever4Game, size: CGFloat) -> some View {
    Group {
        switch round {
        case 0: C4Badge(bonus: .reroll, game: game, size: size)
        case 1: C4Badge(bonus: .plusOne, game: game, size: size)
        case 2: C4Badge(bonus: .extraDie, game: game, size: size)
        case 3:
            // The BLACK "?" — every player picks any colour at round 4's start.
            ZStack {
                Circle().fill(cleverInk)
                Circle().strokeBorder(.white.opacity(0.85), lineWidth: SheetStroke.small)
                Text(verbatim: "?")
                    .font(.system(size: size * 0.55, weight: .black))
                    .foregroundStyle(.white)
            }
        case 4:
            Image(systemName: "person.3.fill")
                .font(.system(size: size * 0.55, weight: .bold))
                .foregroundStyle(.white)
        default:
            Image(systemName: "person.2.fill")
                .font(.system(size: size * 0.6, weight: .bold))
                .foregroundStyle(.white)
        }
    }
    .frame(width: size, height: size)
}

// MARK: - Text seal

/// A starburst seal with arbitrary TEXT — the string sibling of
/// `SheetPointsBadge` (which takes an `Int`), for the yellow −/+ sum seals
/// and the green "×2" point boxes. Same geometry and highlight treatment.
struct C4Seal: View {
    let text: String
    let tint: Color
    var size: CGFloat = 22
    var highlighted: Bool = false

    var body: some View {
        ZStack {
            Image(systemName: "seal.fill")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(highlighted ? Color.black : Color.white)
            Text(verbatim: text)
                .font(.system(size: size * 0.38, weight: .heavy, design: .rounded))
                .foregroundStyle(highlighted ? .white : tint)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .frame(width: size * 0.95)
        }
        .frame(width: size * 1.15, height: size * 1.15)
        .animation(.snappy, value: highlighted)
        .animation(.snappy, value: text)
    }
}

// MARK: - Yellow area (3×5 write-in rows + column stars)

/// The yellow area: three write-in rows of five columns — top strictly
/// ascending ("<" separators, closed after a 6), middle negative ("−" before
/// each cell), bottom positive ("+") — with the printed bonus badges on the
/// row dividers, live −/+ sum seals at the row ends, and the 10/10/15/15/20
/// column stars underneath.
///
/// Natural width (design points): 14 (arrow) + 5×(0.22c sign + c cell)
/// + 6 inter-item gaps of 0.1c + 0.95c seal slot = 14 + 7.65c.
struct C4YellowPanel: View {
    @ObservedObject var game: Clever4Game
    @ObservedObject var diceTheme = DiceTheme.shared
    let cell: CGFloat
    var stretch: CGFloat = 1
    let requestEntry: (ValueEntry) -> Void

    init(game: Clever4Game, cell: CGFloat, stretch: CGFloat = 1,
         requestEntry: @escaping (ValueEntry) -> Void) {
        self.game = game
        self.cell = cell
        self.stretch = stretch
        self.requestEntry = requestEntry
    }

    private var gap: CGFloat { cell * 0.1 }
    private var signW: CGFloat { cell * 0.22 }
    private var cellH: CGFloat { cell * stretch }
    private var sealSlotW: CGFloat { cell * 0.95 }

    var body: some View {
        let tint = game.color(.yellow)
        VStack(spacing: cell * 0.08 * stretch) {
            row(.top, values: game.state.yellowTop, tint: tint,
                entryTitle: "Yellow top row (ascending)")
            badgeStrip { c in
                Clever4Layout.yellowTopColBonus[c]
                    ?? (c == C4PrintedFox.yellowTopCol ? .fox : nil)
            }
            row(.middle, values: game.state.yellowMiddle, tint: tint,
                entryTitle: "Yellow middle row (negative)")
            badgeStrip { c in Clever4Layout.yellowMidColBonus[c] }
            row(.bottom, values: game.state.yellowBottom, tint: tint,
                entryTitle: "Yellow bottom row (positive)")
            starsRow(tint)
        }
    }

    private func sign(_ row: Clever4Game.YellowRow, _ col: Int) -> String {
        switch row {
        case .top:    return col > 0 ? "<" : ""
        case .middle: return "−"
        case .bottom: return "+"
        }
    }

    private func row(_ r: Clever4Game.YellowRow, values: [Int?], tint: DiceColor,
                     entryTitle: String) -> some View {
        let next = game.yellowNext(r)
        let allowed = game.allowedYellow(r)
        let last = values.lastIndex(where: { $0 != nil })
        return HStack(alignment: .center, spacing: gap) {
            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(tint.textColor)
                .frame(width: 14) // fixed so the natural-width derivation is exact
            ForEach(0..<Clever4Layout.yellowCols, id: \.self) { c in
                HStack(spacing: 0) {
                    Text(verbatim: sign(r, c))
                        .font(.system(size: cell * 0.34, weight: .black, design: .rounded))
                        .foregroundStyle(tint.textColor)
                        .frame(width: signW, height: cellH)
                    let undoable = last == c && values[c] != nil
                    SheetWriteCell(
                        value: values[c],
                        tint: tint.color,
                        ink: cleverInk,
                        isNext: next == c && !allowed.isEmpty,
                        undoable: undoable,
                        size: cell,
                        height: cellH
                    ) {
                        if undoable {
                            game.clearLastYellow(r)
                        } else {
                            requestEntry(ValueEntry(title: entryTitle, allowed: allowed) {
                                game.fillYellow(r, $0)
                            })
                        }
                    }
                }
            }
            sumSeal(r, values: values, tint: tint)
        }
    }

    /// The row-end seal: middle → live "−sum", bottom → live "+sum"
    /// (highlighted once the row is full); top → an empty slot of the same
    /// width so all three rows share one cell grid.
    @ViewBuilder
    private func sumSeal(_ r: Clever4Game.YellowRow, values: [Int?], tint: DiceColor) -> some View {
        let sum = values.compactMap { $0 }.reduce(0, +)
        let full = values.allSatisfy { $0 != nil }
        switch r {
        case .top:
            Color.clear.frame(width: sealSlotW, height: 1)
        case .middle:
            C4Seal(text: "−\(sum)", tint: tint.color, size: cell * 0.72, highlighted: full)
                .frame(width: sealSlotW)
        case .bottom:
            C4Seal(text: "+\(sum)", tint: tint.color, size: cell * 0.72, highlighted: full)
                .frame(width: sealSlotW)
        }
    }

    /// A thin badge row on a divider, badges centred under their columns —
    /// same slot rhythm (sign + cell) as the write rows, so columns align.
    private func badgeStrip(_ bonus: @escaping (Int) -> C4Bonus?) -> some View {
        HStack(alignment: .center, spacing: gap) {
            Color.clear.frame(width: 14, height: 1)
            ForEach(0..<Clever4Layout.yellowCols, id: \.self) { c in
                HStack(spacing: 0) {
                    Color.clear.frame(width: signW, height: 1)
                    c4BonusSlot(bonus(c), game: game, size: cell * 0.5)
                        .frame(width: cell)
                }
            }
            Color.clear.frame(width: sealSlotW, height: 1)
        }
    }

    /// The printed 10/10/15/15/20 column stars, each highlighted once its
    /// column (all three rows) is filled.
    private func starsRow(_ tint: DiceColor) -> some View {
        HStack(alignment: .center, spacing: gap) {
            Color.clear.frame(width: 14, height: 1)
            ForEach(0..<Clever4Layout.yellowCols, id: \.self) { c in
                HStack(spacing: 0) {
                    Color.clear.frame(width: signW, height: 1)
                    let done = game.state.yellowTop[c] != nil
                        && game.state.yellowMiddle[c] != nil
                        && game.state.yellowBottom[c] != nil
                    SheetPointsBadge(value: Clever4Layout.yellowColumnStars[c],
                                     tint: tint.color, size: cell * 0.72, highlighted: done)
                        .frame(width: cell)
                }
            }
            Color.clear.frame(width: sealSlotW, height: 1)
        }
        .padding(.vertical, cell * 0.05)
        .background(Capsule().fill(.white.opacity(0.4)))
    }
}

// MARK: - Blue area (6×6 grid, row labels, row bonuses, column seals)

/// The blue area: row-label tiles 1–6 (the blue die) beside a 6×6 grid of
/// cells labelled 1–6 (the white die), the printed row-end bonus badges, the
/// dashed TR→BL scoring diagonal, and the seal row underneath — the
/// diagonal's "6" seal (bottom-left), the 7…12 column seals, and the printed
/// re-roll badge of the other diagonal at the right end.
///
/// Natural width (design points): c label + 6c cells + 0.9c badge slot
/// + 7 gaps of 0.1c = 8.6c.
struct C4BluePanel: View {
    @ObservedObject var game: Clever4Game
    @ObservedObject var diceTheme = DiceTheme.shared
    let cell: CGFloat
    var stretch: CGFloat = 1

    private var gap: CGFloat { cell * 0.1 }
    private var cellH: CGFloat { cell * stretch }
    private var badgeSlotW: CGFloat { cell * 0.9 }

    var body: some View {
        let tint = game.color(.blue)
        VStack(spacing: gap * stretch) {
            HStack(alignment: .top, spacing: gap) {
                labelColumn(tint)
                grid(tint)
                badgeColumn
            }
            sealRow(tint)
        }
    }

    private func labelColumn(_ tint: DiceColor) -> some View {
        VStack(spacing: gap * stretch) {
            ForEach(0..<Clever4Layout.blueRows, id: \.self) { r in
                ZStack {
                    RoundedRectangle(cornerRadius: cell * 0.2, style: .continuous)
                        .fill(.black.opacity(0.32))
                    Text(verbatim: "\(r + 1)")
                        .font(.system(size: cell * 0.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: cell, height: cellH)
            }
        }
    }

    private func grid(_ tint: DiceColor) -> some View {
        VStack(spacing: gap * stretch) {
            ForEach(0..<Clever4Layout.blueRows, id: \.self) { r in
                HStack(spacing: gap) {
                    ForEach(0..<Clever4Layout.blueCols, id: \.self) { c in
                        let idx = r * Clever4Layout.blueCols + c
                        SheetCell(
                            label: "\(c + 1)",
                            tint: tint.color,
                            ink: cleverInk,
                            marked: game.state.blue.contains(idx),
                            legal: true, // free toggling — the engine allows uncrossing
                            size: cell,
                            height: cellH
                        ) {
                            game.toggleBlue(idx)
                        }
                    }
                }
            }
        }
        .overlay {
            // The printed TR→BL scoring diagonal (+6 at ≥2 crosses).
            C4DiagonalTRBL()
                .stroke(style: StrokeStyle(lineWidth: SheetStroke.medium, lineCap: .round,
                                           dash: [cell * 0.14, cell * 0.12]))
                .foregroundStyle(.black.opacity(0.4))
                .allowsHitTesting(false)
        }
    }

    private var badgeColumn: some View {
        VStack(spacing: gap * stretch) {
            ForEach(0..<Clever4Layout.blueRows, id: \.self) { r in
                c4BonusSlot(Clever4Layout.blueRowBonus[r]
                                ?? (r == C4PrintedFox.blueRow ? .fox : nil),
                            game: game, size: cell * 0.62)
                    .frame(width: badgeSlotW, height: cellH)
            }
        }
    }

    private func columnCount(_ c: Int) -> Int {
        (0..<Clever4Layout.blueRows).reduce(0) {
            $0 + (game.state.blue.contains($1 * Clever4Layout.blueCols + c) ? 1 : 0)
        }
    }

    private var diagonalCount: Int {
        (0..<Clever4Layout.blueRows).reduce(0) {
            $0 + (game.state.blue.contains($1 * Clever4Layout.blueCols
                                           + (Clever4Layout.blueCols - 1 - $1)) ? 1 : 0)
        }
    }

    /// Under the grid: the TR→BL diagonal's "6" seal sits under the label
    /// column (where the diagonal ends), the 7…12 column seals under their
    /// columns, and the printed re-roll badge under the bonus column.
    private func sealRow(_ tint: DiceColor) -> some View {
        HStack(alignment: .center, spacing: gap) {
            SheetPointsBadge(value: Clever4Layout.blueDiagonalValue, tint: tint.color,
                             size: cell * 0.62, highlighted: diagonalCount >= 2)
                .frame(width: cell)
            ForEach(0..<Clever4Layout.blueCols, id: \.self) { c in
                SheetPointsBadge(value: Clever4Layout.blueColumnValues[c], tint: tint.color,
                                 size: cell * 0.62, highlighted: columnCount(c) >= 2)
                    .frame(width: cell)
            }
            C4Badge(bonus: Clever4Layout.blueDiagonalBonus, game: game, size: cell * 0.55)
                .frame(width: badgeSlotW)
        }
        .padding(.vertical, cell * 0.05)
        .background(Capsule().fill(.white.opacity(0.35)))
    }
}

/// The blue grid's dashed top-right → bottom-left diagonal.
struct C4DiagonalTRBL: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX - rect.width * 0.07, y: rect.minY + rect.height * 0.07))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.07, y: rect.maxY - rect.height * 0.07))
        return p
    }
}

// MARK: - Grey area (4×16 free-crossing grid + column seals)

/// The grey area: the printed 1…11 column values as seals ABOVE a 4×16 grid
/// of freely-crossable cells (the polyomino regions are enforced by the
/// player, as on paper), with the printed in-cell bonus icons.
///
/// Natural width (design points, unsplit): 16c + 15 gaps of 0.1c = 17.5c.
/// `split: true` stacks two 8-column halves (each with its own seal row) for
/// the big editor page and the list card.
struct C4GreyPanel: View {
    @ObservedObject var game: Clever4Game
    @ObservedObject var diceTheme = DiceTheme.shared
    let cell: CGFloat
    var stretch: CGFloat = 1
    var split = false

    private var gap: CGFloat { cell * 0.1 }
    private var cellH: CGFloat { cell * stretch }

    var body: some View {
        let tint = game.color(.grey)
        Group {
            if split {
                VStack(alignment: .leading, spacing: cell * 0.3) {
                    segment(0..<8, tint: tint)
                    segment(8..<Clever4Layout.greyCols, tint: tint)
                }
            } else {
                segment(0..<Clever4Layout.greyCols, tint: tint)
            }
        }
    }

    private func columnFilled(_ c: Int) -> Bool {
        (0..<Clever4Layout.greyRows).allSatisfy {
            game.state.grey.contains($0 * Clever4Layout.greyCols + c)
        }
    }

    private func segment(_ cols: Range<Int>, tint: DiceColor) -> some View {
        VStack(spacing: gap * stretch) {
            HStack(spacing: gap) {
                ForEach(cols, id: \.self) { c in
                    SheetPointsBadge(value: Clever4Layout.greyColumnValues[c],
                                     tint: tint.color, size: cell * 0.55,
                                     highlighted: columnFilled(c))
                        .frame(width: cell)
                }
            }
            ForEach(0..<Clever4Layout.greyRows, id: \.self) { r in
                HStack(spacing: gap) {
                    ForEach(cols, id: \.self) { c in
                        cellView(r, c, tint: tint)
                    }
                }
            }
        }
    }

    private func cellView(_ r: Int, _ c: Int, tint: DiceColor) -> some View {
        let idx = r * Clever4Layout.greyCols + c
        let crossed = game.state.grey.contains(idx)
        return ZStack {
            SheetCell(
                label: "",
                tint: tint.color,
                ink: cleverInk,
                marked: crossed,
                legal: true, // free toggling — the engine allows uncrossing
                size: cell,
                height: cellH
            ) {
                game.toggleGrey(idx)
            }
            // Printed in-cell bonus icon; fades under the ink cross.
            if let bonus = Clever4Layout.greyCellBonus[GridPos(r, c)] {
                C4Badge(bonus: bonus, game: game, size: cell * 0.55)
                    .opacity(crossed ? 0.35 : 1)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Green area (11 split fields, ×2 from the 4th)

/// The green area: eleven fields, each split by the printed "/" diagonal into
/// an upper (top-left) and lower (bottom-right) triangle, filled left→right
/// per "row" of triangles. The point seal above each field shows the live sum
/// (doubled from the 4th field, whose seals print "×2"); the printed bonus
/// badge sits under each field.
///
/// Natural width (design points, unsplit): 11c + 10 gaps of 0.1c = 12c.
struct C4GreenBand: View {
    @ObservedObject var game: Clever4Game
    @ObservedObject var diceTheme = DiceTheme.shared
    let cell: CGFloat
    var stretch: CGFloat = 1
    var split = false
    let requestEntry: (ValueEntry) -> Void

    init(game: Clever4Game, cell: CGFloat, stretch: CGFloat = 1, split: Bool = false,
         requestEntry: @escaping (ValueEntry) -> Void) {
        self.game = game
        self.cell = cell
        self.stretch = stretch
        self.split = split
        self.requestEntry = requestEntry
    }

    var body: some View {
        let tint = game.color(.green)
        Group {
            if split {
                VStack(alignment: .leading, spacing: cell * 0.3) {
                    segment(0..<6, tint: tint)
                    segment(6..<Clever4Layout.greenFields, tint: tint)
                }
            } else {
                segment(0..<Clever4Layout.greenFields, tint: tint)
            }
        }
    }

    private func segment(_ range: Range<Int>, tint: DiceColor) -> some View {
        let topNext = game.greenTopNext()
        let botNext = game.greenBottomNext()
        let topLast = game.state.greenTop.lastIndex(where: { $0 != nil })
        let botLast = game.state.greenBottom.lastIndex(where: { $0 != nil })
        return HStack(alignment: .top, spacing: cell * 0.1) {
            ForEach(range, id: \.self) { i in
                VStack(spacing: cell * 0.06 * stretch) {
                    seal(i, tint: tint)
                    C4GreenField(
                        top: game.state.greenTop[i],
                        bottom: game.state.greenBottom[i],
                        topNext: topNext == i,
                        bottomNext: botNext == i,
                        topLast: topLast == i && game.state.greenTop[i] != nil,
                        bottomLast: botLast == i && game.state.greenBottom[i] != nil,
                        tint: tint.color,
                        size: cell,
                        height: cell * stretch,
                        tapTop: {
                            if topLast == i && game.state.greenTop[i] != nil {
                                game.clearLastGreenTop()
                            } else if topNext == i {
                                requestEntry(ValueEntry(title: "Green top value",
                                                        allowed: Array(1...6)) {
                                    game.fillGreenTop($0)
                                })
                            }
                        },
                        tapBottom: {
                            if botLast == i && game.state.greenBottom[i] != nil {
                                game.clearLastGreenBottom()
                            } else if botNext == i {
                                requestEntry(ValueEntry(title: "Green bottom value",
                                                        allowed: Array(1...6)) {
                                    game.fillGreenBottom($0)
                                })
                            }
                        }
                    )
                    c4BonusSlot(Clever4Layout.greenFieldBonus[i]
                                    ?? (i == C4PrintedFox.greenField ? .fox : nil),
                                game: game, size: cell * 0.5)
                }
            }
        }
    }

    /// The point seal above a field: the live sum once both triangles are
    /// filled (highlighted); otherwise the printed "×2" from the 4th field.
    @ViewBuilder private func seal(_ i: Int, tint: DiceColor) -> some View {
        let score = game.greenFieldScore(i)
        if score > 0 {
            SheetPointsBadge(value: score, tint: tint.color, size: cell * 0.6, highlighted: true)
        } else {
            C4Seal(text: i >= Clever4Layout.greenDoubleFromIndex ? "×2" : "",
                   tint: tint.color, size: cell * 0.6)
        }
    }
}

/// One green field: a white tile split by the printed "/" diagonal — upper
/// triangle top-left, lower triangle bottom-right. The top half of the tile
/// taps the upper triangle, the bottom half the lower one; a dashed circle
/// marks the next writable triangle, an ink ring the tap-undoable last entry.
struct C4GreenField: View {
    let top: Int?
    let bottom: Int?
    let topNext: Bool
    let bottomNext: Bool
    let topLast: Bool
    let bottomLast: Bool
    let tint: Color
    let size: CGFloat
    var height: CGFloat? = nil
    let tapTop: () -> Void
    let tapBottom: () -> Void

    private var h: CGFloat { height ?? size }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .fill(Color.white)
            C4FieldDiagonal()
                .stroke(tint.opacity(0.7), lineWidth: SheetStroke.small)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
                .allowsHitTesting(false)
            corner(top, next: topNext, last: topLast)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(size * 0.09)
            corner(bottom, next: bottomNext, last: bottomLast)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(size * 0.09)
            VStack(spacing: 0) {
                Button(action: tapTop) { Color.clear.contentShape(Rectangle()) }
                    .buttonStyle(.plain)
                    .disabled(!(topNext || topLast))
                    .accessibilityLabel("Green top value")
                    .accessibilityValue(top.map { "\($0)" } ?? (topNext ? "available" : "blocked"))
                Button(action: tapBottom) { Color.clear.contentShape(Rectangle()) }
                    .buttonStyle(.plain)
                    .disabled(!(bottomNext || bottomLast))
                    .accessibilityLabel("Green bottom value")
                    .accessibilityValue(bottom.map { "\($0)" } ?? (bottomNext ? "available" : "blocked"))
            }
        }
        .frame(width: size, height: h)
        .opacity(top != nil || bottom != nil || topNext || bottomNext ? 1 : 0.55)
        .animation(.snappy, value: top)
        .animation(.snappy, value: bottom)
    }

    @ViewBuilder private func corner(_ value: Int?, next: Bool, last: Bool) -> some View {
        if let value {
            Text(verbatim: "\(value)")
                .font(.system(size: size * 0.32, weight: .heavy, design: .rounded))
                .foregroundStyle(cleverInk)
                .frame(width: size * 0.38, height: size * 0.38)
                .overlay {
                    if last {
                        Circle().strokeBorder(cleverInk, lineWidth: SheetStroke.small)
                    }
                }
        } else if next {
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: SheetStroke.small,
                                                 dash: [size * 0.08, size * 0.06]))
                .foregroundStyle(tint)
                .frame(width: size * 0.34, height: size * 0.34)
        } else {
            Color.clear.frame(width: size * 0.34, height: size * 0.34)
        }
    }
}

/// The green field's printed "/" diagonal (bottom-left → top-right).
struct C4FieldDiagonal: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

// MARK: - Pink area (12-field bar, values above, circled 2/4/6)

/// The pink area: one bar of twelve write-in fields (left→right, no skips),
/// the cumulative 2…42 point seals above (the last written field's seal is
/// highlighted — that is the live base score), the printed bonus badges
/// below, and the printed 2/4/6 extra-points legend. Written 2s, 4s and 6s
/// are circled, as the rules require.
///
/// Natural width (design points, unsplit): 12c + 11 gaps of 0.1c = 13.1c.
struct C4PinkBand: View {
    @ObservedObject var game: Clever4Game
    @ObservedObject var diceTheme = DiceTheme.shared
    let cell: CGFloat
    var stretch: CGFloat = 1
    var split = false
    let requestEntry: (ValueEntry) -> Void

    init(game: Clever4Game, cell: CGFloat, stretch: CGFloat = 1, split: Bool = false,
         requestEntry: @escaping (ValueEntry) -> Void) {
        self.game = game
        self.cell = cell
        self.stretch = stretch
        self.split = split
        self.requestEntry = requestEntry
    }

    var body: some View {
        let tint = game.color(.pink)
        VStack(alignment: .leading, spacing: cell * 0.08 * stretch) {
            if split {
                segment(0..<6, tint: tint)
                segment(6..<Clever4Layout.pinkFields, tint: tint)
            } else {
                segment(0..<Clever4Layout.pinkFields, tint: tint)
            }
            // The printed extra-points legend under the bar.
            Text(verbatim: "2 = +2   ·   4 = +4   ·   6 = +3")
                .font(.system(size: cell * 0.24, weight: .bold, design: .rounded))
                .foregroundStyle(tint.textColor.opacity(0.85))
        }
    }

    private func segment(_ range: Range<Int>, tint: DiceColor) -> some View {
        let next = game.pinkNext()
        let last = game.state.pink.lastIndex(where: { $0 != nil })
        return HStack(alignment: .top, spacing: cell * 0.1) {
            ForEach(range, id: \.self) { i in
                let value = game.state.pink[i]
                let undoable = last == i && value != nil
                VStack(spacing: cell * 0.06 * stretch) {
                    SheetPointsBadge(value: Clever4Layout.pinkValues[i], tint: tint.color,
                                     size: cell * 0.55, highlighted: last == i)
                    SheetWriteCell(
                        value: value,
                        tint: tint.color,
                        ink: cleverInk,
                        isNext: next == i,
                        undoable: undoable,
                        size: cell,
                        height: cell * stretch
                    ) {
                        if undoable {
                            game.clearLastPink()
                        } else {
                            requestEntry(ValueEntry(title: "Pink value", allowed: Array(1...6)) {
                                game.fillPink($0)
                            })
                        }
                    }
                    .overlay {
                        // Circle the written 2s/4s/6s, as printed play requires.
                        if let value, Clever4Layout.pinkBonuses[value] != nil {
                            Circle()
                                .strokeBorder(cleverInk.opacity(0.7), lineWidth: SheetStroke.small)
                                .frame(width: cell * 0.6, height: cell * 0.6)
                                .allowsHitTesting(false)
                        }
                    }
                    c4BonusSlot(Clever4Layout.pinkFieldBonus[i]
                                    ?? (i == C4PrintedFox.pinkField ? .fox : nil),
                                game: game, size: cell * 0.5)
                }
            }
        }
    }
}

// MARK: - Fox stepper

/// The manual fox counter (Clever 4ever's fox triggers are printed bonuses,
/// so the count is the player's to keep — Clever 2/3 precedent). Styled like
/// the sheet's grey chrome pills.
struct C4FoxStepper: View {
    @ObservedObject var game: Clever4Game
    var diameter: CGFloat = 22
    var stretch: CGFloat = 1

    var body: some View {
        HStack(spacing: diameter * 0.4) {
            Text(verbatim: "🦊")
                .font(.system(size: diameter * 0.85))
            Text(verbatim: "×\(game.state.foxes)")
                .font(.system(size: diameter * 0.62, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(cleverInk)
                .contentTransition(.numericText())
            Button { game.removeFox() } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: diameter * 0.95))
                    .foregroundStyle(cleverInk)
            }
            .buttonStyle(.plain)
            .disabled(game.state.foxes == 0)
            .opacity(game.state.foxes == 0 ? 0.4 : 1)
            .accessibilityLabel("Remove fox")
            Button { game.addFox() } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: diameter * 0.95))
                    .foregroundStyle(cleverInk)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add fox")
        }
        .padding(.horizontal, diameter * 0.45)
        .padding(.vertical, diameter * 0.22 * stretch)
        .background(
            RoundedRectangle(cornerRadius: SheetRadius.pill, style: .continuous)
                .fill(Color(white: 0.62))
        )
        .animation(.snappy, value: game.state.foxes)
    }
}

// MARK: - Total strip

/// The bottom summary strip (per-area scores + foxes + total) — the Clever 4
/// counterpart of Clever 1's `cleverTotalStrip`.
@MainActor
func clever4TotalStrip(game: Clever4Game, height: CGFloat) -> some View {
    var entries: [SheetTotalStrip.Entry] = Clever4Area.allCases.map {
        SheetTotalStrip.Entry(value: "\(game.score(for: $0))", tint: game.color($0).color)
    }
    entries.append(SheetTotalStrip.Entry(value: "\(game.foxScore)",
                                         caption: "🦊×\(game.state.foxes)", tint: .red))
    return SheetTotalStrip(entries: entries, total: game.totalScore,
                           ink: cleverInk, height: height)
}

// MARK: - Earned-bonus banner

/// Advisories for the printed bonuses the player must act on (re-roll / +1 /
/// extra die / "?" picks) — the Clever 4 counterpart of `CleverBonusBanner`
/// (which takes a `CleverGame`), matching its look exactly.
struct C4BonusBanner: View {
    @ObservedObject var game: Clever4Game

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
