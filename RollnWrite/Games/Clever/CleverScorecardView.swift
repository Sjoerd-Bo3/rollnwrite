//
//  CleverScorecardView.swift
//  RollnWrite – Clever
//
//  Interactive "That's Pretty Clever" scorecard. Presentation + touch only; all
//  rules and scoring live in `CleverGame`.
//
//  Styled to mimic the official LIGHT printed score sheet: a cream board, dark
//  text, the area colours as on the card. Fullscreen + landscape (no system nav
//  bar) with a compact in-board header carrying Clever's controls, exactly like
//  the Qwixx scorecard. Tapping the most-recent mark un-checks it (LIFO undo).
//

import SwiftUI

/// Cream "paper" background of the printed sheet.
private let cleverPaper = Color(red: 0.97, green: 0.96, blue: 0.93)
private let cleverInk = Color(red: 0.13, green: 0.13, blue: 0.15)

public struct CleverScorecardView: View {
    @StateObject private var game = CleverGame()
    let rules: RulesDocument

    @Environment(\.dismiss) private var dismiss
    @State private var showRules = false
    @State private var showColors = false
    @State private var confirmNewGame = false
    @State private var entry: ValueEntry?

    private let spacing: CGFloat = 3

    public init(rules: RulesDocument) {
        self.rules = rules
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            board
        }
        .background(cleverPaper.ignoresSafeArea())
        .preferredColorScheme(.light)
        .tint(Color(red: 0.55, green: 0.28, blue: 0.72))
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .landscapeLockediPhone(when: true)
        .sheet(isPresented: $showRules) { RulesView(document: rules) }
        .sheet(isPresented: $showColors) { CleverColorSettingsView(game: game) }
        .confirmationDialog("Start a new game?", isPresented: $confirmNewGame, titleVisibility: .visible) {
            Button("New game", role: .destructive) { game.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears the scorecard. Your dice-colour mapping is kept.")
        }
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

    // MARK: - Compact header (replaces the system nav bar)

    private var header: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: { Image(systemName: "chevron.left") }
            Text("That's Pretty Clever")
                .font(.headline).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            Button { game.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(!game.canUndo)
                .opacity(game.canUndo ? 1 : 0.4)
            Button { showColors = true } label: { Image(systemName: "paintpalette") }
            Button { showRules = true } label: { Image(systemName: "info.circle") }
            Button(role: .destructive) { confirmNewGame = true } label: { Image(systemName: "trash") }
        }
        .font(.title3)
        .foregroundStyle(cleverInk)
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    // MARK: - Board (fills the screen; landscape two-column when wide)

    private var board: some View {
        GeometryReader { geo in
            // Two-column layout when there's enough width (landscape / iPad):
            // grids on the left, the linear rows on the right. Otherwise stack.
            let wide = geo.size.width > geo.size.height && geo.size.width > 640
            // Cell size is derived so the densest column (the 11-wide green/
            // orange/purple rows) fills its share of the width with no scroll.
            let rowsW = wide ? geo.size.width * 0.5 : geo.size.width
            let cell = max(20, min(40, (rowsW - 24 - spacing * 10) / 11))

            Group {
                if wide {
                    HStack(alignment: .top, spacing: 14) {
                        VStack(spacing: 10) {
                            summary
                            bonusBanner
                            roundTrack(cell: cell)
                            actionBars(cell: cell)
                            yellowAndBlue(cell: cell)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        VStack(spacing: 10) {
                            greenRow(cell: cell)
                            orangeRow(cell: cell)
                            purpleRow(cell: cell)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            summary
                            bonusBanner
                            roundTrack(cell: cell)
                            actionBars(cell: cell)
                            yellowAndBlue(cell: cell)
                            greenRow(cell: cell)
                            orangeRow(cell: cell)
                            purpleRow(cell: cell)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(CleverArea.allCases) { area in
                    ScoreChip(
                        title: area.title,
                        value: "\(game.score(for: area))",
                        tint: game.color(area).color
                    )
                }
                ScoreChip(title: "🦊 ×\(game.foxCount)", value: "\(game.foxScore)", tint: .gray)
            }
            HStack {
                Text("Foxes score the lowest area (\(game.lowestAreaScore)) each")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Total").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Text("\(game.totalScore)").font(.title3.bold().monospacedDigit()).foregroundStyle(cleverInk)
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
            .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12).strokeBorder(.black.opacity(0.08), lineWidth: 1)
            )
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Round track & action bars

    private func roundTrack(cell: CGFloat) -> some View {
        HStack(spacing: spacing) {
            Text("Rounds").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(0..<6, id: \.self) { r in
                VStack(spacing: 1) {
                    Text("\(r + 1)").font(.caption2.bold()).foregroundStyle(cleverInk)
                    if let b = CleverLayout.roundBonuses[r] {
                        BonusBadge(icon: b, game: game, size: 16)
                    } else {
                        Color.clear.frame(width: 16, height: 16)
                    }
                }
                .frame(width: cell)
            }
            Spacer(minLength: 0)
        }
    }

    private func actionBars(cell: CGFloat) -> some View {
        VStack(spacing: 4) {
            actionBar(title: "Reroll", system: "arrow.triangle.2.circlepath",
                      slots: CleverLayout.rerollTrackSlots,
                      used: game.state.rerollUsed) { game.toggleReroll($0) }
            actionBar(title: "Extra die", system: "plus.circle",
                      slots: CleverLayout.extraDieTrackSlots,
                      used: game.state.extraDieUsed) { game.toggleExtraDie($0) }
        }
    }

    private func actionBar(title: String, system: String, slots: Int, used: Set<Int>, tap: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 6) {
            Label(title, systemImage: system)
                .font(.caption2.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(cleverInk)
                .frame(width: 88, alignment: .leading)
            ForEach(0..<slots, id: \.self) { s in
                Circle()
                    .strokeBorder(.secondary, lineWidth: 1.5)
                    .background(Circle().fill(used.contains(s) ? Color.secondary : .clear))
                    .frame(width: 18, height: 18)
                    .overlay { if used.contains(s) { Image(systemName: "checkmark").font(.system(size: 9, weight: .black)).foregroundStyle(.white) } }
                    .onTapGesture { tap(s) }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Yellow + Blue

    private func yellowAndBlue(cell: CGFloat) -> some View {
        VStack(spacing: 12) {
            areaHeader(.yellow)
            yellowGrid(cell: cell)
            areaHeader(.blue)
            blueGrid(cell: cell)
        }
    }

    private func areaHeader(_ area: CleverArea) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(game.color(area).color).frame(width: 14, height: 14)
            Text(area.title).font(.subheadline.weight(.semibold)).foregroundStyle(cleverInk)
            Spacer()
            Text("\(game.score(for: area)) pts").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private func yellowGrid(cell: CGFloat) -> some View {
        let tint = game.color(.yellow)
        return HStack(alignment: .top, spacing: 8) {
            VStack(spacing: spacing) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<4, id: \.self) { col in
                            let idx = row * 4 + col
                            yellowCell(idx, tint: tint, size: cell)
                        }
                    }
                }
                HStack(spacing: spacing) {
                    ForEach(0..<4, id: \.self) { col in
                        let done = Set(CleverLayout.yellowColumns[col]).isSubset(of: game.state.yellowCrossed)
                        Text("\(CleverLayout.yellowColumnValues[col])")
                            .font(.caption.bold().monospacedDigit())
                            .frame(width: cell, height: 18)
                            .background(done ? tint.color.opacity(0.35) : .clear, in: Capsule())
                            .foregroundStyle(done ? cleverInk : .secondary)
                    }
                }
            }
            VStack(spacing: spacing) {
                ForEach(0..<4, id: \.self) { row in
                    BonusBadge(icon: CleverLayout.yellowRowBonus[row], game: game, size: cell * 0.7)
                        .frame(height: cell)
                }
                BonusBadge(icon: .plusOne, game: game, size: 16).frame(height: 18) // diagonal bonus
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func yellowCell(_ idx: Int, tint: ThemeColor, size: CGFloat) -> some View {
        let free = game.isYellowFree(idx)
        let crossed = game.state.yellowCrossed.contains(idx)
        let undoable = crossed && game.isLastYellow(idx)
        return ZStack {
            RoundedRectangle(cornerRadius: 6).fill(tint.color)
                .opacity(free || crossed ? 1 : 0.85)
            if let n = CleverLayout.yellowGrid[idx] {
                Text("\(n)").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(tint.textColor)
            }
            if crossed || free {
                Image(systemName: "xmark").font(.system(size: 18, weight: .black)).foregroundStyle(tint.textColor)
            }
        }
        .frame(width: size, height: size)
        .overlay(undoRing(undoable, size: size))
        .opacity(game.canMarkYellow(idx) || crossed || free ? 1 : 0.5)
        .onTapGesture { if undoable { game.undo() } else { game.markYellow(idx) } }
    }

    private func blueGrid(cell: CGFloat) -> some View {
        let tint = game.color(.blue)
        return HStack(alignment: .top, spacing: 8) {
            VStack(spacing: spacing) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<4, id: \.self) { col in
                            let v = CleverLayout.blueGrid[row * 4 + col]
                            blueCell(v, tint: tint, size: cell)
                        }
                    }
                }
                HStack(spacing: spacing) {
                    ForEach(0..<4, id: \.self) { col in
                        BonusBadge(icon: CleverLayout.blueColBonus[col], game: game, size: 16).frame(width: cell, height: 18)
                    }
                }
            }
            VStack(spacing: spacing) {
                ForEach(0..<3, id: \.self) { row in
                    BonusBadge(icon: CleverLayout.blueRowBonus[row], game: game, size: cell * 0.7).frame(height: cell)
                }
                Color.clear.frame(height: 18)
            }
        }
        .overlay(alignment: .topLeading) {
            Text("count → pts:  1·1 2·2 3·4 4·7 5·11 6·16 7·22 8·29 9·37 10·46 11·56")
                .font(.system(size: 8)).foregroundStyle(.secondary)
                .offset(y: -12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func blueCell(_ value: Int?, tint: ThemeColor, size: CGFloat) -> some View {
        let crossed = value != nil && game.state.blueCrossed.contains(value!)
        let undoable = value != nil && game.isLastBlue(value!)
        return ZStack {
            RoundedRectangle(cornerRadius: 6).fill(value == nil ? Color.gray.opacity(0.4) : tint.color)
            if let v = value {
                Text("\(v)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(tint.textColor)
                if crossed {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .black)).foregroundStyle(tint.textColor)
                }
            } else {
                Image(systemName: "die.face.5").font(.system(size: 12)).foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .overlay(undoRing(undoable, size: size))
        .opacity(value == nil ? 0.8 : (game.canMarkBlue(value!) || crossed ? 1 : 0.5))
        .onTapGesture { if let v = value { if undoable { game.undo() } else { game.markBlue(v) } } }
    }

    // MARK: - Green / Orange / Purple rows

    private func greenRow(cell: CGFloat) -> some View {
        let tint = game.color(.green)
        return VStack(alignment: .leading, spacing: 2) {
            areaHeader(.green)
            HStack(spacing: spacing) {
                ForEach(0..<11, id: \.self) { i in
                    let marked = i < game.state.greenCount
                    let isNext = i == game.state.greenCount
                    let undoable = game.lastGreenIndex == i
                    VStack(spacing: 1) {
                        Text("\(CleverLayout.greenScale[i])").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                        ZStack {
                            RoundedRectangle(cornerRadius: 6).fill(tint.color).opacity(marked ? 1 : 0.85)
                            Text("≥\(CleverLayout.greenThresholds[i])").font(.system(size: 11, weight: .bold)).foregroundStyle(tint.textColor)
                            if marked { Image(systemName: "xmark").font(.system(size: 16, weight: .black)).foregroundStyle(tint.textColor) }
                        }
                        .frame(width: cell, height: cell)
                        .overlay(undoRing(undoable, size: cell))
                        .opacity(marked || isNext ? 1 : 0.5)
                        .onTapGesture {
                            if undoable { game.undo() }
                            else if isNext { game.markGreen() }
                        }
                        bonusSlot(CleverLayout.greenBonus[i])
                    }
                }
            }
        }
    }

    private func orangeRow(cell: CGFloat) -> some View {
        let tint = game.color(.orange)
        return VStack(alignment: .leading, spacing: 2) {
            areaHeader(.orange)
            HStack(spacing: spacing) {
                ForEach(0..<11, id: \.self) { i in
                    let value = game.state.orange[i]
                    let mult = CleverLayout.orangeMultipliers[i]
                    let isNext = game.orangeNextIndex == i
                    let undoable = value != nil && game.isLastOrange(i)
                    VStack(spacing: 1) {
                        Text(mult > 1 ? "×\(mult)" : " ").font(.system(size: 9, weight: .bold)).foregroundStyle(.orange)
                        ZStack {
                            RoundedRectangle(cornerRadius: 6).fill(value != nil ? tint.color : tint.color.opacity(0.18))
                            if let v = value {
                                Text("\(v * mult)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(tint.textColor)
                            } else if isNext {
                                Image(systemName: "plus").font(.system(size: 12, weight: .bold)).foregroundStyle(tint.color)
                            }
                        }
                        .frame(width: cell, height: cell)
                        .overlay(undoRing(undoable, size: cell))
                        .opacity(value != nil || isNext ? 1 : 0.5)
                        .onTapGesture {
                            if undoable {
                                game.undo()
                            } else if isNext {
                                entry = ValueEntry(title: "Orange die value", allowed: game.allowedOrangeValues()) { game.fillOrange($0) }
                            }
                        }
                        bonusSlot(CleverLayout.orangeBonus[i])
                    }
                }
            }
        }
    }

    private func purpleRow(cell: CGFloat) -> some View {
        let tint = game.color(.purple)
        return VStack(alignment: .leading, spacing: 2) {
            areaHeader(.purple)
            HStack(spacing: spacing) {
                ForEach(0..<11, id: \.self) { i in
                    let value = game.state.purple[i]
                    let isNext = game.purpleNextIndex == i
                    let undoable = value != nil && game.isLastPurple(i)
                    VStack(spacing: 1) {
                        Text(i == 0 ? " " : "<").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                        ZStack {
                            RoundedRectangle(cornerRadius: 6).fill(value != nil ? tint.color : tint.color.opacity(0.18))
                            if let v = value {
                                Text("\(v)").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(tint.textColor)
                            } else if isNext {
                                Image(systemName: "plus").font(.system(size: 12, weight: .bold)).foregroundStyle(tint.color)
                            }
                        }
                        .frame(width: cell, height: cell)
                        .overlay(undoRing(undoable, size: cell))
                        .opacity(value != nil || isNext ? 1 : 0.5)
                        .onTapGesture {
                            if undoable {
                                game.undo()
                            } else if isNext {
                                let allowed = game.allowedPurpleValues()
                                if !allowed.isEmpty {
                                    entry = ValueEntry(title: "Purple die value (> previous)", allowed: allowed) { game.fillPurple($0) }
                                }
                            }
                        }
                        bonusSlot(CleverLayout.purpleBonus[i])
                    }
                }
            }
        }
    }

    @ViewBuilder private func bonusSlot(_ icon: BonusIcon?) -> some View {
        if let icon { BonusBadge(icon: icon, game: game, size: 16) }
        else { Color.clear.frame(width: 16, height: 16) }
    }

    /// A ring drawn around the most-recent mark to signal it is tap-undoable.
    @ViewBuilder private func undoRing(_ active: Bool, size: CGFloat) -> some View {
        if active {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(cleverInk, lineWidth: 2)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Value entry request

private struct ValueEntry: Identifiable {
    let id = UUID()
    let title: String
    let allowed: [Int]
    let commit: (Int) -> Void
}

// MARK: - Bonus badge

private struct BonusBadge: View {
    let icon: BonusIcon
    @ObservedObject var game: CleverGame
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(background)
            content
        }
        .frame(width: size, height: size)
    }

    private var background: Color {
        switch icon {
        case .reroll, .plusOne, .fox: return cleverInk
        case let .mark(area): return game.color(area).color
        case let .number(area, _): return game.color(area).color
        }
    }

    @ViewBuilder private var content: some View {
        switch icon {
        case .reroll: Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: size * 0.55, weight: .bold)).foregroundStyle(.white)
        case .plusOne: Text("+1").font(.system(size: size * 0.5, weight: .black)).foregroundStyle(.white)
        case .fox: Text("🦊").font(.system(size: size * 0.7))
        case let .mark(area): Text("✗").font(.system(size: size * 0.6, weight: .black)).foregroundStyle(game.color(area).textColor)
        case let .number(area, n): Text("\(n)").font(.system(size: size * 0.6, weight: .black)).foregroundStyle(game.color(area).textColor)
        }
    }
}

// MARK: - Colour mapping (map physical dice → areas)

private struct CleverColorSettingsView: View {
    @ObservedObject var game: CleverGame
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(CleverArea.allCases) { area in
                        Picker(selection: Binding(
                            get: { game.color(area) },
                            set: { game.setColor($0, for: area) }
                        )) {
                            ForEach(ThemeColor.allCases) { c in
                                HStack {
                                    Circle().fill(c.color).frame(width: 16, height: 16)
                                    Text(c.displayName)
                                }.tag(c)
                            }
                        } label: {
                            HStack {
                                Circle().fill(game.color(area).color).frame(width: 18, height: 18)
                                Text(area.title)
                            }
                        }
                    }
                } header: {
                    Text("Match each area to your physical dice colour")
                } footer: {
                    Text("Scoring is unchanged — only the colours shown are remapped.")
                }
                Section {
                    Button("Reset to official colours") { game.resetColors() }
                }
            }
            .navigationTitle("Dice colours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
