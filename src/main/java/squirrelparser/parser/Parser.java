package squirrelparser.parser;

import java.util.HashMap;
import java.util.Map;

import squirrelparser.node.Match;
import squirrelparser.rule.Grammar;

public class Parser {
    /** The grammar. */
    private Grammar grammar;

    /** The input to parse. */
    public final String input;

    /** The memo table. */
    public final Map<RuleAndPos, Match> memoTable = new HashMap<>();

    /** One entry for each recursion frame in stack. Value indicates whether key is a cycle head or not. */
    public final Map<RuleAndPos, Boolean> cycleStart = new HashMap<>();

    public Parser(Grammar grammar, String input) {
        this.grammar = grammar;
        this.input = input;
    }

    public Match parse() {
        return grammar.topRule.match(0, /* parentRulePos = */ -1, this);
    }
}
