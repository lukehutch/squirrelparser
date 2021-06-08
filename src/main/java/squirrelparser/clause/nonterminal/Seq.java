package squirrelparser.clause.nonterminal;

import java.util.ArrayList;
import java.util.List;

import squirrelparser.clause.Clause;
import squirrelparser.clause.Clause.ClauseWithMultipleSubClauses;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;

/** Matches if all subclauses match. */
public class Seq extends ClauseWithMultipleSubClauses {
    public Seq(Clause... subClauses) {
        super(subClauses);
    }

    @Override
    public Match match(int pos, int rulePos, Parser parser) {
        List<Match> subClauseMatches = null;
        for (int i = 0, currPos = pos; i < subClauses.length; i++) {
            var subClauseMatch = subClauses[i].match(currPos, rulePos, parser);
            if (subClauseMatch == Match.NO_MATCH) {
                return Match.NO_MATCH;
            }
            if (subClauseMatches == null) {
                subClauseMatches = new ArrayList<>(subClauses.length);
            }
            subClauseMatches.add(subClauseMatch);
            currPos += subClauseMatch.len;
        }
        return new Match(this, pos, subClauseMatches);
    }

    @Override
    public String toString() {
        var buf = new StringBuilder();
        for (int i = 0; i < subClauses.length; i++) {
            if (i > 0) {
                buf.append(' ');
            }
            buf.append(subClauseToString(subClauses[i]));
        }
        return labelClause(buf.toString());
    }
}
