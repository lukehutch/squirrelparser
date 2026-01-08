package com.squirrelparser;

import static com.squirrelparser.TestUtils.parse;
import static com.squirrelparser.TestUtils.parseForTree;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Optional;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Combinators.ZeroOrMore;
import com.squirrelparser.Terminals.Str;

/**
 * SECTION 10: MONOTONIC INVARIANT TESTS (60 tests)
 * Port of monotonic_test.dart
 *
 * These tests verify that the monotonic improvement check only applies to
 * left-recursive clauses, not to all clauses. Without this fix, indirect
 * and interwoven left recursion would fail.
 */
class MonotonicTest {

    // --- Direct LR: E <- E '+n' / 'n' ---
    private static final Map<String, Clause> directLRSimple = Map.of(
        "E", new First(
            new Seq(new Ref("E"), new Str("+n")),
            new Str("n")
        )
    );

    @Test
    void testLRDirect01n() {
        var r = parseForTree(directLRSimple, "n", "E");
        assertTrue(r != null && r.len() == 1, "should parse n");
    }

    @Test
    void testLRDirect02npn() {
        var r = parseForTree(directLRSimple, "n+n", "E");
        assertTrue(r != null && r.len() == 3, "should parse n+n");
    }

    @Test
    void testLRDirect03npnpn() {
        var r = parseForTree(directLRSimple, "n+n+n", "E");
        assertTrue(r != null && r.len() == 5, "should parse n+n+n");
    }

    // --- Indirect LR: E <- F / 'n'; F <- E '+n' ---
    private static final Map<String, Clause> indirectLRSimple = Map.of(
        "E", new First(new Ref("F"), new Str("n")),
        "F", new Seq(new Ref("E"), new Str("+n"))
    );

    @Test
    void testLRIndirect01n() {
        var r = parseForTree(indirectLRSimple, "n", "E");
        assertTrue(r != null && r.len() == 1, "should parse n");
    }

    @Test
    void testLRIndirect02npn() {
        var r = parseForTree(indirectLRSimple, "n+n", "E");
        assertTrue(r != null && r.len() == 3, "should parse n+n");
    }

    @Test
    void testLRIndirect03npnpn() {
        var r = parseForTree(indirectLRSimple, "n+n+n", "E");
        assertTrue(r != null && r.len() == 5, "should parse n+n+n");
    }

    // --- Direct Hidden LR: E <- F? E '+n' / 'n'; F <- 'f' ---
    private static final Map<String, Clause> directHiddenLR = Map.of(
        "E", new First(
            new Seq(new Optional(new Ref("F")), new Ref("E"), new Str("+n")),
            new Str("n")
        ),
        "F", new Str("f")
    );

    @Test
    void testLRDirectHidden01n() {
        var r = parseForTree(directHiddenLR, "n", "E");
        assertTrue(r != null && r.len() == 1, "should parse n");
    }

    @Test
    void testLRDirectHidden02npn() {
        var r = parseForTree(directHiddenLR, "n+n", "E");
        assertTrue(r != null && r.len() == 3, "should parse n+n");
    }

    @Test
    void testLRDirectHidden03npnpn() {
        var r = parseForTree(directHiddenLR, "n+n+n", "E");
        assertTrue(r != null && r.len() == 5, "should parse n+n+n");
    }

    @Test
    void testLRDirectHidden04fnpn() {
        var r = parseForTree(directHiddenLR, "fn+n", "E");
        assertTrue(r != null && r.len() == 4, "should parse fn+n");
    }

    // --- Indirect Hidden LR: E <- F E '+n' / 'n'; F <- "abc" / 'd'* ---
    private static final Map<String, Clause> indirectHiddenLR = Map.of(
        "E", new First(
            new Seq(new Ref("F"), new Ref("E"), new Str("+n")),
            new Str("n")
        ),
        "F", new First(new Str("abc"), new ZeroOrMore(new Str("d")))
    );

    @Test
    void testLRIndirectHidden01n() {
        var r = parseForTree(indirectHiddenLR, "n", "E");
        assertTrue(r != null && r.len() == 1, "should parse n");
    }

    @Test
    void testLRIndirectHidden02npn() {
        var r = parseForTree(indirectHiddenLR, "n+n", "E");
        assertTrue(r != null && r.len() == 3, "should parse n+n");
    }

    @Test
    void testLRIndirectHidden03npnpn() {
        var r = parseForTree(indirectHiddenLR, "n+n+n", "E");
        assertTrue(r != null && r.len() == 5, "should parse n+n+n");
    }

    @Test
    void testLRIndirectHidden04abcnpn() {
        var r = parseForTree(indirectHiddenLR, "abcn+n", "E");
        assertTrue(r != null && r.len() == 6, "should parse abcn+n");
    }

    @Test
    void testLRIndirectHidden05ddnpn() {
        var r = parseForTree(indirectHiddenLR, "ddn+n", "E");
        assertTrue(r != null && r.len() == 5, "should parse ddn+n");
    }

    // --- Multi-step Indirect LR: E <- F '+n' / 'n'; F <- "gh" / J; J <- 'k' / E 'l' ---
    private static final Map<String, Clause> multiStepLR = Map.of(
        "E", new First(
            new Seq(new Ref("F"), new Str("+n")),
            new Str("n")
        ),
        "F", new First(new Str("gh"), new Ref("J")),
        "J", new First(
            new Str("k"),
            new Seq(new Ref("E"), new Str("l"))
        )
    );

    @Test
    void testLRMultiStep01n() {
        var r = parseForTree(multiStepLR, "n", "E");
        assertTrue(r != null && r.len() == 1, "should parse n");
    }

    @Test
    void testLRMultiStep02ghpn() {
        var r = parseForTree(multiStepLR, "gh+n", "E");
        assertTrue(r != null && r.len() == 4, "should parse gh+n");
    }

    @Test
    void testLRMultiStep03kpn() {
        var r = parseForTree(multiStepLR, "k+n", "E");
        assertTrue(r != null && r.len() == 3, "should parse k+n");
    }

    @Test
    void testLRMultiStep04nlpn() {
        var r = parseForTree(multiStepLR, "nl+n", "E");
        assertTrue(r != null && r.len() == 4, "should parse nl+n");
    }

    @Test
    void testLRMultiStep05nlpnlpn() {
        var r = parseForTree(multiStepLR, "nl+nl+n", "E");
        assertTrue(r != null && r.len() == 7, "should parse nl+nl+n");
    }

    // --- Direct + Indirect LR (Interwoven): L <- P '.x' / 'x'; P <- P '(n)' / L ---
    private static final Map<String, Clause> interwovenLR = Map.of(
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
    void testLRInterwoven01x() {
        var r = parseForTree(interwovenLR, "x", "L");
        assertTrue(r != null && r.len() == 1, "should parse x");
    }

    @Test
    void testLRInterwoven02xdotx() {
        var r = parseForTree(interwovenLR, "x.x", "L");
        assertTrue(r != null && r.len() == 3, "should parse x.x");
    }

    @Test
    void testLRInterwoven03xndotx() {
        var r = parseForTree(interwovenLR, "x(n).x", "L");
        assertTrue(r != null && r.len() == 6, "should parse x(n).x");
    }

    @Test
    void testLRInterwoven04xnndotx() {
        var r = parseForTree(interwovenLR, "x(n)(n).x", "L");
        assertTrue(r != null && r.len() == 9, "should parse x(n)(n).x");
    }

    // --- Multiple Interlocking LR Cycles ---
    private static final Map<String, Clause> interlockingLR = Map.of(
        "E", new First(
            new Seq(new Ref("F"), new Str("n")),
            new Str("n")
        ),
        "F", new First(
            new Seq(new Ref("E"), new Str("+"), new ZeroOrMore(new Ref("I"))),
            new Seq(new Ref("G"), new Str("-"))
        ),
        "G", new First(
            new Seq(new Ref("H"), new Str("m")),
            new Ref("E")
        ),
        "H", new Seq(new Ref("G"), new Str("l")),
        "I", new Seq(new Str("("), new OneOrMore(new Ref("A")), new Str(")")),
        "A", new Str("a")
    );

    @Test
    void testLRInterlocking01n() {
        var r = parseForTree(interlockingLR, "n", "E");
        assertTrue(r != null && r.len() == 1, "should parse n");
    }

    @Test
    void testLRInterlocking02npn() {
        var r = parseForTree(interlockingLR, "n+n", "E");
        assertTrue(r != null && r.len() == 3, "should parse n+n");
    }

    @Test
    void testLRInterlocking03nmn() {
        var r = parseForTree(interlockingLR, "n-n", "E");
        assertTrue(r != null && r.len() == 3, "should parse n-n");
    }

    @Test
    void testLRInterlocking04nlmmn() {
        var r = parseForTree(interlockingLR, "nlm-n", "E");
        assertTrue(r != null && r.len() == 5, "should parse nlm-n");
    }

    @Test
    void testLRInterlocking05nparan() {
        var r = parseForTree(interlockingLR, "n+(aaa)n", "E");
        assertTrue(r != null && r.len() == 8, "should parse n+(aaa)n");
    }

    @Test
    void testLRInterlocking06complex() {
        var r = parseForTree(interlockingLR, "nlm-n+(aaa)n", "E");
        assertTrue(r != null && r.len() == 12, "should parse nlm-n+(aaa)n");
    }

    // --- LR Precedence Grammar ---
    private static final Map<String, Clause> precedenceGrammar = Map.of(
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
    void testLRPrecedence01n() {
        var r = parseForTree(precedenceGrammar, "n", "E");
        assertTrue(r != null && r.len() == 1, "should parse n");
    }

    @Test
    void testLRPrecedence02npn() {
        var r = parseForTree(precedenceGrammar, "n+n", "E");
        assertTrue(r != null && r.len() == 3, "should parse n+n");
    }

    @Test
    void testLRPrecedence03nmn() {
        var r = parseForTree(precedenceGrammar, "n*n", "E");
        assertTrue(r != null && r.len() == 3, "should parse n*n");
    }

    @Test
    void testLRPrecedence04npnmn() {
        var r = parseForTree(precedenceGrammar, "n+n*n", "E");
        assertTrue(r != null && r.len() == 5, "should parse n+n*n");
    }

    @Test
    void testLRPrecedence05complex() {
        var r = parseForTree(precedenceGrammar, "n+n*n+n/n", "E");
        assertTrue(r != null && r.len() == 9, "should parse n+n*n+n/n");
    }

    @Test
    void testLRPrecedence06parens() {
        var r = parseForTree(precedenceGrammar, "(n+n)*n", "E");
        assertTrue(r != null && r.len() == 7, "should parse (n+n)*n");
    }

    // --- LR Error Recovery ---
    @Test
    void testLRRecoveryLeadingError() {
        var r = parse(directLRSimple, "+n+n+n+", "E");
        if (r.success()) {
            assertTrue(r.errorCount() >= 1, "should have errors if succeeded");
        }
    }

    @Test
    void testLRRecoveryTrailingPlus() {
        var parser = new Parser(directLRSimple, "n+n+n+");
        var result = parser.parse("E");
        if (result != null && !result.isMismatch()) {
            assertTrue(result.len() >= 5, "should parse at least n+n+n");
        }
    }

    // --- Indirect Left Recursion (Fig7b): A <- B / 'x'; B <- (A 'y') / (A 'x') ---
    private static final Map<String, Clause> fig7b = Map.of(
        "A", new First(new Ref("B"), new Str("x")),
        "B", new First(
            new Seq(new Ref("A"), new Str("y")),
            new Seq(new Ref("A"), new Str("x"))
        )
    );

    @Test
    void testMILR01x() {
        var r = parseForTree(fig7b, "x", "A");
        assertTrue(r != null && r.len() == 1, "should parse x");
    }

    @Test
    void testMILR02xx() {
        var r = parseForTree(fig7b, "xx", "A");
        assertTrue(r != null && r.len() == 2, "should parse xx");
    }

    @Test
    void testMILR03xy() {
        var r = parseForTree(fig7b, "xy", "A");
        assertTrue(r != null && r.len() == 2, "should parse xy");
    }

    @Test
    void testMILR04xxy() {
        var r = parseForTree(fig7b, "xxy", "A");
        assertTrue(r != null && r.len() == 3, "should parse xxy");
    }

    @Test
    void testMILR05xxyx() {
        var r = parseForTree(fig7b, "xxyx", "A");
        assertTrue(r != null && r.len() == 4, "should parse xxyx");
    }

    @Test
    void testMILR06xyx() {
        var r = parseForTree(fig7b, "xyx", "A");
        assertTrue(r != null && r.len() == 3, "should parse xyx");
    }

    // --- Interwoven Left Recursion (Fig7f): L <- P '.x' / 'x'; P <- P '(n)' / L ---
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
    void testMIW01x() {
        var r = parseForTree(fig7f, "x", "L");
        assertTrue(r != null && r.len() == 1, "should parse x");
    }

    @Test
    void testMIW02xdotx() {
        var r = parseForTree(fig7f, "x.x", "L");
        assertTrue(r != null && r.len() == 3, "should parse x.x");
    }

    @Test
    void testMIW03xndotx() {
        var r = parseForTree(fig7f, "x(n).x", "L");
        assertTrue(r != null && r.len() == 6, "should parse x(n).x");
    }

    @Test
    void testMIW04xnndotx() {
        var r = parseForTree(fig7f, "x(n)(n).x", "L");
        assertTrue(r != null && r.len() == 9, "should parse x(n)(n).x");
    }

    @Test
    void testMIW05complex() {
        var r = parseForTree(fig7f, "x.x(n)(n).x.x", "L");
        assertTrue(r != null && r.len() == 13, "should parse x.x(n)(n).x.x");
    }

    // --- Optional-Dependent Left Recursion (Fig7d): A <- 'x'? (A 'y' / A / 'y') ---
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
    void testMOD01y() {
        var r = parseForTree(fig7d, "y", "A");
        assertTrue(r != null && r.len() == 1, "should parse y");
    }

    @Test
    void testMOD02xy() {
        var r = parseForTree(fig7d, "xy", "A");
        assertTrue(r != null && r.len() == 2, "should parse xy");
    }

    @Test
    void testMOD03xxyyy() {
        var r = parseForTree(fig7d, "xxyyy", "A");
        assertTrue(r != null && r.len() == 5, "should parse xxyyy");
    }

    // --- Input-Dependent Left Recursion (Fig7c): A <- B / 'z'; B <- ('x' A) / (A 'y') ---
    private static final Map<String, Clause> fig7c = Map.of(
        "A", new First(new Ref("B"), new Str("z")),
        "B", new First(
            new Seq(new Str("x"), new Ref("A")),
            new Seq(new Ref("A"), new Str("y"))
        )
    );

    @Test
    void testMID01z() {
        var r = parseForTree(fig7c, "z", "A");
        assertTrue(r != null && r.len() == 1, "should parse z");
    }

    @Test
    void testMID02xz() {
        var r = parseForTree(fig7c, "xz", "A");
        assertTrue(r != null && r.len() == 2, "should parse xz");
    }

    @Test
    void testMID03zy() {
        var r = parseForTree(fig7c, "zy", "A");
        assertTrue(r != null && r.len() == 2, "should parse zy");
    }

    @Test
    void testMID04xxzyyy() {
        var r = parseForTree(fig7c, "xxzyyy", "A");
        assertTrue(r != null && r.len() == 6, "should parse xxzyyy");
    }

    // --- Triple-nested indirect LR ---
    private static final Map<String, Clause> tripleLR = Map.of(
        "A", new First(new Ref("B"), new Str("a")),
        "B", new First(new Ref("C"), new Str("b")),
        "C", new First(
            new Seq(new Ref("A"), new Str("x")),
            new Str("c")
        )
    );

    @Test
    void testMTLR01a() {
        var r = parseForTree(tripleLR, "a", "A");
        assertTrue(r != null && r.len() == 1, "should parse a");
    }

    @Test
    void testMTLR02ax() {
        var r = parseForTree(tripleLR, "ax", "A");
        assertTrue(r != null && r.len() == 2, "should parse ax");
    }

    @Test
    void testMTLR03axx() {
        var r = parseForTree(tripleLR, "axx", "A");
        assertTrue(r != null && r.len() == 3, "should parse axx");
    }

    @Test
    void testMTLR04axxx() {
        var r = parseForTree(tripleLR, "axxx", "A");
        assertTrue(r != null && r.len() == 4, "should parse axxx");
    }
}
