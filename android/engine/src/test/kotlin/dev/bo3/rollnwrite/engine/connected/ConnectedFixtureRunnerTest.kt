package dev.bo3.rollnwrite.engine.connected

import dev.bo3.rollnwrite.engine.TriangularScoring
import dev.bo3.rollnwrite.engine.qwixx.GameColor
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
 * Replays every golden fixture under `spec/fixtures/qwixx-connected/` against
 * a real [ConnectedGame], per the runner semantics documented (normatively)
 * in `spec/fixtures/qwixx-connected/README.md` (which extends the base
 * `spec/README.md`). This is the parity contract with the Swift
 * `ConnectedGame` engine: a rule divergence here fails this platform's build.
 *
 * Mirrors `BonusFixtureRunnerTest.kt`'s shape. Connected introduces NO new
 * "do" verb or "assert" key over the base Qwixx vocabulary — a chain co-mark
 * is just another entry in `crosses`/`points`/`rowLocked`, so this runner is
 * (deliberately) the plainest of the variant runners.
 */
class ConnectedFixtureRunnerTest {

    private val json = Json { ignoreUnknownKeys = true }

    private val colorKeys = mapOf(
        "red" to GameColor.RED,
        "yellow" to GameColor.YELLOW,
        "green" to GameColor.GREEN,
        "blue" to GameColor.BLUE,
    )

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
    fun `qwixx connected fixtures replay against the engine`(): List<DynamicTest> {
        val dir = fixturesDir()
        val files = fixtureFiles(dir)
        return files
            .filter { it.readText().let { text -> """"variant"\s*:\s*"connected"""".toRegex().containsMatchIn(text) } }
            .map { file ->
                DynamicTest.dynamicTest(file.relativeTo(dir).path) {
                    replayFixture(file)
                }
            }
    }

    private fun replayFixture(file: File) {
        val label = file.path
        val root = json.parseToJsonElement(file.readText()).jsonObject

        assertEquals("qwixx", root["game"]?.jsonPrimitive?.contentOrNull, "$label: unexpected 'game'")
        assertEquals(
            file.nameWithoutExtension,
            root["name"]?.jsonPrimitive?.contentOrNull,
            "$label: fixture 'name' must match the filename (spec/fixtures/qwixx-connected/README.md)",
        )

        val config = root["config"]?.jsonObject ?: fail<Nothing>("$label: missing 'config' object")
        val scoringCap = config["scoringCap"]?.jsonPrimitive?.intOrNull
            ?: fail<Nothing>("$label: missing config.scoringCap")

        val steps = (root["steps"] as? JsonArray) ?: fail<Nothing>("$label: missing 'steps' array")

        val game = ConnectedGame(scoring = TriangularScoring(cap = scoringCap))

        steps.forEachIndexed { index, stepElement ->
            val step = stepElement.jsonObject
            val stepLabel = "$label: step[$index] ${step}"
            when {
                "do" in step -> applyDoStep(game, step, stepLabel)
                "assert" in step -> applyAssertStep(game, step["assert"]!!.jsonObject, stepLabel)
                else -> fail<Unit>("$stepLabel: must contain exactly one of 'do' or 'assert'")
            }
        }
    }

    private fun applyDoStep(game: ConnectedGame, step: JsonObject, stepLabel: String) {
        val action = step["do"]!!.jsonPrimitive.contentOrNull
            ?: fail<Nothing>("$stepLabel: 'do' must be a string")
        val expect = step["expect"]?.jsonPrimitive?.booleanOrNull
            ?: fail<Nothing>("$stepLabel: missing required 'expect' boolean")

        // Snapshot so a refused ("expect": false) mutation can be verified
        // as a genuine no-op, per spec/README.md runner semantics.
        val before = game.state

        when (action) {
            "markColor" -> {
                val color = colorOf(step, stepLabel)
                val idx = indexOf(step, stepLabel)
                assertEquals(expect, game.canMarkColor(color, idx), "$stepLabel: canMarkColor mismatch")
                game.markColor(color, idx)
            }
            "penalty" -> {
                assertEquals(expect, game.canAddPenalty(), "$stepLabel: canAddPenalty mismatch")
                game.addPenalty()
            }
            "concede" -> {
                val color = colorOf(step, stepLabel)
                assertEquals(expect, game.canConcedeRow(color), "$stepLabel: canConcedeRow mismatch")
                game.concedeRow(color)
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

    private fun applyAssertStep(game: ConnectedGame, assertion: JsonObject, stepLabel: String) {
        assertion["points"]?.jsonObject?.forEach { (key, value) ->
            val color = colorKeys[key] ?: fail<Nothing>("$stepLabel.points: unknown color '$key'")
            val expected = value.jsonPrimitive.intOrNull ?: fail("$stepLabel.points.$key must be an int")
            assertEquals(expected, game.points(color), "$stepLabel: points[$key] mismatch")
        }
        assertion["crosses"]?.jsonObject?.forEach { (key, value) ->
            val color = colorKeys[key] ?: fail<Nothing>("$stepLabel.crosses: unknown color '$key'")
            val expected = value.jsonPrimitive.intOrNull ?: fail("$stepLabel.crosses.$key must be an int")
            assertEquals(expected, game.crosses(color), "$stepLabel: crosses[$key] mismatch")
        }
        assertion["rowLocked"]?.jsonObject?.forEach { (key, value) ->
            val color = colorKeys[key] ?: fail<Nothing>("$stepLabel.rowLocked: unknown color '$key'")
            val expected = value.jsonPrimitive.booleanOrNull ?: fail("$stepLabel.rowLocked.$key must be a bool")
            assertEquals(expected, game.row(color).locked, "$stepLabel: rowLocked[$key] mismatch")
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

    private fun colorOf(step: JsonObject, stepLabel: String): GameColor {
        val key = step["color"]?.jsonPrimitive?.contentOrNull
            ?: fail<Nothing>("$stepLabel: missing 'color'")
        return colorKeys[key] ?: fail("$stepLabel: unknown color '$key'")
    }

    private fun indexOf(step: JsonObject, stepLabel: String): Int =
        step["index"]?.jsonPrimitive?.intOrNull ?: fail("$stepLabel: missing 'index'")
}
