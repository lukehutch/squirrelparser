package squirrelparser.clause.terminal;

import java.util.regex.Pattern;

import squirrelparser.node.Match;
import squirrelparser.parser.Parser;

/**
 * Matches if the regexp matches, starting at the current position. The length of the match is the number of
 * characters matched by the regexp.
 */
public class RegexpToken extends Terminal {
    private final String regexp;
    private final Pattern pattern;

    public RegexpToken(String regexp) {
        this.regexp = regexp;
        this.pattern = Pattern.compile(regexp);
    }

    @Override
    public Match match(int pos, int rulePos, Parser parser) {
        var matcher = pattern.matcher(parser.input.subSequence(pos, parser.input.length()));
        if (matcher.lookingAt()) {
            return new Match(this, pos, pos + matcher.end());
        } else {
            return Match.NO_MATCH;
        }
    }

    @Override
    public String toString() {
        return labelClause('`' + regexp + '`');
    }
}
