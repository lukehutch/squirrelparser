package com.squirrelparser.clause.terminal;

import com.squirrelparser.clause.Clause;
import com.squirrelparser.parser.Match;
import com.squirrelparser.parser.MatchResult;
import com.squirrelparser.parser.Parser;

/**
 * Matches nothing - always succeeds without consuming any input.
 */
public final class Nothing extends Terminal {
    @Override
    public MatchResult match(Parser parser, int pos, Clause bound) {
        return new Match(this, pos, 0);
    }

    @Override
    public String toString() {
        return "()";
    }
}
