//
//  DiceTheme.swift
//  RollnWrite – Core
//
//  The player's physical dice colours, as ONE app-wide setting (the dice you
//  own don't change from game to game). Six arbitrary user-picked colour slots,
//  edited in Settings and persisted in UserDefaults as JSON (like `HighScores`).
//
//  Games never store colours themselves: each passes its STANDARD (official)
//  area colours to `mapped(standard:)` and gets back one display colour per
//  area — the nearest palette colour by hue/saturation/brightness, uniquely
//  assigned so no two areas share a die. Game-agnostic: the API takes plain
//  `Color`s, never game types.
//

import SwiftUI
import UIKit

// MARK: - Codable colour

/// A small Codable RGBA value so arbitrary picked colours can be persisted.
public struct RGBAColor: Codable, Equatable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Bridge from SwiftUI `Color` via `UIColor` components.
    public init(_ color: Color) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
    }

    public var color: Color { Color(red: red, green: green, blue: blue, opacity: alpha) }
}

// MARK: - Resolved display colour

/// One display colour resolved from the dice palette, plus a legible text
/// colour to draw on top of it (dark ink on light dice, white on dark).
public struct DiceColor: Equatable {
    public let color: Color
    public let textColor: Color

    public init(_ rgba: RGBAColor) {
        color = rgba.color
        // Perceived luminance decides the overlay ink.
        let luminance = 0.299 * rgba.red + 0.587 * rgba.green + 0.114 * rgba.blue
        textColor = luminance > 0.65 ? .black : .white
    }
}

// MARK: - App-wide theme

/// Observable singleton holding the six dice-colour slots. Views that render a
/// board observe it (`@ObservedObject var diceTheme = DiceTheme.shared`) so an
/// open scorecard recolours immediately when Settings changes the palette.
@MainActor
public final class DiceTheme: ObservableObject {

    public static let shared = DiceTheme()

    public static let slotCount = 6
    private static let storeKey = "rollnwrite.dicetheme.v1"

    /// The classic Clever dice set: white, yellow, blue, green, orange, purple.
    /// The chromatic values match the official area colours used across the
    /// games, so the default palette reproduces the official card look. White
    /// is toned slightly silver so it stays visible on the paper boards.
    public static let defaultPalette: [RGBAColor] = [
        RGBAColor(red: 0.88, green: 0.89, blue: 0.92),  // white
        RGBAColor(red: 0.96, green: 0.80, blue: 0.10),  // yellow
        RGBAColor(red: 0.16, green: 0.45, blue: 0.82),  // blue
        RGBAColor(red: 0.18, green: 0.62, blue: 0.30),  // green
        RGBAColor(red: 0.95, green: 0.52, blue: 0.10),  // orange
        RGBAColor(red: 0.55, green: 0.28, blue: 0.72),  // purple
    ]

    @Published public var palette: [RGBAColor] {
        didSet {
            cache.removeAll()
            save()
        }
    }

    /// Memoised assignments per set of standard colours; cleared on edits.
    private var cache: [[RGBAColor]: [DiceColor]] = [:]

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storeKey),
           let restored = try? JSONDecoder().decode([RGBAColor].self, from: data),
           restored.count == Self.slotCount {
            palette = restored
        } else {
            palette = Self.defaultPalette
        }
    }

    public func resetToDefault() {
        palette = Self.defaultPalette
    }

    private func save() {
        if let data = try? JSONEncoder().encode(palette) {
            UserDefaults.standard.set(data, forKey: Self.storeKey)
        }
    }

    // MARK: - Nearest-colour matching

    /// Given a game's standard area colours, return one display colour per
    /// standard — each the NEAREST palette colour by hue/saturation/brightness,
    /// with unique assignment (greedy: repeatedly take the globally closest
    /// unassigned pair) so no two areas end up on the same die. If a game has
    /// more standards than palette slots, the leftovers reuse plain nearest.
    public func mapped(standard: [Color]) -> [DiceColor] {
        let key = standard.map(RGBAColor.init)
        if let hit = cache[key] { return hit }
        guard !palette.isEmpty else { return key.map(DiceColor.init) }

        let sHSB = key.map(Self.hsb)
        let pHSB = palette.map(Self.hsb)
        var assignment = [Int?](repeating: nil, count: key.count)
        var usedPalette = Set<Int>()

        // Greedy unique assignment: globally closest (standard, palette) pair
        // among the unassigned, repeated until one side runs out.
        while assignment.contains(nil), usedPalette.count < palette.count {
            var best: (s: Int, p: Int, d: Double)?
            for s in sHSB.indices where assignment[s] == nil {
                for p in pHSB.indices where !usedPalette.contains(p) {
                    let d = Self.distance(sHSB[s], pHSB[p])
                    if best == nil || d < best!.d { best = (s, p, d) }
                }
            }
            guard let hit = best else { break }
            assignment[hit.s] = hit.p
            usedPalette.insert(hit.p)
        }
        for s in assignment.indices where assignment[s] == nil {
            assignment[s] = pHSB.indices.min {
                Self.distance(sHSB[s], pHSB[$0]) < Self.distance(sHSB[s], pHSB[$1])
            }
        }

        let result = assignment.map { DiceColor(palette[$0!]) }
        cache[key] = result
        return result
    }

    private struct HSB {
        var hue: Double         // 0…1, circular
        var saturation: Double  // 0…1
        var brightness: Double  // 0…1
    }

    private static func hsb(_ c: RGBAColor) -> HSB {
        let maxC = max(c.red, c.green, c.blue)
        let minC = min(c.red, c.green, c.blue)
        let delta = maxC - minC
        let brightness = maxC
        let saturation = maxC == 0 ? 0 : delta / maxC
        var hue = 0.0
        if delta > 0 {
            switch maxC {
            case c.red:   hue = ((c.green - c.blue) / delta).truncatingRemainder(dividingBy: 6)
            case c.green: hue = (c.blue - c.red) / delta + 2
            default:      hue = (c.red - c.green) / delta + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return HSB(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// Below this saturation a colour counts as achromatic (white/silver/grey).
    private static let greyThreshold = 0.2

    /// Distance in HSB space. Hue is meaningless for achromatic colours, so a
    /// grey standard matches by brightness among the grey palette entries
    /// first; chromatic↔achromatic pairs get a heavy penalty so a grey area
    /// only borrows a coloured die when no grey die is left (and vice versa).
    private static func distance(_ a: HSB, _ b: HSB) -> Double {
        let aGrey = a.saturation < greyThreshold
        let bGrey = b.saturation < greyThreshold
        if aGrey && bGrey { return abs(a.brightness - b.brightness) }
        if aGrey != bGrey {
            return 10 + abs(a.saturation - b.saturation) + abs(a.brightness - b.brightness)
        }
        let dh = min(abs(a.hue - b.hue), 1 - abs(a.hue - b.hue)) * 2  // 0…1
        return dh * 3 + abs(a.saturation - b.saturation) + abs(a.brightness - b.brightness) * 0.5
    }
}
