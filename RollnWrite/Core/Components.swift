//
//  Components.swift
//  RollnWrite – Core
//
//  Reusable, game-agnostic UI building blocks shared by every scorecard.
//

import SwiftUI

/// Square or round cell, matching the printed scorecards.
public enum CellShape {
    case square
    case circle
}

/// A single tappable number/marker box on a scorecard.
///
/// Pure and stateless: it renders the state it's told and reports taps. All
/// rule enforcement lives in the game engine, so the cell only needs to know
/// whether a tap is currently *legal* and whether it is *marked*.
public struct MarkableCell: View {
    let label: String
    let tint: Color
    let textColor: Color
    let isMarked: Bool
    /// Whether marking this cell is currently a legal move.
    let isLegal: Bool
    /// Whether the cell responds to taps at all (lock indicators don't).
    let isInteractive: Bool
    var shape: CellShape = .square
    var onTap: () -> Void = {}

    private var dimmed: Bool { !isMarked && !(isInteractive && isLegal) }

    public init(
        label: String,
        tint: Color,
        textColor: Color,
        isMarked: Bool,
        isLegal: Bool,
        isInteractive: Bool,
        shape: CellShape = .square,
        onTap: @escaping () -> Void = {}
    ) {
        self.label = label
        self.tint = tint
        self.textColor = textColor
        self.isMarked = isMarked
        self.isLegal = isLegal
        self.isInteractive = isInteractive
        self.shape = shape
        self.onTap = onTap
    }

    public var body: some View {
        ZStack {
            fill
            Text(label)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .foregroundStyle(textColor)
                .padding(1)
            if isMarked {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(textColor)
            }
        }
        .opacity(dimmed ? 0.3 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isInteractive, isLegal, !isMarked else { return }
            onTap()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(isMarked ? "marked" : (isLegal ? "available" : "blocked"))
        .accessibilityAddTraits(isInteractive && isLegal && !isMarked ? .isButton : [])
        .animation(.easeOut(duration: 0.12), value: isMarked)
    }

    @ViewBuilder private var fill: some View {
        switch shape {
        case .square:
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(.black.opacity(0.18), lineWidth: 1)
                )
        case .circle:
            Circle()
                .fill(tint)
                .overlay(Circle().strokeBorder(.black.opacity(0.18), lineWidth: 1))
        }
    }
}

/// Small rounded pill used in score summaries.
public struct ScoreChip: View {
    let title: String
    let value: String
    let tint: Color

    public init(title: String, value: String, tint: Color) {
        self.title = title
        self.value = value
        self.tint = tint
    }

    public var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint.opacity(0.5), lineWidth: 1)
        )
    }
}
