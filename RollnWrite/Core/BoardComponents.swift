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

/// Shared stroke weights for board decorations, relative to the tile size
/// (`min(w, h)`), so rings, dashes and outlines keep one consistent visual
/// scale on every board and screen size.
public enum BoardStroke {
    /// Thin outline weight: slot dashes, boxed-number outlines, chain rings,
    /// tile borders.
    public static func small(_ tile: CGFloat) -> CGFloat { max(1.5, tile * 0.05) }
    /// Emphasis weight: the tap-to-undo ring around the most-recent mark.
    public static func medium(_ tile: CGFloat) -> CGFloat { max(2.5, tile * 0.09) }
}

/// A markable number tile: light rounded cell, coloured number, crossed when
/// marked. Tapping calls `onTap` (the engine decides mark-vs-undo).
/// `forfeited` marks a skipped-forever cell (left of the row's front, or in a
/// locked row) with a subtle diagonal slash so it reads differently from a
/// cell that is merely not-yet-legal.
public struct NumberTile: View {
    let text: String
    let tint: Color
    let marked: Bool
    let legal: Bool
    let undoable: Bool
    let forfeited: Bool
    let w: CGFloat
    let h: CGFloat
    let onTap: () -> Void

    public init(_ text: String, tint: Color, marked: Bool, legal: Bool,
                undoable: Bool = false, forfeited: Bool = false,
                w: CGFloat, h: CGFloat, onTap: @escaping () -> Void) {
        self.text = text; self.tint = tint; self.marked = marked; self.legal = legal
        self.undoable = undoable; self.forfeited = forfeited
        self.w = w; self.h = h; self.onTap = onTap
    }

    public var body: some View {
        let s = min(w, h)
        return Button(action: onTap) {
            ZStack {
                // Keep the tile a clean near-white even when crossed, so the ✗
                // reads clearly on every colour band (the old 0.7 let the band
                // bleed through and the same-colour ✗ vanished, worst on blue).
                RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                    .fill(Color.white.opacity(0.95))
                Text(text)
                    .font(.system(size: s * 0.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                // A forfeited (skipped-forever) cell wears a subtle diagonal
                // slash in the row tint — still dim, but visibly "dead" rather
                // than merely not-yet-legal.
                if forfeited && !marked {
                    Image(systemName: "line.diagonal")
                        .font(.system(size: s * 0.72, weight: .regular))
                        .foregroundStyle(tint.opacity(0.5))
                }
                if marked {
                    Image(systemName: "xmark")
                        .font(.system(size: s * 0.74, weight: .black))
                        .foregroundStyle(tint)
                        .shadow(color: .black.opacity(0.25), radius: 0.5)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .frame(width: w, height: h)
            .overlay(
                RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                    .strokeBorder(tint, lineWidth: undoable ? BoardStroke.medium(s) : 0)
            )
            .animation(.spring(response: 0.26, dampingFraction: 0.6), value: marked)
        }
        .buttonStyle(.plain)
        // NOT `.disabled` — the plain button style dims a disabled label, which
        // made every crossed-but-not-last tile fade toward the band colour (the
        // two-tier crossed look). Crossed cells must all be the SAME near-opaque
        // white; only the undo ring may distinguish the last one.
        .allowsHitTesting(legal || undoable)
        .opacity(marked || legal ? 1 : 0.4)
        .accessibilityValue(marked ? "crossed" : (legal ? "available" : (forfeited ? "forfeited" : "blocked")))
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
    let undoable: Bool
    let w: CGFloat
    let h: CGFloat
    let onTap: (() -> Void)?

    public init(tint: Color, locked: Bool, undoable: Bool = false,
                w: CGFloat, h: CGFloat, onTap: (() -> Void)? = nil) {
        self.tint = tint; self.locked = locked; self.undoable = undoable
        self.w = w; self.h = h; self.onTap = onTap
    }

    public var body: some View {
        let s = min(w, h)
        return ZStack {
            RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                .fill(Color.white.opacity(locked ? 0.95 : 0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                        .strokeBorder(tint, lineWidth: undoable ? BoardStroke.medium(s) : 0)
                )
            Image(systemName: locked ? "lock.fill" : "lock.open")
                .font(.system(size: s * 0.5, weight: .bold))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: w, height: h)
        .animation(.snappy, value: locked)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .accessibilityValue(locked ? "locked" : "open")
        .accessibilityHint(onTap != nil ? "Tap to close this row without scoring" : "")
    }
}

/// A two-colour bonus space (diagonal split fill), e.g. Big Points bonus rows.
public struct BonusTile: View {
    let text: String
    let tintA: Color
    let tintB: Color
    let marked: Bool
    let legal: Bool
    /// Whether colour A / colour B can reach this number (its same-number space
    /// is crossed) — drives which half lights up.
    let aActive: Bool
    let bActive: Bool
    let undoable: Bool
    let onTap: () -> Void

    public init(_ text: String, tintA: Color, tintB: Color, marked: Bool, legal: Bool,
                aActive: Bool = false, bActive: Bool = false,
                undoable: Bool = false, onTap: @escaping () -> Void) {
        self.text = text; self.tintA = tintA; self.tintB = tintB
        self.marked = marked; self.legal = legal
        self.aActive = aActive; self.bActive = bActive
        self.undoable = undoable; self.onTap = onTap
    }

    // A half lights up (full tint) when its colour can reach this number, or the
    // space is crossed. Inactive halves stay a light wash over the near-white
    // base, so an idle bonus space reads as a light tile with a hint of its two
    // colours — never a black hole in dark mode.
    private var aOpacity: Double { (marked || aActive) ? 1 : 0.16 }
    private var bOpacity: Double { (marked || bActive) ? 1 : 0.16 }
    /// Both halves lit (or crossed) → white number on strong colour; otherwise a
    /// dark neutral that stays readable on the light base and the yellow half.
    private var litForWhiteText: Bool { marked || (aActive && bActive) }

    public var body: some View {
        ZStack {
            // Light base, like `NumberTile`: identical in light and dark mode.
            Circle().fill(Color.white.opacity(0.95))
            // Upper-left half = colour A, lower-right half = colour B; each is lit
            // or washed-out independently to show which side enables the bonus.
            Circle().fill(tintA.opacity(aOpacity)).mask(DiagonalHalf(upperLeft: true))
            Circle().fill(tintB.opacity(bOpacity)).mask(DiagonalHalf(upperLeft: false))
            Circle().strokeBorder(.black.opacity(0.18), lineWidth: 1)
            Circle().strokeBorder(.white, lineWidth: undoable ? 2.5 : 0)
            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .foregroundStyle(litForWhiteText ? Color.white : Color.black.opacity(0.55))
                .shadow(color: .black.opacity(litForWhiteText ? 0.35 : 0), radius: 0.5)
            if marked {
                Image(systemName: "xmark").font(.system(size: 18, weight: .black)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 0.5)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .contentShape(Circle())
        .onTapGesture { if (legal && !marked) || undoable { onTap() } }
        .animation(.spring(response: 0.26, dampingFraction: 0.6), value: marked)
        .animation(.snappy, value: aActive)
        .animation(.snappy, value: bActive)
        .accessibilityLabel("Bonus \(text)")
        .accessibilityValue(marked ? "crossed" : (legal ? "available" : "not available"))
        .accessibilityHint(undoable ? "Tap to undo" : "")
    }
}

/// Half of a circle split along the top-right → bottom-left diagonal — the upper-
/// left or the lower-right triangle. Used to colour the two halves of a bonus
/// space independently.
private struct DiagonalHalf: Shape {
    let upperLeft: Bool
    func path(in rect: CGRect) -> Path {
        var p = Path()
        if upperLeft {
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        p.closeSubpath()
        return p
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
                        .strokeBorder(undoable ? .white : .red.opacity(0.7),
                                      lineWidth: undoable ? BoardStroke.medium(h) : BoardStroke.small(h))
                )
            if filled {
                Image(systemName: "xmark").font(.system(size: h * 0.5, weight: .black)).foregroundStyle(.white)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            } else {
                Text("−5").font(.system(size: h * 0.32, weight: .bold)).foregroundStyle(.red)
            }
        }
        .frame(width: h, height: h)
        // Idle boxes stay clearly readable (was 0.5 — the −5 sank into the bar).
        .opacity(filled || isNext ? 1 : 0.62)
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

/// The diamond field printed on several official sheets (X-Change's swap row,
/// Lucky 15's bonus track): a square rotated 45°, with softly rounded points,
/// centred in — and inscribed within — the rect it is given (point-to-point
/// extent = `min(width, height)` minus the inset). `InsettableShape` so
/// `strokeBorder` keeps borders fully inside the tile slot and off the
/// neighbouring tiles.
public struct Diamond: InsettableShape {
    var insetAmount: CGFloat

    public init() { insetAmount = 0 }

    public func path(in rect: CGRect) -> Path {
        // Point-to-point extent of the diamond = the square's diagonal.
        let d = max(0, min(rect.width, rect.height) - 2 * insetAmount)
        let side = d / sqrt(2)
        let square = CGRect(x: -side / 2, y: -side / 2, width: side, height: side)
        // A rounded square at the origin, rotated 45°, moved to the centre.
        let transform = CGAffineTransform(translationX: rect.midX, y: rect.midY)
            .rotated(by: .pi / 4)
        return Path(roundedRect: square, cornerRadius: side * 0.14, style: .continuous)
            .applying(transform)
    }

    public func inset(by amount: CGFloat) -> Diamond {
        var shape = self
        shape.insetAmount += amount
        return shape
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

    /// A horizontally **segmented** band background: one colour per column slot,
    /// in band order (chevron, the number cells, lock, score). This lets a row
    /// whose cells span several colours — e.g. Qwixx Mixx Variant A — show those
    /// colour segments on the *bar itself*, not just on the number tiles.
    ///
    /// `columnWidth`/`gap` must match the band's foreground `HStack` (same `w` per
    /// column, same spacing). Each interior segment spans its slot plus **half the
    /// gap on each side**, so a colour boundary falls in the *middle* of the gap
    /// between two differently-coloured tiles (not hard against one tile), and
    /// runs of the same colour still read as one continuous segment. The first and
    /// last segments absorb the horizontal padding so the strip reaches the band
    /// edges. With a uniform `columns` array this renders identically to
    /// `colourBand`. The content is leading-pinned so the segments line up exactly
    /// with the tiles above them.
    func segmentedColourBand(columns: [Color], columnWidth w: CGFloat, gap: CGFloat,
                             hPad: CGFloat, vPad: CGFloat, corner: CGFloat) -> some View {
        self
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { idx, color in
                        let width: CGFloat = idx == 0
                            ? hPad + w + gap / 2                       // leading pad + slot + half gap
                            : (idx == columns.count - 1 ? w + hPad + gap / 2 // half gap + slot + trailing pad
                                                        : w + gap)           // half gap on each side
                        Rectangle().fill(color).frame(width: width)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
    }
}
