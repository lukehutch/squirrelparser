package com.squirrelparser.clause.nonterminal;

import java.util.List;
import java.util.Map;

import com.squirrelparser.clause.Clause;
import com.squirrelparser.parser.Match;
import com.squirrelparser.parser.MatchResult;
import com.squirrelparser.parser.Parser;

/**
 * Reference to a named rule.
 */
public final class Ref extends Clause {
    private final String ruleName;

    public Ref(String ruleName) {
        this.ruleName = ruleName;
    }

    public String ruleName() {
        return ruleName;
    }

    @Override
    public MatchResult match(Parser parser, int pos, Clause bound) {
        Clause clause = parser.rules().get(ruleName);
        if (clause == null) {
            throw new IllegalArgumentException("Rule \"" + ruleName + "\" not found");
        }
        MatchResult result = parser.match(clause, pos, bound);
        if (result.isMismatch()) {
            return result;
        }
        return Match.withChildren(this, List.of(result), result.isComplete());
    }

    @Override
    public void checkRuleRefs(Map<String, Clause> grammarMap) {
        if (!grammarMap.containsKey(ruleName) && !grammarMap.containsKey("~" + ruleName)) {
            throw new IllegalArgumentException("Rule \"" + ruleName + "\" not found in grammar");
        }
    }

    @Override
    public String toString() {
        return ruleName;
    }
}
