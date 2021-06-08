package squirrelparser.clause.terminal;

import squirrelparser.node.Match;
import squirrelparser.parser.Parser;

/**
 * Match a run of zero or more whitespace characters, defined by {@link Character#isWhitespace()}. (Always matches,
 * even if the character at the current position is not a whitespace character.)
 */
public class Whitespace extends Terminal {
    public Whitespace() {
    }

    @Override
    public Match match(int pos, int rulePos, Parser parser) {
        int currPos = pos;
        while (currPos < parser.input.length()) {
            if (Character.isWhitespace(parser.input.charAt(currPos))) {
                currPos++;
            } else {
                break;
            }
        }
        // Matches zero or more whitespace characters (always matches)
        return new Match(this, pos, currPos - pos);
    }

    @Override
    public String toString() {
        return labelClause("<WS>");
    }
}
