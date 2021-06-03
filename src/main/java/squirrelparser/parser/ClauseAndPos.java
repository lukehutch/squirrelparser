package squirrelparser.parser;

import squirrelparser.clause.Clause;

public record ClauseAndPos(Clause clause, int pos) {
	@Override
	public String toString() {
		return clause.getClass().getSimpleName() + "[" + clause + "]" + ":" + pos;
	}
}
