//
//  DiceRoller.swift
//  RollnWrite – Core
//
//  Optional, purely informational in-app dice roller (issue #30).
//
//  A game that declares its physical dice (`GameDefinition.diceSet`) gets a
//  die toggle in the `ScorecardScaffold` header; switching it on shows this
//  compact strip between the header and the board. Rolling NEVER marks cells
//  and never touches an engine — the app stays a pure scorecard; the strip
//  merely replaces the physical dice on the table for players who left theirs
//  at home. The dice-shown preference persists per game; roll results do not.
//
//  The scaffold discovers the dice via the `\.gameDiceSet` environment value,
//  injected by each `GameDefinition.makeScorecardView()` — so adding a roller
//  to a game touches only its definition file (OCP), never its views.
//

import SwiftUI
import UIKit

// MARK: - Die specification

/// One physical die of a game, as declared by its `GameDefinition`.
public struct DieSpec: Equatable, Sendable {
    /// English colour name ("White", "Red", …), localised for accessibility
    /// labels like "Red die: 4".
    public let name: String
    /// The die's display colour — or, when `themed`, the STANDARD colour fed
    /// to the app-wide `DiceTheme` nearest-colour mapping.
    public let color: Color
    /// Whether the face is light (white/yellow) so pips must be dark. Only
    /// consulted for fixed colours; themed dice get their contrast colour
    /// from `DiceTheme`.
    public let isLight: Bool
    /// Themed dice follow the player's physical dice palette: all themed dice
    /// of a set are resolved together (uniquely) through
    /// `DiceTheme.shared.mapped(standard:)`, exactly like the Clever board
    /// areas. Fixed dice (`false`) always show `color` as-is.
    public let themed: Bool

    public init(name: String, color: Color, isLight: Bool = false, themed: Bool = false) {
        self.name = name
        self.color = color
        self.isLight = isLight
        self.themed = themed
    }

    /// The standard white die (light face, dark pips). Its colour matches the
    /// default palette's white slot, so themed mapping is an identity for the
    /// classic dice set.
    public static func white(themed: Bool = false) -> DieSpec {
        DieSpec(name: "White",
                color: Color(red: 0.88, green: 0.89, blue: 0.92),
                isLight: true,
                themed: themed)
    }
}

// MARK: - Environment plumbing

/// `GameDefinition.makeScorecardView()` injects the game's dice here so the
/// shared `ScorecardScaffold` can offer the roller without any change to the
/// individual scorecard views. Defaults to `nil`: no dice, no roller.
private struct GameDiceSetKey: EnvironmentKey {
    static let defaultValue: [DieSpec]? = nil
}

public extension EnvironmentValues {
    var gameDiceSet: [DieSpec]? {
        get { self[GameDiceSetKey.self] }
        set { self[GameDiceSetKey.self] = newValue }
    }
}

// MARK: - Roller strip

/// A compact horizontal strip of rollable dice. Sits between the scaffold
/// header and the board (boards are GeometryReader-driven and simply adapt).
///
/// Interactions:
/// - "Roll" button — or a tap anywhere on the strip background — rolls every
///   die that isn't held, with a brief tumble animation and a light haptic.
/// - Tapping a single die HOLDS it (dimmed + lock badge): re-rolls keep it,
///   which mirrors the Clever "silver platter" draft flow.
/// - Long-pressing the strip clears all holds.
///
/// Roll state is deliberately transient (`@State`): results are reference
/// only and are never persisted or handed to a game engine.
@MainActor
public struct DiceRollerStrip: View {
    private let dice: [DieSpec]

    /// Observed so themed dice recolour live when Settings edits the palette.
    @ObservedObject private var theme = DiceTheme.shared

    @State private var faces: [Int]
    @State private var wobble: [Double]
    @State private var held: Set<Int> = []
    @State private var isRolling = false

    public init(dice: [DieSpec]) {
        self.dice = dice
        _faces = State(initialValue: dice.map { _ in Int.random(in: 1...6) })
        _wobble = State(initialValue: Array(repeating: 0, count: dice.count))
    }

    public var body: some View {
        GeometryReader { geo in
            let side = dieSide(for: geo.size.width)
            HStack(spacing: dieSpacing) {
                ForEach(dice.indices, id: \.self) { i in
                    dieButton(at: i, side: side)
                }
                Spacer(minLength: 4)
                rollButton
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: Self.stripHeight)
        .background(Color(.secondarySystemBackground))
        .contentShape(Rectangle())
        // Tapping the strip background is a second way to roll.
        .onTapGesture { roll() }
        // Long-press clears every hold at once.
        .onLongPressGesture { clearHolds() }
    }

    // MARK: Layout

    private static let stripHeight: CGFloat = 58
    private let dieSpacing: CGFloat = 8
    /// Space reserved for the Roll button + paddings when sizing dice.
    private let reservedWidth: CGFloat = 130

    private func dieSide(for width: CGFloat) -> CGFloat {
        let count = CGFloat(max(1, dice.count))
        let free = width - reservedWidth - (count - 1) * dieSpacing
        return max(26, min(44, free / count))
    }

    // MARK: Colours

    /// Face + pip colour per die. Fixed dice use their declared colour;
    /// themed dice are resolved TOGETHER through the app-wide palette so the
    /// assignment is unique — the same rule the Clever boards use.
    private var resolved: [(fill: Color, pip: Color)] {
        var out: [(fill: Color, pip: Color)] = dice.map {
            ($0.color, $0.isLight ? Color.black : Color.white)
        }
        let themedIndices = dice.indices.filter { dice[$0].themed }
        guard !themedIndices.isEmpty else { return out }
        let mapped = theme.mapped(standard: themedIndices.map { dice[$0].color })
        for (k, i) in themedIndices.enumerated() where k < mapped.count {
            out[i] = (mapped[k].color, mapped[k].textColor)
        }
        return out
    }

    // MARK: Subviews

    private func dieButton(at i: Int, side: CGFloat) -> some View {
        let colors = resolved[i]
        let isHeld = held.contains(i)
        return Button { toggleHold(i) } label: {
            DieFace(value: faces[i], fill: colors.fill, pip: colors.pip)
                .frame(width: side, height: side)
                .opacity(isHeld ? 0.45 : 1)
                .overlay(alignment: .topTrailing) {
                    if isHeld {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(Circle().fill(.black.opacity(0.65)))
                            .offset(x: 5, y: -5)
                    }
                }
                .rotationEffect(.degrees(wobble[i]))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(localizedName(i)) die: \(faces[i])"))
        .accessibilityValue(isHeld ? Text("Held") : Text(verbatim: ""))
        .accessibilityHint(isHeld ? Text("Releases this die") : Text("Holds this die during rolls"))
    }

    private var rollButton: some View {
        Button { roll() } label: {
            Label("Roll", systemImage: "dice")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(isRolling || held.count == dice.count)
    }

    private func localizedName(_ i: Int) -> String {
        String(localized: String.LocalizationValue(dice[i].name))
    }

    // MARK: Interactions (informational only — no engine is ever involved)

    private func roll() {
        guard !isRolling, held.count < dice.count else { return }
        isRolling = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task { @MainActor in
            // Quick tumble — randomised faces and a little wobble — then
            // settle. Roughly half a second in total.
            for _ in 0..<5 {
                tumble()
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
            settle()
        }
    }

    private func tumble() {
        withAnimation(.easeInOut(duration: 0.07)) {
            for i in dice.indices where !held.contains(i) {
                faces[i] = Int.random(in: 1...6)
                wobble[i] = Double.random(in: -9...9)
            }
        }
    }

    private func settle() {
        for i in dice.indices where !held.contains(i) {
            faces[i] = Int.random(in: 1...6)
        }
        withAnimation(.easeOut(duration: 0.12)) {
            for i in wobble.indices { wobble[i] = 0 }
        }
        isRolling = false
    }

    private func toggleHold(_ i: Int) {
        if held.contains(i) { held.remove(i) } else { held.insert(i) }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func clearHolds() {
        guard !held.isEmpty else { return }
        held.removeAll()
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Die face

/// A rounded die face with the classic pip arrangements (never numerals).
struct DieFace: View {
    let value: Int
    let fill: Color
    let pip: Color

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let corner = s * 0.22
            ZStack {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
                ForEach(Array(Self.pips(for: value).enumerated()), id: \.offset) { _, p in
                    Circle()
                        .fill(pip)
                        .frame(width: s * 0.17, height: s * 0.17)
                        .position(x: (0.5 + p.x * 0.27) * s,
                                  y: (0.5 + p.y * 0.27) * s)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Classic western pip layouts on a −1…1 grid (2 and 3 run along the
    /// top-right → bottom-left diagonal; 6 is two columns of three).
    static func pips(for value: Int) -> [(x: Double, y: Double)] {
        switch value {
        case 1: return [(0, 0)]
        case 2: return [(1, -1), (-1, 1)]
        case 3: return [(1, -1), (0, 0), (-1, 1)]
        case 4: return [(-1, -1), (1, -1), (-1, 1), (1, 1)]
        case 5: return [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)]
        default: return [(-1, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (1, 1)]
        }
    }
}
