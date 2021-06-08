package squirrelparser.parser;

import squirrelparser.grammar.Rule;

/** The current rule being parsed, and the current position of the parser. */ 
public record RuleAndPos(Rule rule, int pos) {
    @Override
    public String toString() {
        return rule.ruleName + " <- " + rule.clause + " : " + pos;
    }
}
