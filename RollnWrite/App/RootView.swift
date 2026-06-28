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

    var body: some View {
        NavigationStack {
            List {
                Section("Games") {
                    ForEach(GameRegistry.playable, id: \.id) { game in
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
            .sheet(item: $rulesToShow) { wrapper in
                RulesView(document: wrapper.document)
            }
        }
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
