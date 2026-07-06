//
//  QwixxFixtureTests.swift
//  RollnWriteTests
//
//  Replays every golden fixture under spec/fixtures/qwixx-* against the real
//  QwixxGame engine. Fixture format is normative in spec/README.md; both this
//  runner and the Android one (android/engine) must implement it identically.
//
//  A failing assertion here means either the engine regressed or the fixture
//  is wrong — this file must never "fix" a mismatch by loosening the check.
//

import XCTest
@testable import RollnWrite

// MARK: - Fixture format (Codable mirror of spec/README.md)

private struct Fixture: Decodable {
    let game: String
    let variant: String
    let config: Config
    let name: String
    let description: String
    let steps: [Step]

    struct Config: Decodable {
        let scoringCap: Int
        let hasBonusRows: Bool
    }
}

/// A step is either a "do" (mutation attempt) or an "assert" (state check).
/// Decoded manually since the two forms share no common shape.
private enum Step: Decodable {
    case doStep(action: String, color: String?, row: String?, index: Int?, expect: Bool)
    case assertStep(Assertion)

    private enum CodingKeys: String, CodingKey {
        case `do`, color, row, index, expect, assert
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // A step must be exactly one of "do" / "assert" (spec/README.md);
        // reject malformed steps carrying both rather than silently picking one.
        if c.contains(.do) && c.contains(.assert) {
            throw DecodingError.dataCorruptedError(
                forKey: .do,
                in: c,
                debugDescription: "step contains both 'do' and 'assert' keys"
            )
        }
        if let action = try c.decodeIfPresent(String.self, forKey: .do) {
            let expect = try c.decode(Bool.self, forKey: .expect)
            let color = try c.decodeIfPresent(String.self, forKey: .color)
            let row = try c.decodeIfPresent(String.self, forKey: .row)
            let index = try c.decodeIfPresent(Int.self, forKey: .index)
            self = .doStep(action: action, color: color, row: row, index: index, expect: expect)
        } else {
            let assertion = try c.decode(Assertion.self, forKey: .assert)
            self = .assertStep(assertion)
        }
    }
}

/// Every key is optional — assert any subset, per spec/README.md.
private struct Assertion: Decodable {
    let points: [String: Int]?
    let crosses: [String: Int]?
    let penalties: Int?
    let penaltyPoints: Int?
    let totalScore: Int?
    let isGameOver: Bool?
    let lockedRowCount: Int?
    let rowLocked: [String: Bool]?
    let canUndo: Bool?
    let canRedo: Bool?
}

// MARK: - Snapshot of every observable, for the "state unchanged on refusal" check

private struct StateSnapshot: Equatable {
    let crosses: [String: Int]
    let points: [String: Int]
    let penalties: Int
    let totalScore: Int
    let isGameOver: Bool
    let lockedRowCount: Int
    let rowLocked: [String: Bool]
    let canUndo: Bool
    let canRedo: Bool
    let bonusMarks: [String: Set<Int>]

    @MainActor
    init(_ game: QwixxGame) {
        crosses = Dictionary(uniqueKeysWithValues: GameColor.allCases.map { ($0.rawValue, game.crosses(for: $0)) })
        points = Dictionary(uniqueKeysWithValues: GameColor.allCases.map { ($0.rawValue, game.points(for: $0)) })
        penalties = game.penalties
        totalScore = game.totalScore
        isGameOver = game.isGameOver
        lockedRowCount = game.lockedRowCount
        rowLocked = Dictionary(uniqueKeysWithValues: GameColor.allCases.map { ($0.rawValue, game.row(for: $0).locked) })
        canUndo = game.canUndo
        canRedo = game.canRedo
        bonusMarks = Dictionary(uniqueKeysWithValues: BonusRowID.allCases.map { ($0.rawValue, game.bonus($0).marks) })
    }
}

// MARK: - Runner

@MainActor
final class QwixxFixtureTests: XCTestCase {

    /// `RollnWriteTests/` sits next to `spec/` at the repo root, so walk up
    /// from this source file's own path rather than depending on the working
    /// directory `xcodebuild test` happens to use.
    private static var fixturesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // QwixxFixtureTests.swift
            .deletingLastPathComponent() // RollnWriteTests/
            .appendingPathComponent("spec/fixtures")
    }

    /// Only the BASE Qwixx directories: each Qwixx variant defines its own
    /// action vocabulary with its own runner file — this runner must not
    /// try to replay those.
    private static let baseQwixxDirs = ["qwixx-big-points", "qwixx-classic"]

    private static func allFixtureFiles() -> [URL] {
        baseQwixxDirs.flatMap { sub -> [URL] in
            let dir = fixturesRoot.appendingPathComponent(sub)
            guard let enumerator = FileManager.default.enumerator(
                at: dir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }
            return enumerator.compactMap { $0 as? URL }
                .filter { $0.pathExtension == "json" }
        }
        .sorted { $0.path < $1.path }
    }

    func testAllGoldenFixtures() throws {
        let files = Self.allFixtureFiles()
        guard !files.isEmpty else {
            XCTFail("No fixture *.json files found under \(Self.fixturesRoot.path)")
            return
        }

        for file in files {
            try runFixture(at: file)
        }
    }

    // MARK: - Per-fixture replay

    private func runFixture(at url: URL) throws {
        let label = url.path
        let data = try Data(contentsOf: url)
        let fixture: Fixture
        do {
            fixture = try JSONDecoder().decode(Fixture.self, from: data)
        } catch {
            XCTFail("\(label): failed to decode fixture — \(error)")
            return
        }

        XCTAssertEqual(fixture.game, "qwixx", "\(label): unexpected 'game' \(fixture.game)")
        XCTAssertEqual(
            fixture.name,
            url.deletingPathExtension().lastPathComponent,
            "\(label): fixture 'name' must match the filename (spec/README.md)"
        )

        // The engine's save() writes this key to UserDefaults on every mutation;
        // remove it afterwards so test runs don't accumulate orphaned keys.
        let persistenceKey = "test.fixtures.\(UUID().uuidString)"
        addTeardownBlock {
            UserDefaults.standard.removeObject(forKey: persistenceKey)
        }

        let game = QwixxGame(
            scoring: TriangularScoring(cap: fixture.config.scoringCap),
            persistenceKey: persistenceKey,
            hasBonusRows: fixture.config.hasBonusRows
        )

        for (index, step) in fixture.steps.enumerated() {
            switch step {
            case let .doStep(action, color, row, cellIndex, expect):
                runDoStep(
                    game: game,
                    file: label,
                    stepIndex: index,
                    action: action,
                    color: color,
                    row: row,
                    cellIndex: cellIndex,
                    expect: expect
                )
            case let .assertStep(assertion):
                runAssertStep(game: game, file: label, stepIndex: index, assertion: assertion)
            }
        }
    }

    // MARK: - "do" step

    private func runDoStep(
        game: QwixxGame,
        file: String,
        stepIndex: Int,
        action: String,
        color: String?,
        row: String?,
        cellIndex: Int?,
        expect: Bool
    ) {
        let context = "\(file): step[\(stepIndex)] do:\(action)"

        switch action {
        case "markColor":
            guard let colorName = color, let gameColor = GameColor(rawValue: colorName), let idx = cellIndex else {
                XCTFail("\(context): missing/invalid color or index")
                return
            }
            let canDo = game.canMarkColor(gameColor, idx)
            XCTAssertEqual(canDo, expect, "\(context): canMarkColor(\(colorName), \(idx)) was \(canDo), expected \(expect)")
            let before = StateSnapshot(game)
            game.markColor(gameColor, idx)
            if !expect {
                assertUnchanged(before, game: game, context: context)
            }

        case "markBonus":
            guard let rowName = row, let bonusID = BonusRowID(rawValue: rowName), let idx = cellIndex else {
                XCTFail("\(context): missing/invalid row or index")
                return
            }
            let canDo = game.canMarkBonus(bonusID, idx)
            XCTAssertEqual(canDo, expect, "\(context): canMarkBonus(\(rowName), \(idx)) was \(canDo), expected \(expect)")
            let before = StateSnapshot(game)
            game.markBonus(bonusID, idx)
            if !expect {
                assertUnchanged(before, game: game, context: context)
            }

        case "penalty":
            let canDo = game.canAddPenalty()
            XCTAssertEqual(canDo, expect, "\(context): canAddPenalty() was \(canDo), expected \(expect)")
            let before = StateSnapshot(game)
            game.addPenalty()
            if !expect {
                assertUnchanged(before, game: game, context: context)
            }

        case "concede":
            guard let colorName = color, let gameColor = GameColor(rawValue: colorName) else {
                XCTFail("\(context): missing/invalid color")
                return
            }
            let canDo = game.canConcedeRow(gameColor)
            XCTAssertEqual(canDo, expect, "\(context): canConcedeRow(\(colorName)) was \(canDo), expected \(expect)")
            let before = StateSnapshot(game)
            game.concedeRow(gameColor)
            if !expect {
                assertUnchanged(before, game: game, context: context)
            }

        case "finish":
            let canDo = game.canFinishManually
            XCTAssertEqual(canDo, expect, "\(context): canFinishManually was \(canDo), expected \(expect)")
            let before = StateSnapshot(game)
            game.finishGame()
            if !expect {
                assertUnchanged(before, game: game, context: context)
            }

        case "undo":
            let canDo = game.canUndo
            XCTAssertEqual(canDo, expect, "\(context): canUndo was \(canDo), expected \(expect)")
            let before = StateSnapshot(game)
            game.undo()
            if !expect {
                assertUnchanged(before, game: game, context: context)
            }

        case "redo":
            let canDo = game.canRedo
            XCTAssertEqual(canDo, expect, "\(context): canRedo was \(canDo), expected \(expect)")
            let before = StateSnapshot(game)
            game.redo()
            if !expect {
                assertUnchanged(before, game: game, context: context)
            }

        default:
            XCTFail("\(context): unknown 'do' action '\(action)'")
        }
    }

    private func assertUnchanged(_ before: StateSnapshot, game: QwixxGame, context: String) {
        let after = StateSnapshot(game)
        XCTAssertEqual(before, after, "\(context): expected no-op (expect=false) but observable state changed")
    }

    // MARK: - "assert" step

    private func runAssertStep(game: QwixxGame, file: String, stepIndex: Int, assertion: Assertion) {
        let context = "\(file): step[\(stepIndex)] assert"

        if let expectedPoints = assertion.points {
            for (colorName, expected) in expectedPoints {
                guard let color = GameColor(rawValue: colorName) else {
                    XCTFail("\(context).points: unknown color '\(colorName)'")
                    continue
                }
                let actual = game.points(for: color)
                XCTAssertEqual(actual, expected, "\(context).points.\(colorName): expected \(expected), got \(actual)")
            }
        }

        if let expectedCrosses = assertion.crosses {
            for (colorName, expected) in expectedCrosses {
                guard let color = GameColor(rawValue: colorName) else {
                    XCTFail("\(context).crosses: unknown color '\(colorName)'")
                    continue
                }
                let actual = game.crosses(for: color)
                XCTAssertEqual(actual, expected, "\(context).crosses.\(colorName): expected \(expected), got \(actual)")
            }
        }

        if let expected = assertion.penalties {
            let actual = game.penalties
            XCTAssertEqual(actual, expected, "\(context).penalties: expected \(expected), got \(actual)")
        }

        if let expected = assertion.penaltyPoints {
            let actual = game.penaltyPoints
            XCTAssertEqual(actual, expected, "\(context).penaltyPoints: expected \(expected), got \(actual)")
        }

        if let expected = assertion.totalScore {
            let actual = game.totalScore
            XCTAssertEqual(actual, expected, "\(context).totalScore: expected \(expected), got \(actual)")
        }

        if let expected = assertion.isGameOver {
            let actual = game.isGameOver
            XCTAssertEqual(actual, expected, "\(context).isGameOver: expected \(expected), got \(actual)")
        }

        if let expected = assertion.lockedRowCount {
            let actual = game.lockedRowCount
            XCTAssertEqual(actual, expected, "\(context).lockedRowCount: expected \(expected), got \(actual)")
        }

        if let expectedLocked = assertion.rowLocked {
            for (colorName, expected) in expectedLocked {
                guard let color = GameColor(rawValue: colorName) else {
                    XCTFail("\(context).rowLocked: unknown color '\(colorName)'")
                    continue
                }
                let actual = game.row(for: color).locked
                XCTAssertEqual(actual, expected, "\(context).rowLocked.\(colorName): expected \(expected), got \(actual)")
            }
        }

        if let expected = assertion.canUndo {
            let actual = game.canUndo
            XCTAssertEqual(actual, expected, "\(context).canUndo: expected \(expected), got \(actual)")
        }

        if let expected = assertion.canRedo {
            let actual = game.canRedo
            XCTAssertEqual(actual, expected, "\(context).canRedo: expected \(expected), got \(actual)")
        }
    }
}
