//
//  HighScores.swift
//  RollnWrite – Core
//
//  Per-game best scores, persisted on-device in UserDefaults. Game-agnostic:
//  callers identify a game by a stable display name (e.g. "Qwixx Big Points")
//  shared by both players of a two-player table, so a variant has one best.
//

import Foundation

public enum HighScores {
    private static let storeKey = "rollnwrite.highscores.v1"

    private static func load() -> [String: Int] {
        guard
            let data = UserDefaults.standard.data(forKey: storeKey),
            let map = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        return map
    }

    private static func save(_ map: [String: Int]) {
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    /// The best score recorded for `name`, or `nil` if none yet.
    public static func best(for name: String) -> Int? { load()[name] }

    /// Record a finished game's score. Returns `true` if it's a new best.
    @discardableResult
    public static func record(_ score: Int, for name: String) -> Bool {
        var map = load()
        if let previous = map[name], previous >= score { return false }
        map[name] = score
        save(map)
        return true
    }

    /// All recorded bests, sorted by game name — for a high-scores list.
    public static func all() -> [(name: String, best: Int)] {
        load().map { (name: $0.key, best: $0.value) }.sorted { $0.name < $1.name }
    }

    public static func reset() {
        UserDefaults.standard.removeObject(forKey: storeKey)
    }
}
