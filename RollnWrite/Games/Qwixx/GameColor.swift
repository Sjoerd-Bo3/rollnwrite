//
//  GameColor.swift
//  RollnWrite – Qwixx
//
//  The four colour tracks of a Qwixx scorecard.
//

import SwiftUI

/// A Qwixx colour row. Red & yellow ascend 2→12; green & blue descend 12→2.
public enum GameColor: String, CaseIterable, Codable, Identifiable {
    case red, yellow, green, blue

    public var id: String { rawValue }

    public var displayName: String {
        rawValue.capitalized
    }

    /// Red and yellow run 2…12 left-to-right; green and blue run 12…2.
    public var isAscending: Bool {
        self == .red || self == .yellow
    }

    /// The 11 numbers of this row, in printed left-to-right order.
    public var numbers: [Int] {
        isAscending ? Array(2...12) : Array((2...12).reversed())
    }

    /// Fill colour for cells.
    public var tint: Color {
        switch self {
        case .red:    return Color(red: 0.86, green: 0.18, blue: 0.18)
        case .yellow: return Color(red: 0.98, green: 0.80, blue: 0.10)
        case .green:  return Color(red: 0.18, green: 0.62, blue: 0.30)
        case .blue:   return Color(red: 0.16, green: 0.40, blue: 0.78)
        }
    }

    /// Legible text colour over `tint`.
    public var textColor: Color {
        self == .yellow ? .black : .white
    }
}
