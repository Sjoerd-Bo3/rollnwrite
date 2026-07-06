package dev.bo3.rollnwrite.engine

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Assertions.fail
import org.junit.jupiter.api.DynamicTest
import org.junit.jupiter.api.TestFactory
import java.io.File

/**
 * Validates every golden fixture under `spec/fixtures` against the format
 * documented below. This is the normative description of that format —
 * both the Android and iOS test runners must implement these semantics
 * identically, since the fixtures are the single source of truth for
 * engine behaviour shared across platforms.
 *
 * ## Golden fixture format
 *
 * One JSON object per file:
 * ```json
 * {
 *   "game": "qwixx",
 *   "variant": "big-points",
 *   "config": { "scoringCap": 15, "hasBonusRows": true },
 *   "name": "kebab-slug",
 *   "description": "what this case proves",
 *   "steps": [ ... ]
 * }
 * ```
 * `variant` is `"big-points"` (config: cap 15, bonus rows true) or
 * `"classic"` (config: cap 12, bonus rows false) — `config` MUST agree with
 * `variant`.
 *
 * A step is EITHER a "do" or an "assert":
 * ```json
 * {"do":"markColor","color":"red|yellow|green|blue","index":0-10,"expect":true|false}
 * {"do":"markBonus","row":"redYellow|greenBlue","index":0-10,"expect":true|false}
 * {"do":"penalty","expect":true|false}
 * {"do":"concede","color":"red|yellow|green|blue","expect":true|false}
 * {"do":"finish","expect":true|false}
 * {"do":"undo","expect":true|false}   // expect == canUndo before applying
 * {"do":"redo","expect":true|false}   // expect == canRedo before applying
 * {"assert": { ...any subset of...
 *    "points":{"red":int,...}, "crosses":{"red":int,...}, "penalties":int,
 *    "penaltyPoints":int, "totalScore":int, "isGameOver":bool,
 *    "lockedRowCount":int, "rowLocked":{"red":bool,...},
 *    "canUndo":bool, "canRedo":bool }}
 * ```
 *
 * `"qwixx-double"` fixtures (`spec/fixtures/qwixx-double/README.md`) follow
 * the same envelope with `variant: "double-a"`, `config: {"scoringCap":16}`
 * (no `hasBonusRows` — Qwixx Double has no bonus rows), and swap `markBonus`
 * for `doubleColor` (same `color`/`index`/`expect` shape).
 *
 * ## Runner semantics (normative, both platforms)
 *
 * For a "do" step: first assert the engine's can-precondition equals
 * `expect`; then invoke the mutator. When `expect` is false the mutator
 * must leave state unchanged. For an "assert" step: compare each present
 * key against observable engine state.
 *
 * This test only validates fixture *shape* (it does not run an engine —
 * :engine has no Qwixx engine yet). It fails loudly, naming the file and
 * step index, so malformed fixtures are caught before any engine consumes
 * them.
 */
class FixtureFormatTest {

    private val json = Json { ignoreUnknownKeys = false }

    private val colors = setOf("red", "yellow", "green", "blue")
    private val bonusRows = setOf("redYellow", "greenBlue")
    private val variantConfigs = mapOf(
        "big-points" to (15 to true),
        "classic" to (12 to false),
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
    fun `fixtures directory exists and is non-empty`(): List<DynamicTest> {
        val dir = fixturesDir()
        val files = fixtureFiles(dir)
        return listOf(
            DynamicTest.dynamicTest("found ${files.size} fixture(s) under ${dir.absolutePath}") {
                assertTrue(files.isNotEmpty())
            },
        )
    }

    @TestFactory
    fun `every fixture is well-formed`(): List<DynamicTest> {
        val dir = fixturesDir()
        val files = fixtureFiles(dir)
        return files.map { file ->
            DynamicTest.dynamicTest(file.relativeTo(dir).path) {
                validateFixture(file)
            }
        }
    }

    private fun validateFixture(file: File) {
        val label = file.path
        val root = try {
            json.parseToJsonElement(file.readText()).jsonObject
        } catch (e: Exception) {
            fail<Unit>("$label: not valid JSON — ${e.message}")
            return
        }

        val game = root.stringField("game", label)
        when (game) {
            "qwixx" -> validateQwixxFixture(root, label)
            "qwixx-double" -> validateQwixxDoubleFixture(root, label)
            else -> fail<Unit>("$label: game='$game', expected 'qwixx' or 'qwixx-double'")
        }
    }

    private fun validateQwixxFixture(root: JsonObject, label: String) {
        val variant = root.stringField("variant", label)
        val variantBounds = variantConfigs[variant]
            ?: fail<Nothing>("$label: variant '$variant' must be one of ${variantConfigs.keys}")

        val config = root["config"]?.jsonObject
            ?: fail<Nothing>("$label: missing 'config' object")
        val scoringCap = config.intField("scoringCap", label)
        val hasBonusRows = config.boolField("hasBonusRows", label)
        val (expectedCap, expectedBonus) = variantBounds
        assertTrue(scoringCap == expectedCap) {
            "$label: config.scoringCap=$scoringCap inconsistent with variant '$variant' (expected $expectedCap)"
        }
        assertTrue(hasBonusRows == expectedBonus) {
            "$label: config.hasBonusRows=$hasBonusRows inconsistent with variant '$variant' (expected $expectedBonus)"
        }

        validateStepsAndCommonFields(root, label, allowedDoActions = qwixxDoActions)
    }

    /**
     * Qwixx Double (`spec/fixtures/qwixx-double/README.md`): same envelope,
     * `variant: "double-a"`, `config: {"scoringCap":16}` only (no bonus
     * rows), and `doubleColor` replaces `markBonus` in the step vocabulary.
     */
    private fun validateQwixxDoubleFixture(root: JsonObject, label: String) {
        val variant = root.stringField("variant", label)
        assertTrue(variant == "double-a") { "$label: variant='$variant', expected 'double-a'" }

        val config = root["config"]?.jsonObject
            ?: fail<Nothing>("$label: missing 'config' object")
        val scoringCap = config.intField("scoringCap", label)
        assertTrue(scoringCap == 16) {
            "$label: config.scoringCap=$scoringCap inconsistent with variant 'double-a' (expected 16)"
        }

        validateStepsAndCommonFields(root, label, allowedDoActions = qwixxDoubleDoActions)
    }

    private fun validateStepsAndCommonFields(root: JsonObject, label: String, allowedDoActions: Set<String>) {
        root.stringField("name", label)
        root.stringField("description", label)

        val steps = root["steps"]?.let { it as? JsonArray }
            ?: fail<Nothing>("$label: missing 'steps' array")
        assertTrue(steps.isNotEmpty()) { "$label: 'steps' must not be empty" }

        var hasAssert = false
        steps.forEachIndexed { index, stepElement ->
            val step = stepElement.jsonObject
            val stepLabel = "$label: step[$index]"
            when {
                "do" in step -> validateDoStep(step, stepLabel, allowedDoActions)
                "assert" in step -> {
                    hasAssert = true
                    validateAssertStep(step, stepLabel)
                }
                else -> fail<Unit>("$stepLabel: must contain exactly one of 'do' or 'assert', found keys ${step.keys}")
            }
        }

        assertTrue(hasAssert) { "$label: must contain at least one 'assert' step" }
    }

    private val qwixxDoActions = setOf("markColor", "markBonus", "penalty", "concede", "finish", "undo", "redo")
    private val qwixxDoubleDoActions = setOf("markColor", "doubleColor", "penalty", "concede", "finish", "undo", "redo")

    private fun validateDoStep(step: JsonObject, stepLabel: String, allowedActions: Set<String>) {
        val action = step.stringField("do", stepLabel)
        if ("expect" !in step) {
            fail<Unit>("$stepLabel: 'do':\"$action\" is missing required 'expect' boolean")
        }
        step.boolField("expect", stepLabel)

        // "note" is a documented optional key on any step (spec/README.md:
        // runners MUST ignore it) — tolerated here, validated as a string below.
        val knownKeys = setOf("do", "expect", "color", "index", "row", "note")
        val extra = step.keys - knownKeys
        assertTrue(extra.isEmpty()) { "$stepLabel: unexpected keys $extra on 'do' step" }
        if ("note" in step) step.stringField("note", stepLabel)

        assertTrue(action in allowedActions) {
            "$stepLabel: unknown 'do' action '$action' (expected one of $allowedActions)"
        }

        when (action) {
            "markColor", "doubleColor" -> {
                val color = step.stringField("color", stepLabel)
                assertTrue(color in colors) { "$stepLabel: $action color '$color' not in $colors" }
                val index = step.intField("index", stepLabel)
                assertTrue(index in 0..10) { "$stepLabel: $action index $index out of range 0..10" }
            }
            "markBonus" -> {
                val row = step.stringField("row", stepLabel)
                assertTrue(row in bonusRows) { "$stepLabel: markBonus row '$row' not in $bonusRows" }
                val index = step.intField("index", stepLabel)
                assertTrue(index in 0..10) { "$stepLabel: markBonus index $index out of range 0..10" }
            }
            "penalty" -> {
                assertTrue(step.keys - setOf("note") == setOf("do", "expect")) {
                    "$stepLabel: penalty takes no fields besides 'do'/'expect', found ${step.keys}"
                }
            }
            "concede" -> {
                val color = step.stringField("color", stepLabel)
                assertTrue(color in colors) { "$stepLabel: concede color '$color' not in $colors" }
            }
            "finish", "undo", "redo" -> {
                assertTrue(step.keys - setOf("note") == setOf("do", "expect")) {
                    "$stepLabel: '$action' takes no fields besides 'do'/'expect', found ${step.keys}"
                }
            }
        }
    }

    private fun validateAssertStep(step: JsonObject, stepLabel: String) {
        val assertion = step["assert"]?.jsonObject
            ?: fail<Nothing>("$stepLabel: 'assert' must be an object")
        // "note" is the one permitted sibling (optional, ignored by runners).
        assertTrue(step.keys - setOf("note") == setOf("assert")) {
            "$stepLabel: 'assert' step must not have sibling keys, found ${step.keys}"
        }
        if ("note" in step) step.stringField("note", stepLabel)
        assertTrue(assertion.isNotEmpty()) { "$stepLabel: 'assert' object must not be empty" }

        val knownKeys = setOf(
            "points", "crosses", "penalties", "penaltyPoints", "totalScore",
            "isGameOver", "lockedRowCount", "rowLocked", "canUndo", "canRedo",
        )
        val extra = assertion.keys - knownKeys
        assertTrue(extra.isEmpty()) { "$stepLabel: unknown assert keys $extra" }

        assertion["points"]?.let { validatePerColorMap(it, "$stepLabel.points", colors) }
        assertion["crosses"]?.let { validatePerColorMap(it, "$stepLabel.crosses", colors) }
        assertion["rowLocked"]?.let { validatePerColorBoolMap(it, "$stepLabel.rowLocked", colors) }

        assertion["penalties"]?.let {
            assertTrue(it.jsonPrimitive.intOrNull != null) { "$stepLabel.penalties must be an int" }
        }
        assertion["penaltyPoints"]?.let {
            assertTrue(it.jsonPrimitive.intOrNull != null) { "$stepLabel.penaltyPoints must be an int" }
        }
        assertion["totalScore"]?.let {
            assertTrue(it.jsonPrimitive.intOrNull != null) { "$stepLabel.totalScore must be an int" }
        }
        assertion["lockedRowCount"]?.let {
            assertTrue(it.jsonPrimitive.intOrNull != null) { "$stepLabel.lockedRowCount must be an int" }
        }
        assertion["isGameOver"]?.let {
            assertTrue(it.jsonPrimitive.booleanOrNull != null) { "$stepLabel.isGameOver must be a bool" }
        }
        assertion["canUndo"]?.let {
            assertTrue(it.jsonPrimitive.booleanOrNull != null) { "$stepLabel.canUndo must be a bool" }
        }
        assertion["canRedo"]?.let {
            assertTrue(it.jsonPrimitive.booleanOrNull != null) { "$stepLabel.canRedo must be a bool" }
        }
    }

    private fun validatePerColorMap(element: JsonElement, label: String, keySet: Set<String>) {
        val obj = element.jsonObject
        val unknown = obj.keys - keySet
        assertTrue(unknown.isEmpty()) { "$label: unknown color keys $unknown (expected subset of $keySet)" }
        obj.forEach { (key, value) ->
            assertTrue(value.jsonPrimitive.intOrNull != null) { "$label.$key must be an int" }
        }
    }

    private fun validatePerColorBoolMap(element: JsonElement, label: String, keySet: Set<String>) {
        val obj = element.jsonObject
        val unknown = obj.keys - keySet
        assertTrue(unknown.isEmpty()) { "$label: unknown color keys $unknown (expected subset of $keySet)" }
        obj.forEach { (key, value) ->
            assertTrue(value.jsonPrimitive.booleanOrNull != null) { "$label.$key must be a bool" }
        }
    }

    // --- small typed-field helpers giving "file + field" failure messages ---

    private fun JsonObject.stringField(key: String, label: String): String {
        val value = this[key]?.jsonPrimitive?.contentOrNull
            ?: fail<Nothing>("$label: missing required string field '$key'")
        return value
    }

    private fun JsonObject.intField(key: String, label: String): Int {
        val prim = this[key]?.jsonPrimitive as? JsonPrimitive
            ?: fail<Nothing>("$label: missing required int field '$key'")
        return prim.intOrNull ?: fail("$label: field '$key' is not an int (value=$prim)")
    }

    private fun JsonObject.boolField(key: String, label: String): Boolean {
        val prim = this[key]?.jsonPrimitive as? JsonPrimitive
            ?: fail<Nothing>("$label: missing required bool field '$key'")
        return prim.booleanOrNull ?: fail("$label: field '$key' is not a bool (value=$prim)")
    }

}
