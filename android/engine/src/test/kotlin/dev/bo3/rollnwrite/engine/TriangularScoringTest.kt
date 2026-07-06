package dev.bo3.rollnwrite.engine

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.CsvSource

class TriangularScoringTest {

    @ParameterizedTest
    @CsvSource(
        "1, 1",
        "2, 3",
        "3, 6",
        "4, 10",
        "5, 15",
    )
    fun `triangular values for n = 1 to 5`(crosses: Int, expectedPoints: Int) {
        val scoring = TriangularScoring(cap = 15)
        assertEquals(expectedPoints, scoring.points(forCrosses = crosses))
    }

    @Test
    fun `cap 15 caps at 120 for 15 crosses and beyond`() {
        val scoring = TriangularScoring(cap = 15)
        assertEquals(120, scoring.points(forCrosses = 15))
        assertEquals(120, scoring.points(forCrosses = 16))
        assertEquals(120, scoring.points(forCrosses = 100))
    }

    @Test
    fun `cap 12 caps at 78`() {
        val scoring = TriangularScoring(cap = 12)
        assertEquals(78, scoring.points(forCrosses = 12))
        assertEquals(78, scoring.points(forCrosses = 20))
    }

    @Test
    fun `zero and negative crosses score zero`() {
        val scoring = TriangularScoring(cap = 15)
        assertEquals(0, scoring.points(forCrosses = 0))
        assertEquals(0, scoring.points(forCrosses = -1))
        assertEquals(0, scoring.points(forCrosses = -100))
    }
}
