package squirrelparser.grammar.clause.nonterminal;

import squirrelparser.grammar.clause.Clause;
import squirrelparser.grammar.clause.ClauseWithMultipleSubClauses;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;

/** Matches the same span as the first subclause that is found to match. */
public class First extends ClauseWithMultipleSubClauses {
    public First(Clause... subClauses) {
        super(" / ", subClauses);
    }

    @Override
    public Match match(int pos, int rulePos, Parser parser) {
        for (int subClauseIdx = 0; subClauseIdx < subClauses.length; subClauseIdx++) {
            var subClauseMatch = subClauses[subClauseIdx].match(pos, rulePos, parser);
            if (subClauseMatch != Match.NO_MATCH) {
                return new Match(this, subClauseIdx, subClauseMatch);
            }
        }
        // No subclauses matched
        return Match.NO_MATCH;
    }
}
