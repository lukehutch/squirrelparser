package squirrelparser.parser;

import java.util.Arrays;

import squirrelparser.clause.nonterminal.First;
import squirrelparser.clause.nonterminal.RuleRef;
import squirrelparser.clause.nonterminal.Seq;
import squirrelparser.clause.terminal.CharSet;
import squirrelparser.rule.Rule;

public class Main {

	public static void main(String[] args) {
		var rules = Arrays
				.asList(new Rule("A", new First(new Seq(new RuleRef("A"), new CharSet('a')), new CharSet('a'))));

		var parser = new Parser("aaa", rules, "A");

		var match = parser.parse();

		System.out.println("\nParse result:");
		match.print(0, parser.input);
	}

}
