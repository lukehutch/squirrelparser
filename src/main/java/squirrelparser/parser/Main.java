package squirrelparser.parser;

import java.util.HashMap;
import java.util.Map;

import squirrelparser.clause.Clause;
import squirrelparser.clause.nonterminal.First;
import squirrelparser.clause.nonterminal.RuleRef;
import squirrelparser.clause.nonterminal.Seq;
import squirrelparser.clause.terminal.Terminal;

public class Main {

	public static void main(String[] args) {
		Map<String, Clause> grammar = new HashMap<>();
		grammar.put("A", new First(new Seq(new RuleRef("A"), new Terminal('a')), new Terminal('a')));
		
		var parser = new Parser("aaa", grammar, "A");
		
		var match = parser.parse();
	}

}
