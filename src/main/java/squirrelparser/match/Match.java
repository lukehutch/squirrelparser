package squirrelparser.match;

import squirrelparser.parser.ClauseAndPos;
import squirrelparser.parser.Parser;

public abstract class Match extends MatchResult {
	public final ClauseAndPos clauseAndPos;
	public final int len;

	public Match(ClauseAndPos clauseAndPos, int len) {
		this.clauseAndPos = clauseAndPos;
		this.len = len;
	}

	protected String getLocationStr() {
		return (clauseAndPos.clause().ruleName != null ? clauseAndPos.clause().ruleName + ":" : "") + clauseAndPos
				+ "+" + len;
	}

	public void print(int pos, int indent, Parser parser) {
		for (int i = 0; i < indent; i++) {
			System.out.print("--");
		}
		System.out.print(getLocationStr());
		System.out.println("[" + parser.input.substring(pos, Math.min(parser.input.length(), pos + len)) + "]"); // TODO: why does this need min?
	}
	
	@Override
	public String toString() {
		return clauseAndPos + "+" + len;
	}
}