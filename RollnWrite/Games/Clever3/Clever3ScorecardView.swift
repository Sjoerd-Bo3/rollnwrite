//
//  Clever3ScorecardView.swift
//  RollnWrite – Clever3
//

import SwiftUI

public struct Clever3ScorecardView: View {
    @StateObject private var game = Clever3Game()
    let rules: RulesDocument

    @State private var showRules = false
    @State private var showColors = false
    @State private var confirmNewGame = false
    @State private var entry: C3Entry?

    private let spacing: CGFloat = 3

    public init(rules: RulesDocument) { self.rules = rules }

    public var body: some View {
        GeometryReader { geo in
            let contentWidth = min(geo.size.width, 720)
            let cell = max(24, min(46, (contentWidth - 24 - spacing * 12) / 13))
            ScrollView {
                VStack(spacing: 12) {
                    summary
                    bonusBanner
                    foxStepper
                    grid(.yellow, rows: Clever3Layout.yellowRows, cols: Clever3Layout.yellowCols,
                         marks: game.state.yellow, scale: Clever3Layout.yellowRowScale,
                         marksInRow: game.yellowMarks(inRow:), toggle: game.toggleYellow, cell: cell)
                    grid(.turquoise, rows: Clever3Layout.turquoiseRows, cols: Clever3Layout.turquoiseCols,
                         marks: game.state.turquoise, scale: Clever3Layout.turquoiseRowScale,
                         marksInRow: game.turquoiseMarks(inRow:), toggle: game.toggleTurquoise, cell: cell)
                    blueTrack(cell: cell)
                    brownRow(cell: cell)
                    pinkRow(cell: cell)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: contentWidth).frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Clever Cubed")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showColors = true } label: { Image(systemName: "paintpalette") }
                Button { showRules = true } label: { Image(systemName: "info.circle") }
                Button(role: .destructive) { confirmNewGame = true } label: { Image(systemName: "trash") }
            }
        }
        .sheet(isPresented: $showRules) { RulesView(document: rules) }
        .sheet(isPresented: $showColors) { Clever3ColorSettingsView(game: game) }
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
            if entry?.allowClear == true {
                Button("Clear", role: .destructive) { entry?.commit(0); entry = nil }
            }
            Button("Cancel", role: .cancel) { entry = nil }
        }
    }

    private var summary: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Clever3Area.allCases) { area in
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
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: .infinity)
        }
    }

    private var foxStepper: some View {
        Stepper(value: Binding(get: { game.state.foxes }, set: { nv in if nv > game.state.foxes { game.addFox() } else { game.removeFox() } }), in: 0...20) {
            Text("🦊 Foxes earned: \(game.state.foxes)").font(.subheadline.weight(.semibold))
        }
    }

    private func grid(_ area: Clever3Area, rows: Int, cols: Int, marks: Set<Int>, scale: [Int],
                      marksInRow: @escaping (Int) -> Int, toggle: @escaping (Int) -> Void, cell: CGFloat) -> some View {
        let tint = game.color(area)
        return VStack(alignment: .leading, spacing: 2) {
            header(area)
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: spacing) {
                    ForEach(0..<cols, id: \.self) { c in
                        C3GridCell(label: c + 1, tint: tint, crossed: marks.contains(r * cols + c), size: cell) {
                            toggle(r * cols + c)
                        }
                    }
                    Text("\(scale[marksInRow(r)])").font(.caption.bold().monospacedDigit()).foregroundStyle(.secondary).frame(minWidth: cell)
                }
            }
        }
    }

    // MARK: - Blue ±1 track

    private func blueTrack(cell: CGFloat) -> some View {
        let tint = game.color(.blue)
        let n = Clever3Layout.blueSideCells
        return VStack(alignment: .leading, spacing: 2) {
            header(.blue)
            HStack(spacing: spacing) {
                ForEach(0..<n, id: \.self) { k in
                    let i = n - 1 - k          // outermost-left first
                    blueCell(side: true, index: i, cell: cell, tint: tint)
                }
                centerSeven(cell: cell, tint: tint)
                ForEach(0..<n, id: \.self) { i in
                    blueCell(side: false, index: i, cell: cell, tint: tint)
                }
            }
            Text("Outermost left + outermost right + 4 per 2/3/4/10/11/12.").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func centerSeven(cell: CGFloat, tint: ThemeColor) -> some View {
        VStack(spacing: 1) {
            Text(" ").font(.system(size: 8))
            ZStack { RoundedRectangle(cornerRadius: 6).fill(tint.color); Text("7").font(.system(size: 15, weight: .black)).foregroundStyle(tint.textColor) }
                .frame(width: cell, height: cell)
        }
    }

    private func blueCell(side left: Bool, index: Int, cell: CGFloat, tint: ThemeColor) -> some View {
        let value = left ? game.state.blueLeft[index] : game.state.blueRight[index]
        let isNext = (left ? game.blueLeftNext : game.blueRightNext) == index
        return VStack(spacing: 1) {
            Text("\(Clever3Layout.bluePositionScale[index])").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(value != nil ? tint.color : tint.color.opacity(0.18))
                if let value { Text("\(value)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(tint.textColor) }
                else if isNext { Text(left ? "−1" : "+1").font(.system(size: 9, weight: .bold)).foregroundStyle(tint.color) }
            }
            .frame(width: cell, height: cell)
            .opacity(value != nil || isNext ? 1 : 0.45)
            .onTapGesture {
                if isNext {
                    let allowed = game.allowedBlue(left: left)
                    if !allowed.isEmpty { entry = C3Entry(title: "Blue value", allowed: allowed, allowClear: false) { game.fillBlue(left: left, $0) } }
                }
            }
        }
    }

    // MARK: - Brown

    private func brownRow(cell: CGFloat) -> some View {
        let tint = game.color(.brown)
        return VStack(alignment: .leading, spacing: 2) {
            header(.brown)
            HStack(spacing: spacing) {
                ForEach(0..<Clever3Layout.brownNumbers.count, id: \.self) { i in
                    let crossed = game.state.brown.contains(i)
                    let enabled = game.canCrossBrown(i) || (crossed && i == (game.state.brown.max() ?? -1))
                    VStack(spacing: 1) {
                        Text("\(Clever3Layout.brownScale[i + 1])").font(.system(size: 7, weight: .bold)).foregroundStyle(.secondary)
                        C3GridCell(label: Clever3Layout.brownNumbers[i], tint: tint, crossed: crossed, size: cell) { game.toggleBrown(i) }
                            .opacity(enabled || crossed ? 1 : 0.4)
                    }
                }
            }
        }
    }

    // MARK: - Pink

    private func pinkRow(cell: CGFloat) -> some View {
        let tint = game.color(.pink)
        return VStack(alignment: .leading, spacing: 2) {
            header(.pink)
            HStack(spacing: spacing) {
                ForEach(0..<Clever3Layout.pinkCells, id: \.self) { i in
                    VStack(spacing: 1) {
                        Text("×\(Clever3Layout.pinkMultipliers[i])").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
                        C3PinkCell(value: game.state.pink[i], tint: tint, size: cell) {
                            entry = C3Entry(title: "Pink written value", allowed: Array(1...12), allowClear: true) { game.setPink(i, $0 == 0 ? nil : $0) }
                        }
                    }
                }
            }
            Text("Enter the value you wrote (die × the shown multiplier, or the halved bonus value).").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func header(_ area: Clever3Area) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(game.color(area).color).frame(width: 14, height: 14)
            Text(area.title).font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(game.score(for: area)) pts").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }
}

private struct C3Entry: Identifiable {
    let id = UUID()
    let title: String
    let allowed: [Int]
    let allowClear: Bool
    let commit: (Int) -> Void
}

private struct C3GridCell: View {
    let label: Int
    let tint: ThemeColor
    let crossed: Bool
    let size: CGFloat
    let onTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(tint.color)
            Text("\(label)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(tint.textColor)
            if crossed {
                Image(systemName: "xmark").font(.system(size: 16, weight: .black)).foregroundStyle(tint.textColor)
            }
        }
        .frame(width: size, height: size)
        .onTapGesture(perform: onTap)
    }
}

private struct C3PinkCell: View {
    let value: Int?
    let tint: ThemeColor
    let size: CGFloat
    let onTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(value != nil ? tint.color : tint.color.opacity(0.18))
            if let value {
                Text("\(value)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(tint.textColor)
            } else {
                Image(systemName: "plus").font(.system(size: 11, weight: .bold)).foregroundStyle(tint.color)
            }
        }
        .frame(width: size, height: size)
        .onTapGesture(perform: onTap)
    }
}

private struct Clever3ColorSettingsView: View {
    @ObservedObject var game: Clever3Game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(Clever3Area.allCases) { area in
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
