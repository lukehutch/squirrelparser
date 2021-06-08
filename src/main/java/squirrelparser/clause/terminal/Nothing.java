package squirrelparser.clause.terminal;

import squirrelparser.node.Match;
import squirrelparser.parser.Parser;

public class Nothing extends Terminal {
    @Override
    public Match match(int pos, int rulePos, Parser parser) {
        return new Match(this, pos);
    }

    @Override
    public String toString() {
        return labelClause("()");
    }
}
