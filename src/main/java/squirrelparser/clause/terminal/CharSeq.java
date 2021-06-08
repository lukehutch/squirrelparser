package squirrelparser.clause.terminal;

import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.utils.StringUtils;

/** Matches a sequence of characters (i.e. a fixed string). */
public class CharSeq extends Terminal {
    private final String seq;
    private final boolean ignoreCase;

    public CharSeq(String seq, boolean ignoreCase) {
        this.seq = seq;
        this.ignoreCase = ignoreCase;
    }

    public CharSeq(String seq) {
        this.seq = seq;
        this.ignoreCase = false;
    }

    @Override
    public Match match(int pos, int rulePos, Parser parser) {
        if (pos <= parser.input.length() - seq.length()
                && parser.input.regionMatches(ignoreCase, pos, seq, 0, seq.length())) {
            return new Match(this, pos, seq.length());
        } else {
            return Match.NO_MATCH;
        }
    }

    @Override
    public String toString() {
        return labelClause('"' + StringUtils.escapeString(seq) + '"');
    }
}
