package com.squirrelparser.clause.terminal;

import static com.squirrelparser.parser.MatchResult.mismatch;

import com.squirrelparser.clause.Clause;
import com.squirrelparser.parser.Match;
import com.squirrelparser.parser.MatchResult;
import com.squirrelparser.parser.Parser;

/**
 * Matches any single character.
 */
public final class AnyChar extends Terminal {
    @Override
    public MatchResult match(Parser parser, int pos, Clause bound) {
        if (pos >= parser.input().length()) {
            return mismatch();
        }
        return new Match(this, pos, 1);
    }

    @Override
    public String toString() {
        return ".";
    }
}
