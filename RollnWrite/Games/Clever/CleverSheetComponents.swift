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
//  Pieces: `ScaledSheet` (stretch + scale-to-fit container), `SheetCell` /
//  `SheetWriteCell` (printed-style tiles), `SheetPointsBadge` (starburst points
//  seal), `SheetRoundsBar`, `SheetCircleTrack` (reroll/+1 tracks),
//  `SheetTotalStrip` (bottom summary) and `SheetEditorPager` (the swipeable
//  editor scaffold).
//

import SwiftUI

// MARK: - Scale-to-fit container (with vertical stretch)

/// Renders `content` at its NATURAL (design-space) size, then applies ONE
/// uniform scale so the whole sheet fits the available space — the faithful
/// miniature behaviour of the Clever overviews. No scrolling; works in both
/// orientations; the sheet is TOP-aligned (leftover height goes below, never
/// as a blank band above). Hit-testing is transformed with the scale, so the
/// miniature stays fully interactive.
///
/// **Vertical stretch.** When the available space is taller (relative to its
/// width) than the design, plain uniform scaling leaves a large slack band.
/// Pass `maxStretch > 1` and build the content from the `stretch` factor the
/// closure receives: multiply cell/track/band HEIGHTS and vertical paddings by
/// it (keep the design WIDTH fixed, and never apply a non-uniform
/// `scaleEffect` — that would distort glyphs). The factor is
/// `clamp(availableAspect / naturalAspect, 1...maxStretch)`, derived from an
/// invisible probe of the content at `stretch == 1`, so the stretched sheet
/// consumes the height and the remaining fit is still one uniform scale.
struct ScaledSheet<Content: View>: View {
    /// Natural size of the design at `stretch == 1` (the probe).
    @State private var base: CGSize = .zero
    /// Natural size of the design at the current stretch factor.
    @State private var natural: CGSize = .zero
    private let maxStretch: CGFloat
    private let content: (CGFloat) -> Content

    init(maxStretch: CGFloat = 1, @ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.maxStretch = maxStretch
        self.content = content
    }

    /// Convenience for stretch-agnostic content (pure scale-to-fit).
    init(@ViewBuilder content: @escaping () -> Content) {
        self.init { _ in content() }
    }

    var body: some View {
        GeometryReader { geo in
            let stretch = stretchFactor(for: geo.size)
            let scale: CGFloat = natural == .zero ? 1 :
                min(geo.size.width / natural.width, geo.size.height / natural.height)
            ZStack(alignment: .top) {
                if maxStretch > 1 {
                    // Invisible probe: measures the natural (stretch 1) size
                    // that the stretch factor is derived from.
                    content(1)
                        .fixedSize()
                        .hidden()
                        .allowsHitTesting(false)
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { base = $0 }
                }
                content(stretch)
                    .fixedSize()
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { natural = $0 }
                    .scaleEffect(scale, anchor: .top)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            // Hide the un-scaled frames before the first measurements land.
            .opacity(natural == .zero || (maxStretch > 1 && base == .zero) ? 0 : 1)
        }
    }

    private func stretchFactor(for avail: CGSize) -> CGFloat {
        guard maxStretch > 1, base.width > 0, base.height > 0, avail.width > 0 else { return 1 }
        let naturalAspect = base.height / base.width
        let availAspect = avail.height / avail.width
        return min(max(availAspect / naturalAspect, 1), maxStretch)
    }
}

/// Width-only scale-to-fit for SCROLLING contexts, where `ScaledSheet`'s
/// `GeometryReader` cannot work (a `ScrollView` proposes no usable height).
/// Renders `content` at its natural size, scales it down uniformly to the
/// GIVEN width if needed (never up), and reserves exactly the scaled height —
/// so list rows stack tightly with no dead space. Hit-testing scales along.
struct WidthScaledCard<Content: View>: View {
    @State private var natural: CGSize = .zero
    let width: CGFloat
    private let content: Content

    init(width: CGFloat, @ViewBuilder content: () -> Content) {
        self.width = width
        self.content = content()
    }

    var body: some View {
        let scale: CGFloat = natural.width > 0 ? min(1, width / natural.width) : 1
        content
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { natural = $0 }
            .scaleEffect(scale, anchor: .top)
            .frame(width: width,
                   height: natural == .zero ? nil : natural.height * scale,
                   alignment: .top)
            // Hide the un-scaled frame before the first measurement lands.
            .opacity(natural == .zero ? 0 : 1)
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
    /// Cell height; defaults to `size` (square). A stretched sheet passes a
    /// taller value — the width stays the design width.
    var height: CGFloat? = nil
    var fontScale: CGFloat = 0.5
    let onTap: () -> Void

    private var h: CGFloat { height ?? size }
    /// Font reference: the width, stepped up modestly (capped) as the cell
    /// stretches taller — glyphs scale uniformly, never distort.
    private var fontBase: CGFloat { size * min(1 + 0.35 * (max(h / size, 1) - 1), 1.25) }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .fill(Color.white)
                Text(label)
                    .font(.system(size: fontBase * fontScale, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                    .padding(1)
                if marked {
                    Image(systemName: "xmark")
                        .font(.system(size: fontBase * 0.6, weight: .black))
                        .foregroundStyle(ink.opacity(0.88))
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .frame(width: size, height: h)
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
    /// Cell height; defaults to `size` (square). See `SheetCell.height`.
    var height: CGFloat? = nil
    let onTap: () -> Void

    private var h: CGFloat { height ?? size }
    private var fontBase: CGFloat { size * min(1 + 0.35 * (max(h / size, 1) - 1), 1.25) }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .fill(Color.white)
                if let value {
                    Text("\(value)")
                        .font(.system(size: fontBase * 0.52, weight: .heavy, design: .rounded))
                        .foregroundStyle(ink)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                } else if let hint {
                    // Near-full tint: combined with the cell's blocked-state
                    // dimming (×0.55) the ghost hint reads clearly (~0.45
                    // effective) while a written value is full-strength ink.
                    Text(hint)
                        .font(.system(size: fontBase * 0.46, weight: .heavy, design: .rounded))
                        .foregroundStyle(tint.opacity(0.85))
                }
            }
            .frame(width: size, height: h)
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

/// The "1 2 3 4 5 6" rounds bar: a white number tile per round with a badge
/// slot underneath (bonus icon or player-count marker). Rounds from
/// `darkFrom` render on black, as printed (they only happen with fewer
/// players). Pass `crossed` + `tap` to make the tiles crossable (bookkeeping
/// only — crossing a round is never a game move); omit them for a
/// display-only bar.
struct SheetRoundsBar<Badge: View>: View {
    let rounds: Int
    let darkFrom: Int
    let cell: CGFloat
    var ink: Color = .black
    /// Vertical stretch factor — multiplies tile heights and vertical
    /// paddings only (widths and glyph geometry stay the design's).
    var stretch: CGFloat = 1
    /// Rounds crossed off by the player (ink ✗ over the number tile).
    var crossed: Set<Int> = []
    /// Tap handler for a round tile; `nil` keeps the bar display-only.
    var tap: ((Int) -> Void)? = nil
    @ViewBuilder let badge: (Int) -> Badge

    private var fontBase: CGFloat { cell * min(1 + 0.35 * (max(stretch, 1) - 1), 1.25) }

    var body: some View {
        HStack(spacing: cell * 0.12) {
            ForEach(0..<rounds, id: \.self) { r in
                VStack(spacing: cell * 0.1 * stretch) {
                    Button { tap?(r) } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: cell * 0.2, style: .continuous)
                                .fill(Color.white)
                            Text("\(r + 1)")
                                .font(.system(size: fontBase * 0.52, weight: .heavy, design: .rounded))
                                .foregroundStyle(ink)
                            if crossed.contains(r) {
                                Image(systemName: "xmark")
                                    .font(.system(size: fontBase * 0.55, weight: .black))
                                    .foregroundStyle(ink.opacity(0.88))
                                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                            }
                        }
                        .frame(width: cell, height: cell * 0.85 * stretch)
                        .animation(.spring(response: 0.26, dampingFraction: 0.6),
                                   value: crossed.contains(r))
                    }
                    .buttonStyle(.plain)
                    .disabled(tap == nil)
                    .accessibilityLabel(Text("Round \(r + 1)"))
                    .accessibilityValue(crossed.contains(r) ? "marked" : "available")
                    badge(r)
                        .frame(height: cell * 0.5)
                }
                .padding(.horizontal, cell * 0.12)
                .padding(.vertical, cell * 0.12 * stretch)
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
/// circles that cross off used actions. Pass `earned` to light up how many
/// slots the player has actually earned — each circle then shows one of
/// three states: USED (ink fill + white ✗), AVAILABLE (earned but unspent:
/// near-white fill + solid ink ring), NOT EARNED (faint, disabled). The
/// default (`.max`) keeps every slot available (the pre-counting behaviour).
struct SheetCircleTrack<Icon: View>: View {
    let slots: Int
    let used: Set<Int>
    var earned: Int = .max
    let diameter: CGFloat
    var ink: Color = .black
    /// Vertical stretch — multiplies the track's vertical padding only
    /// (circles stay circular).
    var stretch: CGFloat = 1
    private let icon: Icon
    private let tap: (Int) -> Void

    init(slots: Int, used: Set<Int>, earned: Int = .max, diameter: CGFloat,
         ink: Color = .black, stretch: CGFloat = 1,
         @ViewBuilder icon: () -> Icon, tap: @escaping (Int) -> Void) {
        self.slots = slots
        self.used = used
        self.earned = earned
        self.diameter = diameter
        self.ink = ink
        self.stretch = stretch
        self.icon = icon()
        self.tap = tap
    }

    var body: some View {
        HStack(spacing: diameter * 0.4) {
            icon
            ForEach(0..<slots, id: \.self) { s in
                let isUsed = used.contains(s)
                let isEarned = s < earned
                Button { tap(s) } label: {
                    ZStack {
                        if isUsed {
                            Circle().fill(ink)
                            Circle().strokeBorder(Color.white, lineWidth: diameter * 0.12)
                            Image(systemName: "xmark")
                                .font(.system(size: diameter * 0.5, weight: .black))
                                .foregroundStyle(.white)
                        } else if isEarned {
                            // AVAILABLE: clearly inviting — a near-white fill
                            // with a solid ink ring, ready to be spent.
                            Circle().fill(Color.white.opacity(0.9))
                            Circle().strokeBorder(ink, lineWidth: diameter * 0.12)
                        } else {
                            // NOT EARNED: faint ghost of the printed circle.
                            Circle().fill(Color.white.opacity(0.15))
                            Circle().strokeBorder(Color.white.opacity(0.45),
                                                  lineWidth: diameter * 0.12)
                        }
                    }
                    .frame(width: diameter, height: diameter)
                    .animation(.snappy, value: isUsed)
                    .animation(.snappy, value: isEarned)
                }
                .buttonStyle(.plain)
                .disabled(!isUsed && !isEarned)
                .accessibilityValue(isUsed ? "marked" : (isEarned ? "available" : "not earned yet"))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, diameter * 0.45)
        .padding(.vertical, diameter * 0.3 * stretch)
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
