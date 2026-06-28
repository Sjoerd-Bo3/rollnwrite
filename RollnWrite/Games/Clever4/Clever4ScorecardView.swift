//
//  Clever4ScorecardView.swift
//  RollnWrite – Clever4
//
//  Interactive, auto-scoring scorecard. View bodies are intentionally small and
//  each cell is extracted into a private `struct …: View` so the Swift
//  type-checker stays fast.
//

import SwiftUI

public struct Clever4ScorecardView: View {
    @StateObject private var game = Clever4Game()
    let rules: RulesDocument

    @State private var showRules = false
    @State private var showColors = false
    @State private var confirmNewGame = false
    @State private var entry: C4Entry?

    private let spacing: CGFloat = 3

    public init(rules: RulesDocument) { self.rules = rules }

    public var body: some View {
        GeometryReader { geo in
            let contentWidth = min(geo.size.width, 720)
            let cell = max(22, min(44, (contentWidth - 24 - spacing * 15) / 16))
            ScrollView {
                VStack(spacing: 14) {
                    summary
                    foxStepper
                    yellowArea(cell: cell)
                    blueArea(cell: cell)
                    greyArea(cell: cell)
                    greenArea(cell: cell)
                    pinkArea(cell: cell)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: contentWidth).frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Clever 4ever")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showColors = true } label: { Image(systemName: "paintpalette") }
                Button { showRules = true } label: { Image(systemName: "info.circle") }
                Button(role: .destructive) { confirmNewGame = true } label: { Image(systemName: "trash") }
            }
        }
        .sheet(isPresented: $showRules) { RulesView(document: rules) }
        .sheet(isPresented: $showColors) { Clever4ColorSettingsView(game: game) }
        .confirmationDialog("Start a new game?", isPresented: $confirmNewGame, titleVisibility: .visible) {
            Button("New game", role: .destructive) { game.reset() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This clears the scorecard. Your dice-colour mapping is kept.") }
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

    private var foxStepper: some View {
        Stepper(value: Binding(get: { game.state.foxes }, set: { nv in if nv > game.state.foxes { game.addFox() } else { game.removeFox() } }), in: 0...20) {
            Text("🦊 Foxes earned: \(game.state.foxes)").font(.subheadline.weight(.semibold))
        }
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

    private func yellowRow(_ row: Clever4Game.YellowRow, label: String, values: [Int?], cell: CGFloat, tint: ThemeColor) -> some View {
        let next = game.yellowNext(row)
        return HStack(spacing: spacing) {
            Text(label).font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
                .frame(width: cell, alignment: .leading).lineLimit(2)
            ForEach(0..<Clever4Layout.yellowCols, id: \.self) { c in
                C4ValueCell(value: values[c], isNext: next == c, tint: tint, size: cell) {
                    if next == c {
                        let allowed = game.allowedYellow(row)
                        if !allowed.isEmpty {
                            entry = C4Entry(title: "Yellow value", allowed: allowed) { game.fillYellow(row, $0) }
                        }
                    } else if values[c] != nil && values.lastIndex(where: { $0 != nil }) == c {
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
                        tint: tint,
                        size: cell,
                        tapTop: {
                            if topNext == i { entry = C4Entry(title: "Green top", allowed: Array(1...6)) { game.fillGreenTop($0) } }
                            else if game.state.greenTop.lastIndex(where: { $0 != nil }) == i { game.clearLastGreenTop() }
                        },
                        tapBottom: {
                            if botNext == i { entry = C4Entry(title: "Green bottom", allowed: Array(1...6)) { game.fillGreenBottom($0) } }
                            else if game.state.greenBottom.lastIndex(where: { $0 != nil }) == i { game.clearLastGreenBottom() }
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
        return VStack(alignment: .leading, spacing: 3) {
            header(.pink)
            HStack(spacing: spacing) {
                ForEach(0..<Clever4Layout.pinkFields, id: \.self) { i in
                    VStack(spacing: 1) {
                        Text("\(Clever4Layout.pinkValues[i])").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
                        C4ValueCell(value: game.state.pink[i], isNext: next == i, tint: tint, size: cell) {
                            if next == i { entry = C4Entry(title: "Pink value", allowed: Array(1...6)) { game.fillPink($0) } }
                            else if game.state.pink.lastIndex(where: { $0 != nil }) == i { game.clearLastPink() }
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

/// A free-entry value cell (yellow / pink). Tap to enter, tap last to clear.
private struct C4ValueCell: View {
    let value: Int?
    let isNext: Bool
    let tint: ThemeColor
    let size: CGFloat
    let onTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(value != nil ? tint.color : tint.color.opacity(0.18))
            if let value {
                Text("\(value)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(tint.textColor)
            } else if isNext {
                Image(systemName: "plus").font(.system(size: 11, weight: .bold)).foregroundStyle(tint.color)
            }
        }
        .frame(width: size, height: size)
        .opacity(value != nil || isNext ? 1 : 0.45)
        .onTapGesture(perform: onTap)
    }
}

/// A numbered grid cell with a cross (blue area).
private struct C4MarkCell: View {
    let label: Int
    let tint: ThemeColor
    let crossed: Bool
    let size: CGFloat
    let onTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(crossed ? tint.color : tint.color.opacity(0.18))
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
    let tint: ThemeColor
    let crossed: Bool
    let size: CGFloat
    let onTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(crossed ? tint.color : tint.color.opacity(0.18))
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
    let tint: ThemeColor
    let size: CGFloat
    let tapTop: () -> Void
    let tapBottom: () -> Void

    var body: some View {
        VStack(spacing: 1) {
            Text(doubled ? "×2" : " ").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
            half(value: top, isNext: topIsNext, onTap: tapTop)
            half(value: bottom, isNext: bottomIsNext, onTap: tapBottom)
            Text(score > 0 ? "\(score)" : " ").font(.system(size: 8, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
        }
    }

    private func half(value: Int?, isNext: Bool, onTap: @escaping () -> Void) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(value != nil ? tint.color : tint.color.opacity(0.18))
            if let value {
                Text("\(value)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(tint.textColor)
            } else if isNext {
                Image(systemName: "plus").font(.system(size: 9, weight: .bold)).foregroundStyle(tint.color)
            }
        }
        .frame(width: size, height: size * 0.66)
        .opacity(value != nil || isNext ? 1 : 0.45)
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Colour settings

private struct Clever4ColorSettingsView: View {
    @ObservedObject var game: Clever4Game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(Clever4Area.allCases) { area in
                        Picker(selection: Binding(get: { game.color(area) }, set: { game.setColor($0, for: area) })) {
                            ForEach(ThemeColor.allCases) { c in
                                HStack { Circle().fill(c.color).frame(width: 16, height: 16); Text(c.displayName) }.tag(c)
                            }
                        } label: {
                            HStack { Circle().fill(game.color(area).color).frame(width: 18, height: 18); Text(area.title) }
                        }
                    }
                } header: { Text("Match each area to your physical dice colour") }
                Section { Button("Reset to official colours") { game.resetColors() } }
            }
            .navigationTitle("Dice colours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
