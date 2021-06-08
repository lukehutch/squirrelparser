package squirrelparser.clause.nonterminal;

import squirrelparser.clause.Clause;
import squirrelparser.clause.Clause.ClauseWithMultipleSubClauses;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;

public class First extends ClauseWithMultipleSubClauses {
    public First(Clause... subClauses) {
        super(subClauses);
    }

    @Override
    public Match match(int pos, int rulePos, Parser parser) {
        for (int subClauseIdx = 0; subClauseIdx < subClauses.length; subClauseIdx++) {
            var subClauseMatch = subClauses[subClauseIdx].match(pos, rulePos, parser);
            if (subClauseMatch != Match.NO_MATCH) {
                return new Match(this, subClauseIdx, subClauseMatch);
            }
        }
        return Match.NO_MATCH;
    }

    @Override
    public String toString() {
        var buf = new StringBuilder();
        for (int i = 0; i < subClauses.length; i++) {
            if (i > 0) {
                buf.append(" / ");
            }
            buf.append(subClauseToString(subClauses[i]));
        }
        return labelClause(buf.toString());
    }
}
