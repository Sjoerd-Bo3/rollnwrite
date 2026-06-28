//
//  Clever2ScorecardView.swift
//  RollnWrite – Clever2
//
//  Interactive "Twice as Clever" scorecard. Presentation + touch only.
//

import SwiftUI

public struct Clever2ScorecardView: View {
    @StateObject private var game = Clever2Game()
    let rules: RulesDocument

    @State private var showRules = false
    @State private var showColors = false
    @State private var confirmNewGame = false
    @State private var entry: C2ValueEntry?

    private let spacing: CGFloat = 3
    private let columns = 12

    public init(rules: RulesDocument) { self.rules = rules }

    public var body: some View {
        GeometryReader { geo in
            let contentWidth = min(geo.size.width, 760)
            let cell = max(20, (contentWidth - 24 - spacing * CGFloat(columns - 1)) / CGFloat(columns))
            ScrollView {
                VStack(spacing: 12) {
                    summary
                    bonusBanner
                    foxRow
                    actionBars(cell: cell)
                    silverArea(cell: cell)
                    yellowArea(cell: cell)
                    blueRow(cell: cell)
                    greenRow(cell: cell)
                    pinkRow(cell: cell)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: contentWidth).frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Twice as Clever")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { game.undo() } label: { Image(systemName: "arrow.uturn.backward") }.disabled(!game.canUndo)
                Button { showColors = true } label: { Image(systemName: "paintpalette") }
                Button { showRules = true } label: { Image(systemName: "info.circle") }
                Button(role: .destructive) { confirmNewGame = true } label: { Image(systemName: "trash") }
            }
        }
        .sheet(isPresented: $showRules) { RulesView(document: rules) }
        .sheet(isPresented: $showColors) { Clever2ColorSettingsView(game: game) }
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

    // MARK: - Summary & foxes

    private var summary: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Clever2Area.allCases) { area in
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

    // MARK: - Earned-bonus banner

    @ViewBuilder private var bonusBanner: some View {
        if !game.earnedBonuses.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "gift.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(game.earnedBonuses.suffix(4).enumerated()), id: \.offset) { _, msg in
                        Text(msg).font(.caption.weight(.medium))
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
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: .infinity)
        }
    }

    private var foxRow: some View {
        Stepper(
            value: Binding(
                get: { game.state.foxes },
                set: { newValue in if newValue > game.state.foxes { game.addFox() } else { game.removeFox() } }
            ),
            in: 0...20
        ) {
            Text("🦊 Foxes earned: \(game.state.foxes)").font(.subheadline.weight(.semibold))
        }
    }

    private func actionBars(cell: CGFloat) -> some View {
        VStack(spacing: 4) {
            bar("Reroll", "arrow.triangle.2.circlepath", Clever2Layout.rerollTrackSlots, game.state.rerollUsed) { game.toggleReroll($0) }
            bar("Return", "arrow.uturn.left", Clever2Layout.returnTrackSlots, game.state.returnUsed) { game.toggleReturn($0) }
            bar("Extra die", "plus.circle", Clever2Layout.extraDieTrackSlots, game.state.extraDieUsed) { game.toggleExtraDie($0) }
        }
    }

    private func bar(_ title: String, _ system: String, _ slots: Int, _ used: Set<Int>, _ tap: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 6) {
            Label(title, systemImage: system).font(.caption2.weight(.semibold)).frame(width: 92, alignment: .leading)
            ForEach(0..<slots, id: \.self) { s in
                Circle().strokeBorder(.secondary, lineWidth: 1.5)
                    .background(Circle().fill(used.contains(s) ? Color.secondary : .clear))
                    .frame(width: 16, height: 16)
                    .onTapGesture { tap(s) }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Silver

    private func silverArea(cell: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            header(.silver)
            HStack(spacing: spacing) {
                ForEach(0..<Clever2Layout.silverCols, id: \.self) { c in
                    C2Badge(bonus: Clever2Layout.silverColumnBonus[c], game: game, size: 16).frame(width: cell)
                }
            }
            ForEach(0..<Clever2Layout.silverRowAreas.count, id: \.self) { r in
                let area = Clever2Layout.silverRowAreas[r]
                HStack(spacing: spacing) {
                    ForEach(0..<Clever2Layout.silverCols, id: \.self) { c in
                        let idx = r * Clever2Layout.silverCols + c
                        let crossed = game.state.silver.contains(idx)
                        ZStack {
                            RoundedRectangle(cornerRadius: 6).fill(game.color(area).color)
                            Text("\(c + 1)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(game.color(area).textColor)
                            if crossed { Image(systemName: "xmark").font(.system(size: 16, weight: .black)).foregroundStyle(game.color(area).textColor) }
                        }
                        .frame(width: cell, height: cell)
                        .onTapGesture { game.crossSilver(idx) }
                    }
                    Text("\(Clever2Layout.silverRowScale[game.silverMarks(inRow: r)])")
                        .font(.caption.bold().monospacedDigit()).foregroundStyle(.secondary).frame(width: cell)
                }
            }
        }
    }

    // MARK: - Yellow (staggered, circle → cross)

    private func yellowArea(cell: CGFloat) -> some View {
        let cols = Clever2Layout.yellowColumns
        // Flat index where each column begins (cells are numbered column by column).
        var starts: [Int] = []
        var acc = 0
        for c in cols { starts.append(acc); acc += c.count }
        return VStack(alignment: .leading, spacing: 2) {
            header(.yellow)
            Text("Tap once to circle, twice to cross. Score counts crosses: \(game.yellowCrossedCount) → \(game.yellowScore)")
                .font(.caption2).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: spacing) {
                ForEach(0..<cols.count, id: \.self) { col in
                    VStack(spacing: spacing) {
                        ForEach(0..<cols[col].count, id: \.self) { row in
                            yellowCell(index: starts[col] + row, value: cols[col][row], cell: cell)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func yellowCell(index: Int, value: Int, cell: CGFloat) -> some View {
        let tint = game.color(.yellow)
        let st = game.yellowState(index)
        return ZStack {
            RoundedRectangle(cornerRadius: 6).fill(tint.color)
            Text("\(value)").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(tint.textColor)
            if st == .circled {
                Circle().strokeBorder(tint.textColor, lineWidth: 2.5).padding(3)
            } else if st == .crossed {
                Image(systemName: "xmark").font(.system(size: 18, weight: .black)).foregroundStyle(tint.textColor)
            }
        }
        .frame(width: cell, height: cell)
        .onTapGesture { game.advanceYellow(index) }
    }

    // MARK: - Blue / Green / Pink rows

    private func blueRow(cell: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            header(.blue)
            HStack(spacing: spacing) {
                ForEach(0..<Clever2Layout.blueCount, id: \.self) { i in
                    let v = game.state.blue[i]
                    let isNext = game.blueNextIndex == i
                    VStack(spacing: 1) {
                        Text("\(Clever2Layout.blueScale[i + 1])").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
                        valueCell(area: .blue, value: v, isNext: isNext, cell: cell) {
                            entry = C2ValueEntry(title: "Blue sum (≤ previous)", allowed: game.allowedBlueValues()) { game.fillBlue($0) }
                        }
                        C2Badge.slot(Clever2Layout.blueBonus[i], game: game)
                    }
                }
            }
        }
    }

    private func greenRow(cell: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            header(.green)
            HStack(spacing: spacing) {
                ForEach(0..<12, id: \.self) { i in
                    let isNext = game.greenNextIndex == i
                    VStack(spacing: 1) {
                        if i % 2 == 0 {
                            let pair = i / 2
                            if let a = game.greenWritten(pair * 2), let b = game.greenWritten(pair * 2 + 1) {
                                Text("\(a - b)").font(.system(size: 9, weight: .black)).foregroundStyle(game.color(.green).color)
                            } else {
                                Text("×\(Clever2Layout.greenMultipliers[i])").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
                            }
                        } else {
                            Text("×\(Clever2Layout.greenMultipliers[i])").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
                        }
                        valueCell(area: .green, value: game.greenWritten(i), isNext: isNext, cell: cell) {
                            entry = C2ValueEntry(title: "Green die (×\(Clever2Layout.greenMultipliers[i]))", allowed: game.allowedGreenValues()) { game.fillGreen($0) }
                        }
                        C2Badge.slot(Clever2Layout.greenBonus[i], game: game)
                    }
                    .padding(.trailing, i % 2 == 1 ? 4 : 0) // gap between pairs
                }
            }
        }
    }

    private func pinkRow(cell: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            header(.pink)
            HStack(spacing: spacing) {
                ForEach(0..<12, id: \.self) { i in
                    let isNext = game.pinkNextIndex == i
                    VStack(spacing: 1) {
                        Text(Clever2Layout.pinkThresholds[i].map { "≥\($0)" } ?? " ").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
                        valueCell(area: .pink, value: game.state.pink[i], isNext: isNext, cell: cell) {
                            entry = C2ValueEntry(title: "Pink die value", allowed: game.allowedPinkValues()) { game.fillPink($0) }
                        }
                        C2Badge.slot(Clever2Layout.pinkBonus[i], game: game)
                    }
                }
            }
        }
    }

    private func valueCell(area: Clever2Area, value: Int?, isNext: Bool, cell: CGFloat, onTap: @escaping () -> Void) -> some View {
        let tint = game.color(area)
        return ZStack {
            RoundedRectangle(cornerRadius: 6).fill(value != nil ? tint.color : tint.color.opacity(0.18))
            if let v = value {
                Text("\(v)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(tint.textColor)
            } else if isNext {
                Image(systemName: "plus").font(.system(size: 11, weight: .bold)).foregroundStyle(tint.color)
            }
        }
        .frame(width: cell, height: cell)
        .opacity(value != nil || isNext ? 1 : 0.5)
        .onTapGesture { if isNext { onTap() } }
    }

    private func header(_ area: Clever2Area) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(game.color(area).color).frame(width: 14, height: 14)
            Text(area.title).font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(game.score(for: area)) pts").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Helpers

private struct C2ValueEntry: Identifiable {
    let id = UUID()
    let title: String
    let allowed: [Int]
    let commit: (Int) -> Void
}

private struct C2Badge: View {
    let bonus: Clever2Bonus
    @ObservedObject var game: Clever2Game
    let size: CGFloat

    @ViewBuilder static func slot(_ bonus: Clever2Bonus?, game: Clever2Game) -> some View {
        if let bonus { C2Badge(bonus: bonus, game: game, size: 15) } else { Color.clear.frame(width: 15, height: 15) }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(background)
            content
        }
        .frame(width: size, height: size)
    }

    private var background: Color {
        switch bonus {
        case .reroll, .returnDie, .plusOne, .fox: return .black
        case let .mark(a): return game.color(a).color
        case let .number(a, _): return game.color(a).color
        }
    }

    @ViewBuilder private var content: some View {
        switch bonus {
        case .reroll: Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: size * 0.55, weight: .bold)).foregroundStyle(.white)
        case .returnDie: Image(systemName: "arrow.uturn.left").font(.system(size: size * 0.55, weight: .bold)).foregroundStyle(.white)
        case .plusOne: Text("+1").font(.system(size: size * 0.5, weight: .black)).foregroundStyle(.white)
        case .fox: Text("🦊").font(.system(size: size * 0.7))
        case let .mark(a): Text("✗").font(.system(size: size * 0.6, weight: .black)).foregroundStyle(game.color(a).textColor)
        case let .number(a, n): Text("\(n)").font(.system(size: size * 0.6, weight: .black)).foregroundStyle(game.color(a).textColor)
        }
    }
}

private struct Clever2ColorSettingsView: View {
    @ObservedObject var game: Clever2Game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(Clever2Area.allCases) { area in
                        Picker(selection: Binding(get: { game.color(area) }, set: { game.setColor($0, for: area) })) {
                            ForEach(ThemeColor.allCases) { c in
                                HStack { Circle().fill(c.color).frame(width: 16, height: 16); Text(c.displayName) }.tag(c)
                            }
                        } label: {
                            HStack { Circle().fill(game.color(area).color).frame(width: 18, height: 18); Text(area.title) }
                        }
                    }
                } header: {
                    Text("Match each area to your physical dice colour")
                } footer: {
                    Text("Scoring is unchanged — only the colours shown are remapped.")
                }
                Section { Button("Reset to official colours") { game.resetColors() } }
            }
            .navigationTitle("Dice colours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
