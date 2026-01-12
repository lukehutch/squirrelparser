package com.squirrelparser.clause.terminal;

import static com.squirrelparser.parser.MatchResult.mismatch;

import com.squirrelparser.clause.Clause;
import com.squirrelparser.parser.Match;
import com.squirrelparser.parser.MatchResult;
import com.squirrelparser.parser.Parser;
import com.squirrelparser.parser.Utils;

/**
 * Matches a single character.
 */
public final class Char extends Terminal {
    private final String ch;

    public Char(String ch) {
        if (ch.length() != 1) {
            throw new IllegalArgumentException("Char must be a single character");
        }
        this.ch = ch;
    }

    public String ch() {
        return ch;
    }

    @Override
    public MatchResult match(Parser parser, int pos, Clause bound) {
        if (pos + ch.length() > parser.input().length()) {
            return mismatch();
        }
        for (int i = 0; i < ch.length(); i++) {
            if (parser.input().charAt(pos + i) != ch.charAt(i)) {
                return mismatch();
            }
        }
        return new Match(this, pos, ch.length());
    }

    @Override
    public String toString() {
        return "'" + Utils.escapeString(ch) + "'";
    }
}
