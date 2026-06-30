//
//  BoardComponents.swift
//  RollnWrite – Core
//
//  Reusable, game-agnostic scorecard tiles. Every colour-row game (Qwixx Big
//  Points, classic, all variants) composes these instead of re-implementing tile
//  styling, the crossed-out look, the tap-to-undo ring, and sizing. Parameterised
//  by plain `Color` (not any game's colour enum) so they stay in Core.
//
//  Convention: pass `w`/`h` (tile width/height from `BoardMetrics.tile`); fonts
//  scale off `min(w, h)`. `undoable` rings the cell to show it can be tapped to
//  un-check (the most-recent mark — see CLAUDE.md → tap-to-undo).
//

import SwiftUI

/// A markable number tile: light rounded cell, coloured number, crossed when
/// marked. Tapping calls `onTap` (the engine decides mark-vs-undo).
public struct NumberTile: View {
    let text: String
    let tint: Color
    let marked: Bool
    let legal: Bool
    let undoable: Bool
    let w: CGFloat
    let h: CGFloat
    let onTap: () -> Void

    public init(_ text: String, tint: Color, marked: Bool, legal: Bool,
                undoable: Bool = false, w: CGFloat, h: CGFloat, onTap: @escaping () -> Void) {
        self.text = text; self.tint = tint; self.marked = marked; self.legal = legal
        self.undoable = undoable; self.w = w; self.h = h; self.onTap = onTap
    }

    public var body: some View {
        let s = min(w, h)
        return Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                    .fill(Color.white.opacity(marked ? 0.7 : 0.95))
                Text(text)
                    .font(.system(size: s * 0.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                if marked {
                    Image(systemName: "xmark")
                        .font(.system(size: s * 0.72, weight: .black))
                        .foregroundStyle(tint)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .frame(width: w, height: h)
            .overlay(
                RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                    .strokeBorder(tint, lineWidth: undoable ? 2.5 : 0)
            )
            .animation(.spring(response: 0.26, dampingFraction: 0.6), value: marked)
        }
        .buttonStyle(.plain)
        .disabled(!(legal || undoable))
        .opacity(marked || legal ? 1 : 0.4)
        .accessibilityValue(marked ? "crossed" : (legal ? "available" : "blocked"))
        .accessibilityHint(undoable ? "Tap to undo" : "")
    }
}

/// A row's running score, shown as a dark inline tile at the band's edge.
public struct ScoreTile: View {
    let value: Int
    let w: CGFloat
    let h: CGFloat

    public init(_ value: Int, w: CGFloat, h: CGFloat) {
        self.value = value; self.w = w; self.h = h
    }

    public var body: some View {
        let s = min(w, h)
        return ZStack {
            RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                .fill(Color.black.opacity(0.2))
            Text("\(value)")
                .font(.system(size: s * 0.46, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .minimumScaleFactor(0.3)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
        }
        .frame(width: w, height: h)
    }
}

/// The inline lock indicator at a row's lockable end.
public struct LockTile: View {
    let tint: Color
    let locked: Bool
    let w: CGFloat
    let h: CGFloat

    public init(tint: Color, locked: Bool, w: CGFloat, h: CGFloat) {
        self.tint = tint; self.locked = locked; self.w = w; self.h = h
    }

    public var body: some View {
        let s = min(w, h)
        return ZStack {
            RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                .fill(Color.white.opacity(locked ? 0.95 : 0.42))
            Image(systemName: locked ? "lock.fill" : "lock.open")
                .font(.system(size: s * 0.5, weight: .bold))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: w, height: h)
        .animation(.snappy, value: locked)
        .accessibilityValue(locked ? "locked" : "open")
    }
}

/// A two-colour bonus space (diagonal split fill), e.g. Big Points bonus rows.
public struct BonusTile: View {
    let text: String
    let tintA: Color
    let tintB: Color
    let marked: Bool
    let legal: Bool
    let undoable: Bool
    let onTap: () -> Void

    public init(_ text: String, tintA: Color, tintB: Color, marked: Bool, legal: Bool,
                undoable: Bool = false, onTap: @escaping () -> Void) {
        self.text = text; self.tintA = tintA; self.tintB = tintB
        self.marked = marked; self.legal = legal; self.undoable = undoable; self.onTap = onTap
    }

    private var dimmed: Bool { !marked && !legal }

    public var body: some View {
        ZStack {
            Circle()
                .fill(tintA)
                .overlay(
                    Circle().fill(tintB)
                        .mask(
                            GeometryReader { g in
                                Path { p in
                                    p.move(to: CGPoint(x: g.size.width, y: 0))
                                    p.addLine(to: CGPoint(x: g.size.width, y: g.size.height))
                                    p.addLine(to: CGPoint(x: 0, y: g.size.height))
                                    p.closeSubpath()
                                }
                            }
                        )
                )
                .overlay(Circle().strokeBorder(.black.opacity(0.18), lineWidth: 1))
                .overlay(Circle().strokeBorder(.white, lineWidth: undoable ? 2.5 : 0))
            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .foregroundStyle(.white)
                .shadow(radius: 0.5)
            if marked {
                Image(systemName: "xmark").font(.system(size: 18, weight: .black)).foregroundStyle(.white)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .opacity(dimmed ? 0.3 : 1)
        .contentShape(Circle())
        .onTapGesture { if (legal && !marked) || undoable { onTap() } }
        .animation(.spring(response: 0.26, dampingFraction: 0.6), value: marked)
        .accessibilityLabel("Bonus \(text)")
        .accessibilityHint(undoable ? "Tap to undo" : "")
    }
}

/// One of the four penalty boxes in a board's bottom bar.
public struct PenaltyBox: View {
    let filled: Bool
    let isNext: Bool
    let undoable: Bool
    let size: CGFloat
    let onTap: () -> Void

    public init(filled: Bool, isNext: Bool, undoable: Bool, size: CGFloat, onTap: @escaping () -> Void) {
        self.filled = filled; self.isNext = isNext; self.undoable = undoable
        self.size = size; self.onTap = onTap
    }

    public var body: some View {
        let h = size
        return ZStack {
            RoundedRectangle(cornerRadius: h * 0.2, style: .continuous)
                .fill(filled ? Color.red.opacity(0.85) : Color.gray.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: h * 0.2, style: .continuous)
                        .strokeBorder(undoable ? .white : .red.opacity(0.7), lineWidth: undoable ? 2.5 : 1.5)
                )
            if filled {
                Image(systemName: "xmark").font(.system(size: h * 0.5, weight: .black)).foregroundStyle(.white)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            } else {
                Text("−5").font(.system(size: h * 0.32, weight: .bold)).foregroundStyle(.red)
            }
        }
        .frame(width: h, height: h)
        .opacity(filled || isNext ? 1 : 0.5)
        .onTapGesture { if isNext || undoable { onTap() } }
        .animation(.spring(response: 0.28, dampingFraction: 0.62), value: filled)
        .accessibilityHint(undoable ? "Tap to undo" : "")
    }
}

/// A small dark control button (undo, new game) for a board's bottom bar.
public struct BoardControlButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void

    public init(_ icon: String, size: CGFloat, action: @escaping () -> Void) {
        self.icon = icon; self.size = size; self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .fill(Color.gray.opacity(0.25))
                Image(systemName: icon)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }
}

/// A right-pointing direction chevron at a band's leading edge.
public struct BandChevron: View {
    let w: CGFloat
    let h: CGFloat

    public init(w: CGFloat, h: CGFloat) { self.w = w; self.h = h }

    public var body: some View {
        Image(systemName: "arrowtriangle.right.fill")
            .font(.system(size: min(w, h) * 0.5, weight: .black))
            .foregroundStyle(.black.opacity(0.5))
            .frame(width: w, height: h)
    }
}

public extension View {
    /// Wraps a band's tiles in the full-width coloured-band background.
    func colourBand(tint: Color, hPad: CGFloat, vPad: CGFloat, corner: CGFloat) -> some View {
        self
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
            .frame(maxWidth: .infinity)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
    }
}
