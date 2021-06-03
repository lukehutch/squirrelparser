package squirrelparser.main;

import java.util.Arrays;

import squirrelparser.clause.nonterminal.First;
import squirrelparser.clause.nonterminal.RuleRef;
import squirrelparser.clause.nonterminal.Seq;
import squirrelparser.clause.terminal.CharSet;
import squirrelparser.node.CSTNode;
import squirrelparser.parser.Parser;
import squirrelparser.rule.Rule;

public class Main {
	public static void main(String[] args) {
		var rules = Arrays
				.asList(new Rule("A", new First(new Seq(new RuleRef("A"), new CharSet('a')), new CharSet('a'))));

		var parser = new Parser("aaa", rules, "A");

		var match = parser.parse();

		System.out.println("\nParse tree:");
		match.print(parser.input);

		System.out.println("\nCST:");
		var cst = new CSTNode(match, parser.input);
		cst.print();
	}
}
