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
    @State private var pinkEntry: Int?   // index of pink cell being filled

    private let spacing: CGFloat = 3

    public init(rules: RulesDocument) { self.rules = rules }

    public var body: some View {
        GeometryReader { geo in
            let contentWidth = min(geo.size.width, 680)
            let cell = max(28, min(48, (contentWidth - 24 - spacing * 5) / 6))
            ScrollView {
                VStack(spacing: 12) {
                    summary
                    note
                    foxStepper
                    grid(.yellow, rows: Clever3Layout.yellowRows, cols: Clever3Layout.yellowCols,
                         marks: game.state.yellow, scale: Clever3Layout.yellowRowScale,
                         marksInRow: game.yellowMarks(inRow:), toggle: game.toggleYellow, cell: cell)
                    grid(.turquoise, rows: Clever3Layout.turquoiseRows, cols: Clever3Layout.turquoiseCols,
                         marks: game.state.turquoise, scale: Clever3Layout.turquoiseRowScale,
                         marksInRow: game.turquoiseMarks(inRow:), toggle: game.toggleTurquoise, cell: cell)
                    pinkArea(cell: cell)
                    manualArea(.blue, total: game.state.blueTotal, max: Clever3Layout.blueMax) { game.setBlueTotal($0) }
                    manualArea(.brown, total: game.state.brownTotal, max: Clever3Layout.brownMax) { game.setBrownTotal($0) }
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
            "Pink written value",
            isPresented: Binding(get: { pinkEntry != nil }, set: { if !$0 { pinkEntry = nil } }),
            titleVisibility: .visible
        ) {
            ForEach(1...12, id: \.self) { v in
                Button("\(v)") { if let i = pinkEntry { game.setPink(i, v) }; pinkEntry = nil }
            }
            Button("Clear", role: .destructive) { if let i = pinkEntry { game.setPink(i, nil) }; pinkEntry = nil }
            Button("Cancel", role: .cancel) { pinkEntry = nil }
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

    private var note: some View {
        Text("Yellow, turquoise and pink are scored automatically. Blue and brown use point tables printed only on the physical sheet — enter those two area totals below.")
            .font(.caption2).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
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
                    Text("\(scale[marksInRow(r)])")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: cell)
                }
            }
        }
    }

    private func pinkArea(cell: CGFloat) -> some View {
        let tint = game.color(.pink)
        return VStack(alignment: .leading, spacing: 2) {
            header(.pink)
            HStack(spacing: spacing) {
                ForEach(0..<Clever3Layout.pinkCells, id: \.self) { i in
                    C3PinkCell(value: game.state.pink[i], tint: tint, size: cell) { pinkEntry = i }
                }
            }
            Text("Enter the value you wrote (die × multiplier, or the halved bonus value).").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func manualArea(_ area: Clever3Area, total: Int, max: Int, set: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3).fill(game.color(area).color).frame(width: 14, height: 14)
            Text("\(area.title) total").font(.subheadline.weight(.semibold))
            Spacer()
            TextField("0", value: Binding(get: { total }, set: { set($0) }), format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
                .textFieldStyle(.roundedBorder)
            Text("/ \(max)").font(.caption).foregroundStyle(.secondary)
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
