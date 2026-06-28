//
//  Clever4Models.swift
//  RollnWrite – Clever4
//
//  "Clever 4ever" by Wolfgang Warsch / Schmidt Spiele (art. 49424).
//
//  Clever 4ever's board is the most complex of the series — the grey area uses
//  polyomino crossings and the blue area uses (blue,white) coordinates, with
//  per-row/column point tables printed only on the physical sheet. Rather than
//  guess those tables, this v1 is an honest scorecard *calculator*: you enter
//  each of the five area totals and it computes foxes and the grand total.
//  (The interactive board can be added once the official sheet is transcribed.)
//

import SwiftUI

public enum Clever4Area: String, Codable, CaseIterable, Identifiable {
    case yellow, blue, grey, green, pink

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    public var defaultColor: ThemeColor {
        switch self {
        case .yellow: return .yellow
        case .blue:   return .blue
        case .grey:   return .gray
        case .green:  return .green
        case .pink:   return .pink
        }
    }
}

public struct Clever4ColorTheme: Codable, Equatable {
    public var yellow: ThemeColor = .yellow
    public var blue: ThemeColor = .blue
    public var grey: ThemeColor = .gray
    public var green: ThemeColor = .green
    public var pink: ThemeColor = .pink

    public init() {}

    public func value(for area: Clever4Area) -> ThemeColor {
        switch area {
        case .yellow: return yellow
        case .blue:   return blue
        case .grey:   return grey
        case .green:  return green
        case .pink:   return pink
        }
    }

    public mutating func set(_ c: ThemeColor, for area: Clever4Area) {
        switch area {
        case .yellow: yellow = c
        case .blue:   blue = c
        case .grey:   grey = c
        case .green:  green = c
        case .pink:   pink = c
        }
    }
}

public struct Clever4State: Codable, Equatable {
    public var totals: [String: Int] = [:]   // area.rawValue -> entered total
    public var foxes: Int = 0
    public var theme = Clever4ColorTheme()

    public init() {}
}
