package squirrelparser.clause.nonterminal;

import java.util.ArrayList;
import java.util.List;

import squirrelparser.clause.Clause;
import squirrelparser.clause.ClauseWithOneSubClause;
import squirrelparser.match.Match;
import squirrelparser.match.MatchMultiple;
import squirrelparser.match.MatchResult;
import squirrelparser.parser.ClauseAndPos;
import squirrelparser.parser.Parser;

public class OneOrMore extends ClauseWithOneSubClause {
	public OneOrMore(Clause subClause) {
		super(subClause);
	}

	@Override
	public MatchResult match(ClauseAndPos clauseAndPos, Parser parser) {
		List<Match> subClauseMatches = null;
		int currPos = clauseAndPos.pos();
		for (;;) {
			var subClauseMatchResult = parser.match(clauseAndPos.pos(), new ClauseAndPos(subClause, currPos));
			if (subClauseMatchResult == MatchResult.NO_MATCH) {
				break;
			}
			if (subClauseMatches == null) {
				subClauseMatches = new ArrayList<>();
			}
			var subClauseMatch = (Match) subClauseMatchResult;
			subClauseMatches.add(subClauseMatch);
			currPos += subClauseMatch.len;
			// If subclauseMatch.len == 0, then we have a pathological grammar that will trigger an
			// infinite loop, e.g. e+ (where e is the empty string) -- only match once.
			if (subClauseMatch.len == 0) {
				break;
			}
		}
		return subClauseMatches == null ? MatchResult.NO_MATCH
				: new MatchMultiple(clauseAndPos, subClauseMatches.toArray(new Match[subClauseMatches.size()]));
	}

	public String toStringInternal() {
		return subClause + "+";
	}
}
