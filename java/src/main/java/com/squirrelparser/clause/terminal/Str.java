package com.squirrelparser.clause.terminal;

import static com.squirrelparser.parser.MatchResult.mismatch;

import com.squirrelparser.clause.Clause;
import com.squirrelparser.parser.Match;
import com.squirrelparser.parser.MatchResult;
import com.squirrelparser.parser.Parser;
import com.squirrelparser.parser.Utils;

/**
 * Matches a literal string.
 */
public final class Str extends Terminal {
    private final String text;

    public Str(String text) {
        this.text = text;
    }

    public String text() {
        return text;
    }

    @Override
    public MatchResult match(Parser parser, int pos, Clause bound) {
        if (pos + text.length() > parser.input().length()) {
            return mismatch();
        }
        for (int i = 0; i < text.length(); i++) {
            if (parser.input().charAt(pos + i) != text.charAt(i)) {
                return mismatch();
            }
        }
        return new Match(this, pos, text.length());
    }

    @Override
    public String toString() {
        return "\"" + Utils.escapeString(text) + "\"";
    }
}
