//
//  Clever4ScorecardView.swift
//  RollnWrite – Clever4
//

import SwiftUI

public struct Clever4ScorecardView: View {
    @StateObject private var game = Clever4Game()
    let rules: RulesDocument

    @State private var showRules = false
    @State private var showColors = false
    @State private var confirmNewGame = false

    public init(rules: RulesDocument) { self.rules = rules }

    public var body: some View {
        GeometryReader { geo in
            let contentWidth = min(geo.size.width, 560)
            ScrollView {
                VStack(spacing: 14) {
                    summary
                    note
                    ForEach(Clever4Area.allCases) { area in
                        areaRow(area)
                    }
                    foxStepper
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
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
    }

    private var summary: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Total").font(.title3.weight(.semibold))
                Spacer()
                Text("\(game.totalScore)").font(.largeTitle.bold().monospacedDigit())
            }
            HStack {
                Text("🦊 ×\(game.state.foxes) = \(game.foxScore)").font(.caption)
                Spacer()
                Text("Foxes score the lowest area (\(game.lowestAreaScore)) each").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var note: some View {
        Text("Clever 4ever's board (polyomino grey area, coordinate blue area) isn't yet interactive in the app. Enter each area's total from your sheet — foxes and the grand total are computed for you.")
            .font(.caption2).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func areaRow(_ area: Clever4Area) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6).fill(game.color(area).color).frame(width: 26, height: 26)
            Text(area.title).font(.headline)
            Spacer()
            TextField("0", value: Binding(get: { game.score(for: area) }, set: { game.setScore($0, for: area) }), format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.title3.monospacedDigit())
                .frame(width: 80)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.vertical, 2)
    }

    private var foxStepper: some View {
        Stepper(value: Binding(get: { game.state.foxes }, set: { nv in if nv > game.state.foxes { game.addFox() } else { game.removeFox() } }), in: 0...20) {
            Text("🦊 Foxes earned: \(game.state.foxes)").font(.headline)
        }
        .padding(.top, 4)
    }
}

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
