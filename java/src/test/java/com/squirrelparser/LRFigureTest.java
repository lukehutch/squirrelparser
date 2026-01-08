package com.squirrelparser;

import static com.squirrelparser.TestUtils.isLeftAssociative;
import static com.squirrelparser.TestUtils.parse;
import static com.squirrelparser.TestUtils.parseForTree;
import static com.squirrelparser.TestUtils.verifyOperatorCount;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.Optional;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Terminals.Str;

/**
 * LEFT RECURSION FIGURE TESTS
 * Port of lr_figure_test.dart
 *
 * Tests for left recursion patterns from paper figures:
 * - Fig 7a-f demonstrate various LR patterns
 * - These tests verify correct parsing and tree structure
 */
class LRFigureTest {

    // ===========================================================================
    // Figure 7a - Direct Left Recursion: E <- E '+n' / 'n'
    // ===========================================================================

    private static final Map<String, Clause> fig7a = Map.of(
        "E", new First(
            new Seq(new Ref("E"), new Str("+n")),
            new Str("n")
        )
    );

    @Test
    void testFig7a_01_n() {
        var r = parseForTree(fig7a, "n", "E");
        assertNotNull(r, "should parse n");
        assertEquals(1, r.len(), "length should be 1");
    }

    @Test
    void testFig7a_02_n_plus_n() {
        var r = parseForTree(fig7a, "n+n", "E");
        assertNotNull(r, "should parse n+n");
        assertEquals(3, r.len(), "length should be 3");
    }

    @Test
    void testFig7a_03_n_plus_n_plus_n() {
        var r = parseForTree(fig7a, "n+n+n", "E");
        assertNotNull(r, "should parse n+n+n");
        assertEquals(5, r.len(), "length should be 5");
    }

    @Test
    void testFig7a_04_leftAssociative() {
        var r = parseForTree(fig7a, "n+n+n", "E");
        assertNotNull(r, "should parse");

        // Wrap in Ref match so isLeftAssociative sees the root as an instance of E
        var wrapped = new Match(
            new Ref("E"),
            r.pos(),
            r.len(),
            java.util.List.of(r),
            r.isComplete(),
            r.isFromLRContext()
        );

        assertTrue(isLeftAssociative(wrapped, "E"), "should be left-associative");
    }

    @Test
    void testFig7a_05_twoOps() {
        var r = parseForTree(fig7a, "n+n+n", "E");
        assertNotNull(r, "should parse");
        assertTrue(verifyOperatorCount(r, "+n", 2), "should have 2 operators");
    }

    // ===========================================================================
    // Figure 7b - Indirect Left Recursion: A <- B / 'x'; B <- (A 'y') / (A 'x')
    // ===========================================================================

    private static final Map<String, Clause> fig7b = Map.of(
        "A", new First(new Ref("B"), new Str("x")),
        "B", new First(
            new Seq(new Ref("A"), new Str("y")),
            new Seq(new Ref("A"), new Str("x"))
        )
    );

    @Test
    void testFig7b_01_x() {
        var r = parseForTree(fig7b, "x", "A");
        assertNotNull(r, "should parse x");
        assertEquals(1, r.len());
    }

    @Test
    void testFig7b_02_xx() {
        var r = parseForTree(fig7b, "xx", "A");
        assertNotNull(r, "should parse xx");
        assertEquals(2, r.len());
    }

    @Test
    void testFig7b_03_xy() {
        var r = parseForTree(fig7b, "xy", "A");
        assertNotNull(r, "should parse xy");
        assertEquals(2, r.len());
    }

    @Test
    void testFig7b_04_xxy() {
        var r = parseForTree(fig7b, "xxy", "A");
        assertNotNull(r, "should parse xxy");
        assertEquals(3, r.len());
    }

    @Test
    void testFig7b_05_xxyx() {
        var r = parseForTree(fig7b, "xxyx", "A");
        assertNotNull(r, "should parse xxyx");
        assertEquals(4, r.len());
    }

    @Test
    void testFig7b_06_xyx() {
        var r = parseForTree(fig7b, "xyx", "A");
        assertNotNull(r, "should parse xyx");
        assertEquals(3, r.len());
    }

    // ===========================================================================
    // Figure 7c - Input-Dependent: A <- B / 'z'; B <- ('x' A) / (A 'y')
    // ===========================================================================

    private static final Map<String, Clause> fig7c = Map.of(
        "A", new First(new Ref("B"), new Str("z")),
        "B", new First(
            new Seq(new Str("x"), new Ref("A")),
            new Seq(new Ref("A"), new Str("y"))
        )
    );

    @Test
    void testFig7c_01_z() {
        var r = parseForTree(fig7c, "z", "A");
        assertNotNull(r, "should parse z");
        assertEquals(1, r.len());
    }

    @Test
    void testFig7c_02_xz() {
        var r = parseForTree(fig7c, "xz", "A");
        assertNotNull(r, "should parse xz");
        assertEquals(2, r.len());
    }

    @Test
    void testFig7c_03_zy() {
        var r = parseForTree(fig7c, "zy", "A");
        assertNotNull(r, "should parse zy");
        assertEquals(2, r.len());
    }

    @Test
    void testFig7c_04_xxzyyy() {
        var r = parseForTree(fig7c, "xxzyyy", "A");
        assertNotNull(r, "should parse xxzyyy");
        assertEquals(6, r.len());
    }

    // ===========================================================================
    // Figure 7d - Optional-Dependent: A <- 'x'? (A 'y' / A / 'y')
    // ===========================================================================

    private static final Map<String, Clause> fig7d = Map.of(
        "A", new Seq(
            new Optional(new Str("x")),
            new First(
                new Seq(new Ref("A"), new Str("y")),
                new Ref("A"),
                new Str("y")
            )
        )
    );

    @Test
    void testFig7d_01_y() {
        var r = parseForTree(fig7d, "y", "A");
        assertNotNull(r, "should parse y");
        assertEquals(1, r.len());
    }

    @Test
    void testFig7d_02_xy() {
        var r = parseForTree(fig7d, "xy", "A");
        assertNotNull(r, "should parse xy");
        assertEquals(2, r.len());
    }

    @Test
    void testFig7d_03_xxyyy() {
        var r = parseForTree(fig7d, "xxyyy", "A");
        assertNotNull(r, "should parse xxyyy");
        assertEquals(5, r.len());
    }

    // ===========================================================================
    // Figure 7e - Hidden LR: E <- F? E '+n' / 'n'; F <- 'f'
    // ===========================================================================

    private static final Map<String, Clause> fig7e = Map.of(
        "E", new First(
            new Seq(new Optional(new Ref("F")), new Ref("E"), new Str("+n")),
            new Str("n")
        ),
        "F", new Str("f")
    );

    @Test
    void testFig7e_01_n() {
        var r = parseForTree(fig7e, "n", "E");
        assertNotNull(r, "should parse n");
        assertEquals(1, r.len());
    }

    @Test
    void testFig7e_02_n_plus_n() {
        var r = parseForTree(fig7e, "n+n", "E");
        assertNotNull(r, "should parse n+n");
        assertEquals(3, r.len());
    }

    @Test
    void testFig7e_03_fn_plus_n() {
        var r = parseForTree(fig7e, "fn+n", "E");
        assertNotNull(r, "should parse fn+n");
        assertEquals(4, r.len());
    }

    @Test
    void testFig7e_04_n_plus_n_plus_n() {
        var r = parseForTree(fig7e, "n+n+n", "E");
        assertNotNull(r, "should parse n+n+n");
        assertEquals(5, r.len());
    }

    // ===========================================================================
    // Figure 7f - Interwoven: L <- P '.x' / 'x'; P <- P '(n)' / L
    // ===========================================================================

    private static final Map<String, Clause> fig7f = Map.of(
        "L", new First(
            new Seq(new Ref("P"), new Str(".x")),
            new Str("x")
        ),
        "P", new First(
            new Seq(new Ref("P"), new Str("(n)")),
            new Ref("L")
        )
    );

    @Test
    void testFig7f_01_x() {
        var r = parseForTree(fig7f, "x", "L");
        assertNotNull(r, "should parse x");
        assertEquals(1, r.len());
    }

    @Test
    void testFig7f_02_x_dot_x() {
        var r = parseForTree(fig7f, "x.x", "L");
        assertNotNull(r, "should parse x.x");
        assertEquals(3, r.len());
    }

    @Test
    void testFig7f_03_x_call_dot_x() {
        var r = parseForTree(fig7f, "x(n).x", "L");
        assertNotNull(r, "should parse x(n).x");
        assertEquals(6, r.len());
    }

    @Test
    void testFig7f_04_x_call_call_dot_x() {
        var r = parseForTree(fig7f, "x(n)(n).x", "L");
        assertNotNull(r, "should parse x(n)(n).x");
        assertEquals(9, r.len());
    }

    @Test
    void testFig7f_05_complex() {
        var r = parseForTree(fig7f, "x.x(n)(n).x.x", "L");
        assertNotNull(r, "should parse x.x(n)(n).x.x");
        assertEquals(13, r.len());
    }

    // ===========================================================================
    // Additional LR Tests: Depth and Structure
    // ===========================================================================

    // ===========================================================================
    // Error Recovery in LR
    // ===========================================================================

    @Test
    void testLRRecovery_01_fig7aSkip() {
        var result = parse(fig7a, "n+n+Xn", "E");
        // Note: With atomic '+n' terminal, X breaks it
        // This may fail or succeed depending on recovery semantics
        // The test verifies we don't crash
        assertNotNull(result);
    }

    @Test
    void testLRRecovery_02_fig7fSkip() {
        var result = parse(fig7f, "x(n)X.x", "L");
        // X between (n) and .x
        // May require recovery
        assertNotNull(result);
    }

    // ===========================================================================
    // Precedence Grammar (Classic)
    // ===========================================================================

    private static final Map<String, Clause> precedence = Map.of(
        "E", new First(
            new Seq(new Ref("E"), new Str("+"), new Ref("T")),
            new Seq(new Ref("E"), new Str("-"), new Ref("T")),
            new Ref("T")
        ),
        "T", new First(
            new Seq(new Ref("T"), new Str("*"), new Ref("F")),
            new Seq(new Ref("T"), new Str("/"), new Ref("F")),
            new Ref("F")
        ),
        "F", new First(
            new Seq(new Str("("), new Ref("E"), new Str(")")),
            new Str("n")
        )
    );

    @Test
    void testPrecedence_01_n() {
        var r = parseForTree(precedence, "n", "E");
        assertNotNull(r, "should parse n");
        assertEquals(1, r.len());
    }

    @Test
    void testPrecedence_02_n_plus_n() {
        var r = parseForTree(precedence, "n+n", "E");
        assertNotNull(r, "should parse n+n");
        assertEquals(3, r.len());
    }

    @Test
    void testPrecedence_03_n_times_n() {
        var r = parseForTree(precedence, "n*n", "E");
        assertNotNull(r, "should parse n*n");
        assertEquals(3, r.len());
    }

    @Test
    void testPrecedence_04_n_plus_n_times_n() {
        var r = parseForTree(precedence, "n+n*n", "E");
        assertNotNull(r, "should parse n+n*n");
        assertEquals(5, r.len());
        // Precedence: n+(n*n) not (n+n)*n
    }

    @Test
    void testPrecedence_05_parens() {
        var r = parseForTree(precedence, "(n+n)*n", "E");
        assertNotNull(r, "should parse (n+n)*n");
        assertEquals(7, r.len());
    }

    @Test
    void testPrecedence_06_complex() {
        var r = parseForTree(precedence, "n+n*n+n/n", "E");
        assertNotNull(r, "should parse n+n*n+n/n");
        assertEquals(9, r.len());
    }
}
