//
//  CleverSheetComponents.swift
//  RollnWrite – Clever
//
//  Reusable "printed sheet" chrome for the Clever-family scorecard redesign.
//  Clever 1 is the PILOT: its board is a faithful one-screen miniature of the
//  printed score sheet, and tapping an area opens a paged editor. Everything
//  here is parameterised by plain values (`Color`, closures, generic views) —
//  no Clever 1 types — so Clever 2/3/4 can adopt the same idioms verbatim.
//
//  Pieces: `ScaledSheet` (uniform scale-to-fit container), `SheetCell` /
//  `SheetWriteCell` (printed-style tiles), `SheetPointsBadge` (starburst points
//  seal), `SheetRoundsBar`, `SheetCircleTrack` (reroll/+1 tracks),
//  `SheetScratchBoxes`, `SheetTotalStrip` (bottom summary) and
//  `SheetEditorPager` (the swipeable editor scaffold).
//

import SwiftUI

// MARK: - Scale-to-fit container

/// Renders `content` at its NATURAL (design-space) size, then applies ONE
/// uniform scale so the whole sheet fits the available space — the faithful
/// miniature behaviour of the Clever overviews. No scrolling; works in both
/// orientations; leftover space centres the sheet. Hit-testing is transformed
/// with the scale, so the miniature stays fully interactive.
struct ScaledSheet<Content: View>: View {
    @State private var natural: CGSize = .zero
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            let scale: CGFloat = natural == .zero ? 1 :
                min(geo.size.width / natural.width, geo.size.height / natural.height)
            content
                .fixedSize()
                .onGeometryChange(for: CGSize.self) { $0.size } action: { natural = $0 }
                .scaleEffect(scale, anchor: .center)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                // Hide the single un-scaled frame before the first measurement.
                .opacity(natural == .zero ? 0 : 1)
        }
    }
}

// MARK: - Printed-style cells

/// A printed-sheet cell: white rounded tile, coloured label, INK cross when
/// marked (like the printed ✗s), ink ring when tap-undoable. Disabled taps
/// pass through, so the surrounding area can catch them to open its editor.
struct SheetCell: View {
    let label: String
    let tint: Color
    var ink: Color = .black
    let marked: Bool
    let legal: Bool
    var undoable: Bool = false
    let size: CGFloat
    var fontScale: CGFloat = 0.5
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .fill(Color.white)
                Text(label)
                    .font(.system(size: size * fontScale, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                    .padding(1)
                if marked {
                    Image(systemName: "xmark")
                        .font(.system(size: size * 0.6, weight: .black))
                        .foregroundStyle(ink.opacity(0.88))
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .strokeBorder(ink, lineWidth: undoable ? size * 0.06 : 0)
            )
            .animation(.spring(response: 0.26, dampingFraction: 0.6), value: marked)
        }
        .buttonStyle(.plain)
        .disabled(!(legal || undoable))
        .opacity(marked || legal || undoable ? 1 : 0.55)
        .accessibilityLabel(label)
        .accessibilityValue(marked ? "marked" : (legal ? "available" : "blocked"))
        .accessibilityHint(undoable ? "Tap to undo" : "")
    }
}

/// A write-in cell (orange/purple style): shows the written value in ink, a
/// faint printed hint (e.g. "×2") when empty, and a dashed tint ring on the
/// next writable cell. Disabled taps pass through like `SheetCell`.
struct SheetWriteCell: View {
    let value: Int?
    var hint: String? = nil
    let tint: Color
    var ink: Color = .black
    let isNext: Bool
    var undoable: Bool = false
    let size: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .fill(Color.white)
                if let value {
                    Text("\(value)")
                        .font(.system(size: size * 0.52, weight: .heavy, design: .rounded))
                        .foregroundStyle(ink)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                } else if let hint {
                    Text(hint)
                        .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
                        .foregroundStyle(tint.opacity(0.45))
                }
            }
            .frame(width: size, height: size)
            .overlay {
                if isNext, value == nil {
                    RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: size * 0.05,
                                                         dash: [size * 0.12, size * 0.09]))
                        .foregroundStyle(tint)
                }
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .strokeBorder(ink, lineWidth: undoable ? size * 0.06 : 0)
            }
            .animation(.snappy, value: value)
        }
        .buttonStyle(.plain)
        .disabled(!(isNext || undoable))
        .opacity(value != nil || isNext ? 1 : 0.55)
        .accessibilityValue(value.map { "\($0)" } ?? (isNext ? "available" : "blocked"))
        .accessibilityHint(undoable ? "Tap to undo" : "")
    }
}

// MARK: - Points badge

/// A starburst "points" seal as printed above the scale rows (green scale,
/// blue scale, yellow column values). Highlight the currently-achieved value.
struct SheetPointsBadge: View {
    let value: Int
    let tint: Color
    var fill: Color = .white
    var size: CGFloat = 22
    var highlighted: Bool = false

    var body: some View {
        ZStack {
            Image(systemName: "seal.fill")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(highlighted ? Color.black : fill)
            Text("\(value)")
                .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
                .foregroundStyle(highlighted ? .white : tint)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: size * 0.9)
        }
        .frame(width: size * 1.15, height: size * 1.15)
        .animation(.snappy, value: highlighted)
    }
}

// MARK: - Header chrome

/// The big empty "extra dice" scratch boxes at the sheet's top-left. Purely
/// decorative, exactly as printed (players jot leftover dice there on paper).
struct SheetScratchBoxes: View {
    var count: Int = 3
    var box: CGFloat = 48
    var ink: Color = .black

    var body: some View {
        VStack(spacing: box * 0.18) {
            ForEach(0..<count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: box * 0.22, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: box * 0.22, style: .continuous)
                            .strokeBorder(ink, lineWidth: box * 0.07)
                    )
                    .frame(width: box, height: box)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The "1 2 3 4 5 6" rounds bar: a white number tile per round with a badge
/// slot underneath (bonus icon or player-count marker). Rounds from
/// `darkFrom` render on black, as printed (they only happen with fewer
/// players). Informative only — no game state.
struct SheetRoundsBar<Badge: View>: View {
    let rounds: Int
    let darkFrom: Int
    let cell: CGFloat
    var ink: Color = .black
    @ViewBuilder let badge: (Int) -> Badge

    var body: some View {
        HStack(spacing: cell * 0.12) {
            ForEach(0..<rounds, id: \.self) { r in
                VStack(spacing: cell * 0.1) {
                    ZStack {
                        RoundedRectangle(cornerRadius: cell * 0.2, style: .continuous)
                            .fill(Color.white)
                        Text("\(r + 1)")
                            .font(.system(size: cell * 0.52, weight: .heavy, design: .rounded))
                            .foregroundStyle(ink)
                    }
                    .frame(width: cell, height: cell * 0.85)
                    badge(r)
                        .frame(height: cell * 0.5)
                }
                .padding(cell * 0.12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: cell * 0.18, style: .continuous)
                        .fill(r >= darkFrom ? Color.black : Color(white: 0.3))
                )
            }
        }
    }
}

/// A grey action track (reroll / +1): a leading icon badge and tappable
/// circles that cross off used actions.
struct SheetCircleTrack<Icon: View>: View {
    let slots: Int
    let used: Set<Int>
    let diameter: CGFloat
    var ink: Color = .black
    private let icon: Icon
    private let tap: (Int) -> Void

    init(slots: Int, used: Set<Int>, diameter: CGFloat, ink: Color = .black,
         @ViewBuilder icon: () -> Icon, tap: @escaping (Int) -> Void) {
        self.slots = slots
        self.used = used
        self.diameter = diameter
        self.ink = ink
        self.icon = icon()
        self.tap = tap
    }

    var body: some View {
        HStack(spacing: diameter * 0.4) {
            icon
            ForEach(0..<slots, id: \.self) { s in
                let isUsed = used.contains(s)
                Button { tap(s) } label: {
                    ZStack {
                        Circle().fill(isUsed ? ink : Color.white.opacity(0.35))
                        Circle().strokeBorder(Color.white, lineWidth: diameter * 0.12)
                        if isUsed {
                            Image(systemName: "xmark")
                                .font(.system(size: diameter * 0.5, weight: .black))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: diameter, height: diameter)
                }
                .buttonStyle(.plain)
                .accessibilityValue(isUsed ? "marked" : "available")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, diameter * 0.45)
        .padding(.vertical, diameter * 0.3)
        .background(
            RoundedRectangle(cornerRadius: diameter * 0.55, style: .continuous)
                .fill(Color(white: 0.62))
        )
    }
}

// MARK: - Total strip

/// The bottom summary strip: one colour-outlined box per area (plus fox),
/// "+" separators, and the "=" Total box — exactly like the printed footer.
struct SheetTotalStrip: View {
    struct Entry {
        let value: String
        var caption: String? = nil
        let tint: Color
    }

    let entries: [Entry]
    let total: Int
    var ink: Color = .black
    var height: CGFloat = 46

    var body: some View {
        HStack(spacing: height * 0.1) {
            ForEach(entries.indices, id: \.self) { i in
                if i > 0 { separator("plus") }
                box(entries[i])
            }
            separator("equal")
            totalBox
        }
    }

    private func separator(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: height * 0.26, weight: .black))
            .foregroundStyle(Color(white: 0.45))
    }

    private func box(_ e: Entry) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: height * 0.22, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: height * 0.22, style: .continuous)
                        .strokeBorder(e.tint, lineWidth: height * 0.07)
                )
            VStack(spacing: 0) {
                Text(e.value)
                    .font(.system(size: height * 0.38, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                if let caption = e.caption {
                    Text(caption)
                        .font(.system(size: height * 0.18, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    private var totalBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: height * 0.22, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: height * 0.22, style: .continuous)
                        .strokeBorder(ink, lineWidth: height * 0.09)
                )
            Text("\(total)")
                .font(.system(size: height * 0.42, weight: .heavy, design: .rounded).monospacedDigit())
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(ink)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .frame(height: height * 1.08)
        .overlay(alignment: .bottomTrailing) {
            Text("Total")
                .font(.system(size: height * 0.19, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, height * 0.1)
                .padding(.vertical, 1)
                .background(ink)
                .padding(height * 0.08)
        }
        .animation(.snappy, value: total)
    }
}

// MARK: - Paged editor scaffold

/// The editor sheet's scaffold: a header (area dot + title + accessory +
/// Done) above a `.page`-style `TabView` — one big, comfortable page per
/// sheet section. Swiping left/right moves between areas without closing.
/// Generic over the section type so every Clever reuses it.
struct SheetEditorPager<Section: Hashable, Content: View, Accessory: View>: View {
    private let sections: [Section]
    @Binding private var selection: Section
    private let title: (Section) -> String
    private let tint: (Section) -> Color
    private let accessory: Accessory
    private let content: (Section) -> Content

    @Environment(\.dismiss) private var dismiss

    init(sections: [Section],
         selection: Binding<Section>,
         title: @escaping (Section) -> String,
         tint: @escaping (Section) -> Color,
         @ViewBuilder accessory: () -> Accessory,
         @ViewBuilder content: @escaping (Section) -> Content) {
        self.sections = sections
        self._selection = selection
        self.title = title
        self.tint = tint
        self.accessory = accessory()
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Circle()
                    .fill(tint(selection))
                    .frame(width: 14, height: 14)
                Text(LocalizedStringKey(title(selection)))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                accessory
                Button { dismiss() } label: {
                    Text("Done").font(.body.weight(.semibold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            TabView(selection: $selection) {
                ForEach(sections, id: \.self) { section in
                    content(section)
                        .tag(section)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }
}
