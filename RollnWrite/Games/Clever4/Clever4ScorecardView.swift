//
//  Clever4ScorecardView.swift
//  RollnWrite – Clever4
//
//  Interactive, auto-scoring scorecard, styled LIGHT to mirror the official
//  printed "Clever 4ever" score sheet (cream paper, white tiles, dark text and
//  the official area colours) and presented fullscreen in landscape — no system
//  nav bar, a compact in-board header with every control, and GeometryReader
//  sizing so the board fills the width edge-to-edge.
//
//  This board is genuinely the densest in the app (grey is 4×16, plus an
//  11-field green and a 12-field pink bar), so a ScrollView is kept as a
//  fallback — but the areas are laid out in two columns in landscape so most of
//  the card is visible at once. View bodies are intentionally small and each
//  cell is extracted into a private `struct …: View` so the Swift type-checker
//  stays fast.
//

import SwiftUI

public struct Clever4ScorecardView: View {
    @StateObject private var game = Clever4Game()
    /// Observed so an open board recolours when Settings changes the palette.
    @ObservedObject private var diceTheme = DiceTheme.shared
    let rules: RulesDocument

    @Environment(\.dismiss) private var dismiss
    @State private var showRules = false
    @State private var confirmNewGame = false
    @State private var entry: C4Entry?

    private let spacing: CGFloat = 3

    /// Cream "paper" the printed sheet is on, plus a slightly lighter panel for
    /// each area so it reads like a card on a table.
    private let paper = Color(red: 0.97, green: 0.96, blue: 0.92)
    private let panel = Color.white
    private let ink = Color(red: 0.12, green: 0.12, blue: 0.14)

    public init(rules: RulesDocument) { self.rules = rules }

    public var body: some View {
        GeometryReader { geo in
            // Fill the available width edge-to-edge. In landscape the areas sit
            // in two columns, so each column gets ~half the width; the grey
            // 4×16 grid is the column-count driver and gets the full width.
            let landscape = geo.size.width > geo.size.height
            let colCount: CGFloat = landscape ? 2 : 1
            let columnW = (geo.size.width - 24 - (colCount - 1) * 12) / colCount
            // Grey (16 cols) sets the smallest cell; it spans the FULL width.
            let greyCell = max(16, min(40, (geo.size.width - 24 - spacing * 15) / 16))
            // Other areas size to a single column.
            let cell = max(20, min(44, (columnW - spacing * 12) / 13))

            ScrollView {
                VStack(spacing: 12) {
                    summary
                    bonusBanner
                    foxStepper
                    if landscape {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 12) {
                                areaPanel { yellowArea(cell: cell) }
                                areaPanel { greenArea(cell: cell) }
                            }
                            VStack(spacing: 12) {
                                areaPanel { blueArea(cell: cell) }
                                areaPanel { pinkArea(cell: cell) }
                            }
                        }
                        areaPanel { greyArea(cell: greyCell) }
                    } else {
                        areaPanel { yellowArea(cell: cell) }
                        areaPanel { blueArea(cell: cell) }
                        areaPanel { greyArea(cell: greyCell) }
                        areaPanel { greenArea(cell: cell) }
                        areaPanel { pinkArea(cell: cell) }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity)
            }
        }
        .background(paper.ignoresSafeArea())
        .foregroundStyle(ink)
        .tint(game.color(.green).color)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .landscapeLockediPhone(when: true)
        .preferredColorScheme(.light)
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .sheet(isPresented: $showRules) { RulesView(document: rules).preferredColorScheme(.light) }
        .confirmationDialog("Start a new game?", isPresented: $confirmNewGame, titleVisibility: .visible) {
            Button("New game", role: .destructive) { game.reset() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This clears the scorecard.") }
        .confirmationDialog(
            entry?.title ?? "",
            isPresented: Binding(get: { entry != nil }, set: { if !$0 { entry = nil } }),
            titleVisibility: .visible
        ) {
            ForEach(entry?.allowed ?? [], id: \.self) { v in
                Button("\(v)") { entry?.commit(v); entry = nil }
            }
            Button("Cancel", role: .cancel) { entry = nil }
        }
    }

    // MARK: - Header (replaces the system nav bar)

    private var header: some View {
        HStack(spacing: 16) {
            Button { dismiss() } label: { Image(systemName: "chevron.left") }
            Text("Clever 4ever").font(.headline).lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
            Button { showRules = true } label: { Image(systemName: "info.circle") }
            Button(role: .destructive) { confirmNewGame = true } label: { Image(systemName: "trash") }
        }
        .font(.title3)
        .foregroundStyle(ink)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(paper)
    }

    /// A light "card" panel that each area sits on.
    private func areaPanel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.black.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Clever4Area.allCases) { area in
                    ScoreChip(title: area.title, value: "\(game.score(for: area))", tint: game.color(area).color)
                }
                ScoreChip(title: "🦊 ×\(game.state.foxes)", value: "\(game.foxScore)", tint: .gray)
            }
            HStack {
                Text("Foxes score the lowest area (\(game.lowestAreaScore)) each").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("Total").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Text("\(game.totalScore)").font(.title3.bold().monospacedDigit())
            }
        }
    }

    @ViewBuilder private var bonusBanner: some View {
        if !game.earnedBonuses.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "gift.fill").font(.caption).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(game.earnedBonuses.suffix(4).enumerated()), id: \.offset) { _, msg in
                        Text(msg).font(.caption.weight(.medium))
                    }
                }
                Spacer(minLength: 0)
                Button { game.clearEarnedBonuses() } label: {
                    Image(systemName: "xmark.circle.fill").font(.body).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(red: 0.99, green: 0.97, blue: 0.88), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.black.opacity(0.08), lineWidth: 1))
            .frame(maxWidth: .infinity)
        }
    }

    private var foxStepper: some View {
        Stepper(value: Binding(get: { game.state.foxes }, set: { nv in if nv > game.state.foxes { game.addFox() } else { game.removeFox() } }), in: 0...20) {
            Text("🦊 Foxes earned: \(game.state.foxes)").font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(panel, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.black.opacity(0.08), lineWidth: 1))
    }

    private func header(_ area: Clever4Area) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(game.color(area).color).frame(width: 14, height: 14)
            Text(area.title).font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(game.score(for: area)) pts").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    // MARK: - Yellow

    private func yellowArea(cell: CGFloat) -> some View {
        let tint = game.color(.yellow)
        return VStack(alignment: .leading, spacing: 3) {
            header(.yellow)
            yellowRow(.top, label: "▲ ascending (0 pts)", values: game.state.yellowTop, cell: cell, tint: tint)
            yellowRow(.middle, label: "− negative", values: game.state.yellowMiddle, cell: cell, tint: tint)
            yellowRow(.bottom, label: "+ positive", values: game.state.yellowBottom, cell: cell, tint: tint)
            HStack(spacing: spacing) {
                Text("col:").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary).frame(width: cell)
                ForEach(0..<Clever4Layout.yellowCols, id: \.self) { c in
                    Text("\(Clever4Layout.yellowColumnStars[c])")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary).frame(width: cell)
                }
            }
            Text("Each fully-filled column scores its star. Total = (sum +) − (sum −) + columns.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func yellowRow(_ row: Clever4Game.YellowRow, label: String, values: [Int?], cell: CGFloat, tint: DiceColor) -> some View {
        let next = game.yellowNext(row)
        let last = values.lastIndex(where: { $0 != nil })
        return HStack(spacing: spacing) {
            Text(label).font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
                .frame(width: cell, alignment: .leading).lineLimit(2)
            ForEach(0..<Clever4Layout.yellowCols, id: \.self) { c in
                C4ValueCell(value: values[c], isNext: next == c, isLast: last == c, tint: tint, size: cell) {
                    if next == c {
                        let allowed = game.allowedYellow(row)
                        if !allowed.isEmpty {
                            entry = C4Entry(title: "Yellow value", allowed: allowed) { game.fillYellow(row, $0) }
                        }
                    } else if values[c] != nil && last == c {
                        game.clearLastYellow(row)
                    }
                }
            }
        }
    }

    // MARK: - Blue (6×6 grid)

    private func blueArea(cell: CGFloat) -> some View {
        let tint = game.color(.blue)
        return VStack(alignment: .leading, spacing: 3) {
            header(.blue)
            HStack(spacing: spacing) {
                Text(" ").frame(width: cell)
                ForEach(0..<Clever4Layout.blueCols, id: \.self) { c in
                    Text("\(c + 1)").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).frame(width: cell)
                }
            }
            ForEach(0..<Clever4Layout.blueRows, id: \.self) { r in
                HStack(spacing: spacing) {
                    Text("\(r + 1)").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).frame(width: cell)
                    ForEach(0..<Clever4Layout.blueCols, id: \.self) { c in
                        let idx = r * Clever4Layout.blueCols + c
                        C4MarkCell(label: c + 1, tint: tint, crossed: game.state.blue.contains(idx), size: cell) {
                            game.toggleBlue(idx)
                        }
                    }
                }
            }
            HStack(spacing: spacing) {
                Text("pts:").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary).frame(width: cell)
                ForEach(0..<Clever4Layout.blueCols, id: \.self) { c in
                    Text("\(Clever4Layout.blueColumnValues[c])").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).frame(width: cell)
                }
            }
            Text("Column with ≥2 crosses scores its value. Top-right→bottom-left diagonal with ≥2 scores +6.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Grey (4×16 grid; free crossing)

    private func greyArea(cell: CGFloat) -> some View {
        let tint = game.color(.grey)
        return VStack(alignment: .leading, spacing: 3) {
            header(.grey)
            HStack(spacing: spacing) {
                ForEach(0..<Clever4Layout.greyCols, id: \.self) { c in
                    Text("\(Clever4Layout.greyColumnValues[c])").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary).frame(width: cell)
                }
            }
            ForEach(0..<Clever4Layout.greyRows, id: \.self) { r in
                HStack(spacing: spacing) {
                    ForEach(0..<Clever4Layout.greyCols, id: \.self) { c in
                        let idx = r * Clever4Layout.greyCols + c
                        C4PlainCell(tint: tint, crossed: game.state.grey.contains(idx), size: cell) {
                            game.toggleGrey(idx)
                        }
                    }
                }
            }
            Text("Cross polyomino cells freely. Each fully-crossed column scores the value above it.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Green (11 split fields)

    private func greenArea(cell: CGFloat) -> some View {
        let tint = game.color(.green)
        let topNext = game.greenTopNext()
        let botNext = game.greenBottomNext()
        let topLast = game.state.greenTop.lastIndex(where: { $0 != nil })
        let botLast = game.state.greenBottom.lastIndex(where: { $0 != nil })
        return VStack(alignment: .leading, spacing: 3) {
            header(.green)
            HStack(spacing: spacing) {
                ForEach(0..<Clever4Layout.greenFields, id: \.self) { i in
                    C4GreenCell(
                        top: game.state.greenTop[i],
                        bottom: game.state.greenBottom[i],
                        score: game.greenFieldScore(i),
                        doubled: i >= Clever4Layout.greenDoubleFromIndex,
                        topIsNext: topNext == i,
                        bottomIsNext: botNext == i,
                        topIsLast: topLast == i,
                        bottomIsLast: botLast == i,
                        tint: tint,
                        size: cell,
                        tapTop: {
                            if topNext == i { entry = C4Entry(title: "Green top", allowed: Array(1...6)) { game.fillGreenTop($0) } }
                            else if topLast == i { game.clearLastGreenTop() }
                        },
                        tapBottom: {
                            if botNext == i { entry = C4Entry(title: "Green bottom", allowed: Array(1...6)) { game.fillGreenBottom($0) } }
                            else if botLast == i { game.clearLastGreenBottom() }
                        }
                    )
                }
            }
            Text("Fill both triangles left→right. Field box = top + bottom; doubled from the 4th field (×2).")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Pink (12 fields)

    private func pinkArea(cell: CGFloat) -> some View {
        let tint = game.color(.pink)
        let next = game.pinkNext()
        let last = game.state.pink.lastIndex(where: { $0 != nil })
        return VStack(alignment: .leading, spacing: 3) {
            header(.pink)
            HStack(spacing: spacing) {
                ForEach(0..<Clever4Layout.pinkFields, id: \.self) { i in
                    VStack(spacing: 1) {
                        Text("\(Clever4Layout.pinkValues[i])").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
                        C4ValueCell(value: game.state.pink[i], isNext: next == i, isLast: last == i, tint: tint, size: cell) {
                            if next == i { entry = C4Entry(title: "Pink value", allowed: Array(1...6)) { game.fillPink($0) } }
                            else if last == i { game.clearLastPink() }
                        }
                    }
                }
            }
            Text("Fill left→right (no skips). Score = value above the last field, plus 2→+2, 4→+4, 6→+3.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Entry model

private struct C4Entry: Identifiable {
    let id = UUID()
    let title: String
    let allowed: [Int]
    let commit: (Int) -> Void
}

// MARK: - Cells
//
// Tiles are LIGHT: an empty cell is a white box with a coloured outline; a
// filled cell is the area colour with legible text. The most-recently entered
// cell is ringed to advertise tap-to-undo (LIFO).

/// A free-entry value cell (yellow / pink). Tap to enter, tap last to clear.
private struct C4ValueCell: View {
    let value: Int?
    let isNext: Bool
    let isLast: Bool
    let tint: DiceColor
    let size: CGFloat
    let onTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(value != nil ? tint.color : Color.white)
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isLast ? Color.primary : tint.color.opacity(0.5), lineWidth: isLast ? 2.5 : 1)
            if let value {
                Text("\(value)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(tint.textColor)
            } else if isNext {
                Image(systemName: "plus").font(.system(size: 11, weight: .bold)).foregroundStyle(tint.color)
            }
        }
        .frame(width: size, height: size)
        .opacity(value != nil || isNext ? 1 : 0.4)
        .onTapGesture(perform: onTap)
    }
}

/// A numbered grid cell with a cross (blue area).
private struct C4MarkCell: View {
    let label: Int
    let tint: DiceColor
    let crossed: Bool
    let size: CGFloat
    let onTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(crossed ? tint.color : Color.white)
            RoundedRectangle(cornerRadius: 6).strokeBorder(tint.color.opacity(0.5), lineWidth: 1)
            Text("\(label)").font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(crossed ? tint.textColor : tint.color)
            if crossed {
                Image(systemName: "xmark").font(.system(size: 13, weight: .black)).foregroundStyle(tint.textColor)
            }
        }
        .frame(width: size, height: size)
        .onTapGesture(perform: onTap)
    }
}

/// An unlabelled grid cell with a cross (grey polyomino area).
private struct C4PlainCell: View {
    let tint: DiceColor
    let crossed: Bool
    let size: CGFloat
    let onTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(crossed ? tint.color : Color.white)
            RoundedRectangle(cornerRadius: 4).strokeBorder(tint.color.opacity(0.5), lineWidth: 1)
            if crossed {
                Image(systemName: "xmark").font(.system(size: 12, weight: .black)).foregroundStyle(tint.textColor)
            }
        }
        .frame(width: size, height: size)
        .onTapGesture(perform: onTap)
    }
}

/// A green field: a top and bottom triangle value plus its point box.
private struct C4GreenCell: View {
    let top: Int?
    let bottom: Int?
    let score: Int
    let doubled: Bool
    let topIsNext: Bool
    let bottomIsNext: Bool
    let topIsLast: Bool
    let bottomIsLast: Bool
    let tint: DiceColor
    let size: CGFloat
    let tapTop: () -> Void
    let tapBottom: () -> Void

    var body: some View {
        VStack(spacing: 1) {
            Text(doubled ? "×2" : " ").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
            half(value: top, isNext: topIsNext, isLast: topIsLast, onTap: tapTop)
            half(value: bottom, isNext: bottomIsNext, isLast: bottomIsLast, onTap: tapBottom)
            Text(score > 0 ? "\(score)" : " ").font(.system(size: 8, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
        }
    }

    private func half(value: Int?, isNext: Bool, isLast: Bool, onTap: @escaping () -> Void) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(value != nil ? tint.color : Color.white)
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(isLast ? Color.primary : tint.color.opacity(0.5), lineWidth: isLast ? 2.5 : 1)
            if let value {
                Text("\(value)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(tint.textColor)
            } else if isNext {
                Image(systemName: "plus").font(.system(size: 9, weight: .bold)).foregroundStyle(tint.color)
            }
        }
        .frame(width: size, height: size * 0.66)
        .opacity(value != nil || isNext ? 1 : 0.4)
        .onTapGesture(perform: onTap)
    }
}

