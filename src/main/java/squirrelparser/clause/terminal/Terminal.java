package squirrelparser.clause.terminal;

import squirrelparser.clause.ClauseWithZeroSubClauses;
import squirrelparser.match.Match;
import squirrelparser.parser.Parser;

public class Terminal extends ClauseWithZeroSubClauses {
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
	public String toStringInternal() {
		String chrStr;
		switch (chr) {
		case '\'':
			chrStr = "\\'";
			break;
		case '\n':
			chrStr = "\\n";
			break;
		case '\r':
			chrStr = "\\r";
			break;
		case '\t':
			chrStr = "\\t";
			break;
		case '\b':
			chrStr = "\\b";
			break;
		default:
			if (chr < 32 || chr > 126) {
				String hex = "000" + Integer.toHexString(chr);
				chrStr = "\\u" + hex.substring(hex.length() - 4);
			} else {
				chrStr = Character.toString(chr);
			}
		}
		return "'" + chrStr + "'";
	}
}
