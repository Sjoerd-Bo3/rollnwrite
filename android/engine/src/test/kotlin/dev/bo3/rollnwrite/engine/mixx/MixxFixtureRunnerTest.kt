package dev.bo3.rollnwrite.engine.mixx

import dev.bo3.rollnwrite.engine.TriangularScoring
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Assertions.fail
import org.junit.jupiter.api.DynamicTest
import org.junit.jupiter.api.TestFactory
import java.io.File

/**
 * Replays every golden fixture under `spec/fixtures/qwixx-mixx` against a
 * real [MixxGame], per the runner semantics documented (normatively) in
 * `spec/fixtures/qwixx-mixx/README.md`. This is the parity contract with the
 * Swift engine (`MixxFixtureTests.swift`): a rule divergence here fails this
 * platform's build.
 *
 * Mirrors `QwixxFixtureRunnerTest` name-for-name, adapted to Mixx's
 * row-by-index (not by-colour) vocabulary and lack of bonus rows.
 */
class MixxFixtureRunnerTest {

    private val json = Json { ignoreUnknownKeys = true }

    private fun fixturesDir(): File {
        val path = System.getProperty("fixtures.dir")
            ?: fail("fixtures.dir system property is not set — check engine/build.gradle.kts")
        val dir = File(path)
        assertTrue(dir.isDirectory) {
            "fixtures.dir '$path' does not exist or is not a directory"
        }
        return dir
    }

    private fun fixtureFiles(dir: File): List<File> {
        val files = dir.walkTopDown().filter { it.isFile && it.extension == "json" }.toList()
        assertTrue(files.isNotEmpty()) {
            "fixtures.dir '${dir.absolutePath}' contains no *.json fixtures"
        }
        return files.sortedBy { it.path }
    }

    @TestFactory
    fun `qwixx-mixx fixtures replay against the engine`(): List<DynamicTest> {
        val dir = fixturesDir()
        val files = fixtureFiles(dir)
        val mixxFixtures = files.filter {
            it.readText().let { text -> """"game"\s*:\s*"qwixx-mixx"""".toRegex().containsMatchIn(text) }
        }
        // FAIL if no fixtures are found for this game, per the task contract —
        // an empty directory must not silently pass as "0 dynamic tests, all green".
        assertTrue(mixxFixtures.isNotEmpty()) {
            "no qwixx-mixx fixtures found under '${dir.absolutePath}'"
        }
        return mixxFixtures.map { file ->
            DynamicTest.dynamicTest(file.relativeTo(dir).path) {
                replayFixture(file)
            }
        }
    }

    private fun replayFixture(file: File) {
        val label = file.path
        val root = json.parseToJsonElement(file.readText()).jsonObject

        val name = root["name"]?.jsonPrimitive?.contentOrNull ?: fail<Nothing>("$label: missing 'name'")
        assertEquals(
            file.nameWithoutExtension,
            name,
            "$label: fixture 'name' must match the filename (spec/fixtures/qwixx-mixx/README.md)",
        )

        val variant = root["variant"]?.jsonPrimitive?.contentOrNull ?: fail<Nothing>("$label: missing 'variant'")
        val config = root["config"]?.jsonObject ?: fail<Nothing>("$label: missing 'config' object")
        val boardName = config["board"]?.jsonPrimitive?.contentOrNull
            ?: fail<Nothing>("$label: missing config.board")
        assertEquals(variant, boardName, "$label: 'variant' must equal 'config.board'")
        val scoringCap = config["scoringCap"]?.jsonPrimitive?.intOrNull
            ?: fail<Nothing>("$label: missing config.scoringCap")

        val board = boardOf(boardName, label)
        val steps = (root["steps"] as? JsonArray) ?: fail<Nothing>("$label: missing 'steps' array")

        val game = MixxGame(board = board, scoring = TriangularScoring(cap = scoringCap))

        steps.forEachIndexed { index, stepElement ->
            val step = stepElement.jsonObject
            val stepLabel = "$label: step[$index] $step"
            when {
                "do" in step -> applyDoStep(game, step, stepLabel)
                "assert" in step -> applyAssertStep(game, step["assert"]!!.jsonObject, stepLabel)
                else -> fail<Unit>("$stepLabel: must contain exactly one of 'do' or 'assert'")
            }
        }
    }

    private fun applyDoStep(game: MixxGame, step: JsonObject, stepLabel: String) {
        val action = step["do"]!!.jsonPrimitive.contentOrNull
            ?: fail<Nothing>("$stepLabel: 'do' must be a string")
        val expect = step["expect"]?.jsonPrimitive?.booleanOrNull
            ?: fail<Nothing>("$stepLabel: missing required 'expect' boolean")

        // Snapshot so a refused ("expect": false) mutation can be verified
        // as a genuine no-op, per the runner semantics.
        val before = game.state

        when (action) {
            "mark" -> {
                val row = rowOf(step, stepLabel)
                val idx = indexOf(step, stepLabel)
                assertEquals(expect, game.canMark(row, idx), "$stepLabel: canMark mismatch")
                game.mark(row, idx)
            }
            "penalty" -> {
                assertEquals(expect, game.canAddPenalty(), "$stepLabel: canAddPenalty mismatch")
                game.addPenalty()
            }
            "concede" -> {
                val row = rowOf(step, stepLabel)
                assertEquals(expect, game.canConcedeRow(row), "$stepLabel: canConcedeRow mismatch")
                game.concedeRow(row)
            }
            "finish" -> {
                assertEquals(expect, game.canFinishManually(), "$stepLabel: canFinishManually mismatch")
                game.finishGame()
            }
            "undo" -> {
                assertEquals(expect, game.canUndo, "$stepLabel: canUndo mismatch")
                game.undo()
            }
            "redo" -> {
                assertEquals(expect, game.canRedo, "$stepLabel: canRedo mismatch")
                game.redo()
            }
            else -> fail<Unit>("$stepLabel: unknown 'do' action '$action'")
        }

        if (!expect) {
            assertEquals(before, game.state, "$stepLabel: refused action must leave state unchanged")
        }
    }

    private fun applyAssertStep(game: MixxGame, assertion: JsonObject, stepLabel: String) {
        assertion["points"]?.jsonObject?.forEach { (key, value) ->
            val row = rowIndexKey(key, stepLabel, "points")
            val expected = value.jsonPrimitive.intOrNull ?: fail("$stepLabel.points.$key must be an int")
            assertEquals(expected, game.points(row), "$stepLabel: points[$key] mismatch")
        }
        assertion["crosses"]?.jsonObject?.forEach { (key, value) ->
            val row = rowIndexKey(key, stepLabel, "crosses")
            val expected = value.jsonPrimitive.intOrNull ?: fail("$stepLabel.crosses.$key must be an int")
            assertEquals(expected, game.crosses(row), "$stepLabel: crosses[$key] mismatch")
        }
        assertion["rowLocked"]?.jsonObject?.forEach { (key, value) ->
            val row = rowIndexKey(key, stepLabel, "rowLocked")
            val expected = value.jsonPrimitive.booleanOrNull ?: fail("$stepLabel.rowLocked.$key must be a bool")
            assertEquals(expected, game.rowState(row).locked, "$stepLabel: rowLocked[$key] mismatch")
        }
        assertion["penalties"]?.let {
            assertEquals(it.jsonPrimitive.intOrNull, game.penalties, "$stepLabel: penalties mismatch")
        }
        assertion["penaltyPoints"]?.let {
            assertEquals(it.jsonPrimitive.intOrNull, game.penaltyPoints, "$stepLabel: penaltyPoints mismatch")
        }
        assertion["totalScore"]?.let {
            assertEquals(it.jsonPrimitive.intOrNull, game.totalScore, "$stepLabel: totalScore mismatch")
        }
        assertion["isGameOver"]?.let {
            assertEquals(it.jsonPrimitive.booleanOrNull, game.isGameOver, "$stepLabel: isGameOver mismatch")
        }
        assertion["lockedRowCount"]?.let {
            assertEquals(it.jsonPrimitive.intOrNull, game.lockedRowCount, "$stepLabel: lockedRowCount mismatch")
        }
        assertion["canUndo"]?.let {
            assertEquals(it.jsonPrimitive.booleanOrNull, game.canUndo, "$stepLabel: canUndo mismatch")
        }
        assertion["canRedo"]?.let {
            assertEquals(it.jsonPrimitive.booleanOrNull, game.canRedo, "$stepLabel: canRedo mismatch")
        }
    }

    private fun boardOf(name: String, label: String): MixxBoard = when (name) {
        "variantA" -> MixxBoard.VARIANT_A
        "variantB" -> MixxBoard.VARIANT_B
        else -> fail("$label: unknown board '$name'")
    }

    private fun rowOf(step: JsonObject, stepLabel: String): Int =
        step["row"]?.jsonPrimitive?.intOrNull ?: fail("$stepLabel: missing 'row'")

    private fun rowIndexKey(key: String, stepLabel: String, assertKey: String): Int =
        key.toIntOrNull() ?: fail("$stepLabel.$assertKey: row key '$key' is not an integer")

    private fun indexOf(step: JsonObject, stepLabel: String): Int =
        step["index"]?.jsonPrimitive?.intOrNull ?: fail("$stepLabel: missing 'index'")
}
