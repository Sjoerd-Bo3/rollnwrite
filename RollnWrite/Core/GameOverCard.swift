//
//  GameOverCard.swift
//  RollnWrite – Core
//
//  A reusable, game-agnostic "game over" results overlay. A game's board shows
//  it when the engine reports the game is finished: a titled card with a
//  breakdown of score lines, the final total, and New game / View board actions.
//  Parameterised by plain values (label / detail / value / tint) so it stays in
//  Core and every game can reuse it.
//

import SwiftUI

public struct GameOverCard: View {
    /// One row of the breakdown (e.g. a colour's score, or the penalty line).
    public struct Line: Identifiable {
        public let id = UUID()
        public let label: String
        public let value: Int
        public let tint: Color
        public init(label: String, value: Int, tint: Color = .primary) {
            self.label = label; self.value = value; self.tint = tint
        }
    }

    let title: String
    let subtitle: String?
    let lines: [Line]
    let total: Int
    let onNewGame: () -> Void
    let onDismiss: () -> Void

    public init(title: String = "Game over", subtitle: String? = nil,
                lines: [Line], total: Int,
                onNewGame: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.title = title; self.subtitle = subtitle
        self.lines = lines; self.total = total
        self.onNewGame = onNewGame; self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            // Dimmed backdrop — tap anywhere outside the card to peek at the board.
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 14) {
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 8) {
                    ForEach(lines) { line in
                        HStack {
                            Circle().fill(line.tint).frame(width: 10, height: 10)
                            Text(line.label).font(.system(size: 16, weight: .medium))
                            Spacer(minLength: 16)
                            Text("\(line.value)")
                                .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundStyle(line.value < 0 ? .red : .primary)
                        }
                    }
                    Divider().padding(.vertical, 2)
                    HStack {
                        Text("Total").font(.system(size: 18, weight: .bold))
                        Spacer()
                        Text("\(total)")
                            .font(.system(size: 22, weight: .heavy, design: .rounded).monospacedDigit())
                    }
                }

                HStack(spacing: 10) {
                    Button(action: onDismiss) {
                        Text("View board")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    Button(action: onNewGame) {
                        Text("New game")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .foregroundStyle(.white)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
            .padding(20)
            .frame(maxWidth: 360)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.15)))
            .shadow(radius: 24, y: 8)
            .padding(24)
        }
    }
}
