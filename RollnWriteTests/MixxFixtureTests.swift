//
//  MixxFixtureTests.swift
//  RollnWriteTests
//
//  Replays every golden fixture under spec/fixtures/qwixx-mixx against the
//  real QwixxMixx (`MixxGame`) engine, exactly as `QwixxMixxGame` constructs
//  it. Fixture format is normative in spec/fixtures/qwixx-mixx/README.md;
//  both this runner and the Android one (android/engine) must implement it
//  identically.
//
//  A failing assertion here means either the engine regressed or the fixture
//  is wrong — this file must never "fix" a mismatch by loosening the check.
//

import XCTest
@testable import RollnWrite

// MARK: - Fixture format (Codable mirror of spec/fixtures/qwixx-mixx/README.md)

private struct MixxFixture: Decodable {
    let game: String
    let variant: String
    let config: Config
    let name: String
    let description: String
    let steps: [MixxStep]

    struct Config: Decodable {
        let board: String
        let scoringCap: Int
    }
}

/// A step is either a "do" (mutation attempt) or an "assert" (state check).
/// Decoded manually since the two forms share no common shape.
///
/// "row" is the row INDEX (0...3) for `mark`/`concede`; "index" is the cell
/// position (0...10), only present for `mark`. Both fold into one case here
/// (mirroring how `QwixxFixtureTests` decodes color/row/index generically)
/// rather than a fragile side channel.
private enum MixxStep: Decodable {
    case doStep(action: String, row: Int?, index: Int?, expect: Bool)
    case assertStep(MixxAssertion)

    private enum CodingKeys: String, CodingKey {
        case `do`, row, index, expect, assert
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // A step must be exactly one of "do" / "assert" (spec/fixtures/qwixx-mixx/README.md);
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
            let row = try c.decodeIfPresent(Int.self, forKey: .row)
            let index = try c.decodeIfPresent(Int.self, forKey: .index)
            self = .doStep(action: action, row: row, index: index, expect: expect)
        } else {
            let assertion = try c.decode(MixxAssertion.self, forKey: .assert)
            self = .assertStep(assertion)
        }
    }
}

/// Every key is optional — assert any subset, per spec/fixtures/qwixx-mixx/README.md.
/// Row keys are the Mixx row index (0...3) rendered as strings (JSON object keys).
private struct MixxAssertion: Decodable {
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

private struct MixxStateSnapshot: Equatable {
    let crosses: [Int: Int]
    let points: [Int: Int]
    let penalties: Int
    let totalScore: Int
    let isGameOver: Bool
    let lockedRowCount: Int
    let rowLocked: [Int: Bool]
    let canUndo: Bool
    let canRedo: Bool

    @MainActor
    init(_ game: MixxGame) {
        let indices = Array(0..<4)
        crosses = Dictionary(uniqueKeysWithValues: indices.map { ($0, game.crosses($0)) })
        points = Dictionary(uniqueKeysWithValues: indices.map { ($0, game.points($0)) })
        penalties = game.penalties
        totalScore = game.totalScore
        isGameOver = game.isGameOver
        lockedRowCount = game.lockedRowCount
        rowLocked = Dictionary(uniqueKeysWithValues: indices.map { ($0, game.rowState($0).locked) })
        canUndo = game.canUndo
        canRedo = game.canRedo
    }
}

// MARK: - Runner

@MainActor
final class MixxFixtureTests: XCTestCase {

    /// `RollnWriteTests/` sits next to `spec/` at the repo root, so walk up
    /// from this source file's own path rather than depending on the working
    /// directory `xcodebuild test` happens to use.
    private static var fixturesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // MixxFixtureTests.swift
            .deletingLastPathComponent() // RollnWriteTests/
            .appendingPathComponent("spec/fixtures/qwixx-mixx")
    }

    private static func allFixtureFiles() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: fixturesRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return enumerator.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "json" }
            .sorted { $0.path < $1.path }
    }

    func testAllGoldenFixtures() throws {
        let files = Self.allFixtureFiles()
        guard !files.isEmpty else {
            XCTFail("No qwixx-mixx fixture *.json files found under \(Self.fixturesRoot.path)")
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
        let fixture: MixxFixture
        do {
            fixture = try JSONDecoder().decode(MixxFixture.self, from: data)
        } catch {
            XCTFail("\(label): failed to decode fixture — \(error)")
            return
        }

        XCTAssertEqual(fixture.game, "qwixx-mixx", "\(label): unexpected 'game' \(fixture.game)")
        XCTAssertEqual(
            fixture.name,
            url.deletingPathExtension().lastPathComponent,
            "\(label): fixture 'name' must match the filename (spec/fixtures/qwixx-mixx/README.md)"
        )
        XCTAssertEqual(fixture.variant, fixture.config.board, "\(label): 'variant' must equal 'config.board'")
        guard let board = MixxBoard(rawValue: fixture.config.board) else {
            XCTFail("\(label): unknown config.board '\(fixture.config.board)'")
            return
        }

        // The engine's save() writes both boards' keys to UserDefaults on
        // every mutation; remove them afterwards so test runs don't
        // accumulate orphaned keys. A unique prefix per fixture also gives
        // full isolation between fixture runs.
        let persistencePrefix = "test.fixtures.mixx.\(UUID().uuidString)"
        addTeardownBlock {
            UserDefaults.standard.removeObject(forKey: "\(persistencePrefix).\(MixxBoard.variantA.rawValue).state")
            UserDefaults.standard.removeObject(forKey: "\(persistencePrefix).\(MixxBoard.variantB.rawValue).state")
            UserDefaults.standard.removeObject(forKey: "\(persistencePrefix).board")
        }

        // Constructed exactly as `QwixxMixxScorecardView` constructs it
        // (`MixxGame()`, all defaults) except for the scoring cap (taken
        // from the fixture, always 12 for Mixx) and an isolated persistence
        // prefix; `board` is then switched to the fixture's board, just as
        // the in-card A/B picker does.
        let game = MixxGame(
            scoring: TriangularScoring(cap: fixture.config.scoringCap),
            persistencePrefix: persistencePrefix
        )
        game.board = board

        for (index, step) in fixture.steps.enumerated() {
            switch step {
            case let .doStep(action, row, cellIndex, expect):
                runDoStep(
                    game: game,
                    file: label,
                    stepIndex: index,
                    action: action,
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
        game: MixxGame,
        file: String,
        stepIndex: Int,
        action: String,
        row: Int?,
        cellIndex: Int?,
        expect: Bool
    ) {
        let context = "\(file): step[\(stepIndex)] do:\(action)"

        switch action {
        case "mark":
            guard let rowIndex = row, let idx = cellIndex else {
                XCTFail("\(context): missing/invalid row or index")
                return
            }
            let canDo = game.canMark(rowIndex, idx)
            XCTAssertEqual(canDo, expect, "\(context): canMark(\(rowIndex), \(idx)) was \(canDo), expected \(expect)")
            let before = MixxStateSnapshot(game)
            game.mark(rowIndex, idx)
            if !expect {
                assertUnchanged(before, game: game, context: context)
            }

        case "penalty":
            let canDo = game.canAddPenalty()
            XCTAssertEqual(canDo, expect, "\(context): canAddPenalty() was \(canDo), expected \(expect)")
            let before = MixxStateSnapshot(game)
            game.addPenalty()
            if !expect {
                assertUnchanged(before, game: game, context: context)
            }

        case "concede":
            guard let rowIndex = row else {
                XCTFail("\(context): missing/invalid row")
                return
            }
            let canDo = game.canConcedeRow(rowIndex)
            XCTAssertEqual(canDo, expect, "\(context): canConcedeRow(\(rowIndex)) was \(canDo), expected \(expect)")
            let before = MixxStateSnapshot(game)
            game.concedeRow(rowIndex)
            if !expect {
                assertUnchanged(before, game: game, context: context)
            }

        case "finish":
            let canDo = game.canFinishManually
            XCTAssertEqual(canDo, expect, "\(context): canFinishManually was \(canDo), expected \(expect)")
            let before = MixxStateSnapshot(game)
            game.finishGame()
            if !expect {
                assertUnchanged(before, game: game, context: context)
            }

        case "undo":
            let canDo = game.canUndo
            XCTAssertEqual(canDo, expect, "\(context): canUndo was \(canDo), expected \(expect)")
            let before = MixxStateSnapshot(game)
            game.undo()
            if !expect {
                assertUnchanged(before, game: game, context: context)
            }

        case "redo":
            let canDo = game.canRedo
            XCTAssertEqual(canDo, expect, "\(context): canRedo was \(canDo), expected \(expect)")
            let before = MixxStateSnapshot(game)
            game.redo()
            if !expect {
                assertUnchanged(before, game: game, context: context)
            }

        default:
            XCTFail("\(context): unknown 'do' action '\(action)'")
        }
    }

    private func assertUnchanged(_ before: MixxStateSnapshot, game: MixxGame, context: String) {
        let after = MixxStateSnapshot(game)
        XCTAssertEqual(before, after, "\(context): expected no-op (expect=false) but observable state changed")
    }

    // MARK: - "assert" step

    private func runAssertStep(game: MixxGame, file: String, stepIndex: Int, assertion: MixxAssertion) {
        let context = "\(file): step[\(stepIndex)] assert"

        if let expectedPoints = assertion.points {
            for (rowKey, expected) in expectedPoints {
                guard let rowIndex = Int(rowKey) else {
                    XCTFail("\(context).points: non-integer row key '\(rowKey)'")
                    continue
                }
                let actual = game.points(rowIndex)
                XCTAssertEqual(actual, expected, "\(context).points.\(rowKey): expected \(expected), got \(actual)")
            }
        }

        if let expectedCrosses = assertion.crosses {
            for (rowKey, expected) in expectedCrosses {
                guard let rowIndex = Int(rowKey) else {
                    XCTFail("\(context).crosses: non-integer row key '\(rowKey)'")
                    continue
                }
                let actual = game.crosses(rowIndex)
                XCTAssertEqual(actual, expected, "\(context).crosses.\(rowKey): expected \(expected), got \(actual)")
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
            for (rowKey, expected) in expectedLocked {
                guard let rowIndex = Int(rowKey) else {
                    XCTFail("\(context).rowLocked: non-integer row key '\(rowKey)'")
                    continue
                }
                let actual = game.rowState(rowIndex).locked
                XCTAssertEqual(actual, expected, "\(context).rowLocked.\(rowKey): expected \(expected), got \(actual)")
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
