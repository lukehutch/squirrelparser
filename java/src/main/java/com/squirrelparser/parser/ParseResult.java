package com.squirrelparser.parser;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * The result of parsing the input.
 */
public record ParseResult(
    String input,
    MatchResult root,
    String topRuleName,
    Set<String> transparentRules,
    boolean hasSyntaxErrors,
    SyntaxError unmatchedInput
) {
    /**
     * Get the syntax errors from the parse.
     */
    public List<SyntaxError> getSyntaxErrors() {
        if (!hasSyntaxErrors) {
            return List.of();
        }
        List<SyntaxError> errors = new ArrayList<>();
        collectErrors(root, errors);
        if (unmatchedInput != null) {
            errors.add(unmatchedInput);
        }
        return errors;
    }

    private void collectErrors(MatchResult result, List<SyntaxError> errors) {
        if (result instanceof SyntaxError se) {
            errors.add(se);
        } else if (!result.isMismatch()) {
            for (MatchResult sub : result.subClauseMatches()) {
                collectErrors(sub, errors);
            }
        }
    }
}
