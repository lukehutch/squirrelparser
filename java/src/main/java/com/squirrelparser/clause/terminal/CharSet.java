package com.squirrelparser.clause.terminal;

import static com.squirrelparser.parser.MatchResult.mismatch;

import java.util.List;

import com.squirrelparser.clause.Clause;
import com.squirrelparser.parser.Match;
import com.squirrelparser.parser.MatchResult;
import com.squirrelparser.parser.Parser;
import com.squirrelparser.parser.Utils;

/**
 * Matches a single character in a set of character ranges.
 *
 * Supports multiple ranges and an optional inversion flag for negated character
 * classes like `[^a-zA-Z0-9]`.
 */
public final class CharSet extends Terminal {
    /** List of character ranges as (lo, hi) code unit pairs (inclusive). */
    private final List<int[]> ranges;

    /** If true, matches any character NOT in the set. */
    private final boolean inverted;

    public CharSet(List<int[]> ranges, boolean inverted) {
        this.ranges = ranges;
        this.inverted = inverted;
    }

    public CharSet(List<int[]> ranges) {
        this(ranges, false);
    }

    /** Convenience factory for a single character range. */
    public static CharSet range(String lo, String hi) {
        return new CharSet(List.of(new int[]{lo.codePointAt(0), hi.codePointAt(0)}), false);
    }

    /** Convenience factory for a single character. */
    public static CharSet ofChar(String c) {
        int cp = c.codePointAt(0);
        return new CharSet(List.of(new int[]{cp, cp}), false);
    }

    /** Convenience factory for a negated single character range. */
    public static CharSet notRange(String lo, String hi) {
        return new CharSet(List.of(new int[]{lo.codePointAt(0), hi.codePointAt(0)}), true);
    }

    public List<int[]> ranges() {
        return ranges;
    }

    public boolean inverted() {
        return inverted;
    }

    @Override
    public MatchResult match(Parser parser, int pos, Clause bound) {
        if (pos >= parser.input().length()) {
            return mismatch();
        }
        int c = parser.input().codePointAt(pos);

        boolean inSet = false;
        for (int[] range : ranges) {
            if (c >= range[0] && c <= range[1]) {
                inSet = true;
                break;
            }
        }

        if (inverted ? !inSet : inSet) {
            return new Match(this, pos, 1);
        }
        return mismatch();
    }

    @Override
    public String toString() {
        var buf = new StringBuilder("[");
        if (inverted) {
            buf.append("^");
        }
        for (int[] range : ranges) {
            if (range[0] == range[1]) {
                buf.append(Utils.escapeString(Character.toString(range[0])));
            } else {
                buf.append(Utils.escapeString(Character.toString(range[0])));
                buf.append("-");
                buf.append(Utils.escapeString(Character.toString(range[1])));
            }
        }
        buf.append("]");
        return buf.toString();
    }
}
