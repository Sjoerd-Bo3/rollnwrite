//
//  RootView.swift
//  RollnWrite
//
//  The game catalogue. Driven entirely by `GameRegistry`, so shipping a new game
//  requires no changes here (Open/Closed Principle).
//

import SwiftUI

struct RootView: View {
    @State private var rulesToShow: IdentifiedRules?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(families, id: \.name) { group in
                    Section(group.name) {
                        ForEach(group.games, id: \.id) { game in
                            NavigationLink {
                                game.makeScorecardView()
                            } label: {
                                GameRow(game: game)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    rulesToShow = IdentifiedRules(document: game.rules)
                                } label: {
                                    Label("Rules", systemImage: "info.circle")
                                }
                                .tint(.indigo)
                            }
                        }
                    }
                }

                if !GameRegistry.upcoming.isEmpty {
                    Section("Coming soon") {
                        ForEach(GameRegistry.upcoming, id: \.id) { game in
                            GameRow(game: game)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Roll'n Write")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(item: $rulesToShow) { wrapper in
                RulesView(document: wrapper.document)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    /// Playable games grouped by family (Qwixx, Clever) so the catalogue stays
    /// tidy as variants are added. Families appear in a fixed order; any others
    /// fall through to the end alphabetically.
    private var families: [(name: String, games: [GameDefinition])] {
        let order = ["Qwixx", "Clever"]
        let grouped = Dictionary(grouping: GameRegistry.playable, by: Self.family)
        let known = order.compactMap { key in grouped[key].map { (name: key, games: $0) } }
        let extra = grouped.keys
            .filter { !order.contains($0) }
            .sorted()
            .map { (name: $0, games: grouped[$0]!) }
        return known + extra
    }

    private static func family(_ game: GameDefinition) -> String {
        game.id.hasPrefix("qwixx") ? "Qwixx" : "Clever"
    }
}

/// Wrapper to present a `RulesDocument` via `.sheet(item:)`.
private struct IdentifiedRules: Identifiable {
    let id = UUID()
    let document: RulesDocument
}

private struct GameRow: View {
    let game: GameDefinition

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: game.iconSystemName)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(game.accent.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(game.title).font(.headline)
                Text(game.subtitle).font(.subheadline).foregroundStyle(.secondary)
            }

            Spacer()

            if game.availability == .comingSoon {
                Text("Soon")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}
