package squirrelparser.clause.terminal;

import squirrelparser.clause.Clause;
import squirrelparser.match.Match;
import squirrelparser.parser.Parser;
import squirrelparser.utils.Utils;

public class Terminal extends Clause {
	public final char chr;

	public Terminal(char chr) {
		this.chr = chr;
	}

	@Override
	public Match match(int pos, int rulePos, Parser parser) {
		return pos < parser.input.length() && parser.input.charAt(pos) == chr ? new Match(this, pos, 1)
				: Match.NO_MATCH;
	}

	@Override
	public String toString() {
		return "'" + Utils.chrToStrEscaped(chr) + "'";
	}
}
