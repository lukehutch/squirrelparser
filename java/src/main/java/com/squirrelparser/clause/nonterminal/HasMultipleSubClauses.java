package com.squirrelparser.clause.nonterminal;

import java.util.List;
import java.util.Map;

import com.squirrelparser.clause.Clause;

/**
 * Base class for clauses with multiple sub-clauses.
 */
public abstract sealed class HasMultipleSubClauses extends Clause permits Seq, First {
    protected final List<Clause> subClauses;

    protected HasMultipleSubClauses(List<Clause> subClauses) {
        this.subClauses = subClauses;
    }

    public List<Clause> subClauses() {
        return subClauses;
    }

    @Override
    public void checkRuleRefs(Map<String, Clause> grammarMap) {
        for (Clause clause : subClauses) {
            clause.checkRuleRefs(grammarMap);
        }
    }
}
