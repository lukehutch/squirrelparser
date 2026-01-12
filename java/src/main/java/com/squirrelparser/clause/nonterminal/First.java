package com.squirrelparser.clause.nonterminal;

import static com.squirrelparser.parser.MatchResult.mismatch;

import java.util.List;
import java.util.stream.Collectors;

import com.squirrelparser.clause.Clause;
import com.squirrelparser.parser.Match;
import com.squirrelparser.parser.MatchResult;
import com.squirrelparser.parser.Parser;

/**
 * Ordered choice: matches the first successful sub-clause.
 */
public final class First extends HasMultipleSubClauses {
    public First(List<Clause> subClauses) {
        super(subClauses);
    }

    @Override
    public MatchResult match(Parser parser, int pos, Clause bound) {
        for (int i = 0; i < subClauses.size(); i++) {
            MatchResult result = parser.match(subClauses.get(i), pos, bound);
            if (!result.isMismatch()) {
                if (parser.inRecoveryPhase() && i == 0 && result.totDescendantErrors() > 0) {
                    MatchResult bestResult = result;
                    int bestLen = result.len();
                    int bestErrors = result.totDescendantErrors();

                    for (int j = 1; j < subClauses.size(); j++) {
                        MatchResult altResult = parser.match(subClauses.get(j), pos, bound);
                        if (!altResult.isMismatch()) {
                            int altLen = altResult.len();
                            int altErrors = altResult.totDescendantErrors();

                            double bestErrorRate = bestLen > 0 ? (double) bestErrors / bestLen : 0.0;
                            double altErrorRate = altLen > 0 ? (double) altErrors / altLen : 0.0;
                            double errorRateThreshold = 0.5;

                            if ((bestErrorRate >= errorRateThreshold && altErrorRate < errorRateThreshold)
                                    || altLen > bestLen
                                    || (altLen == bestLen && altErrors < bestErrors)) {
                                bestResult = altResult;
                                bestLen = altLen;
                                bestErrors = altErrors;
                            }
                            if (altErrors == 0 && altLen >= bestLen) {
                                break;
                            }
                        }
                    }
                    return Match.withChildren(this, List.of(bestResult), bestResult.isComplete());
                }
                return Match.withChildren(this, List.of(result), result.isComplete());
            }
        }
        return mismatch();
    }

    @Override
    public String toString() {
        return "(" + subClauses.stream().map(Object::toString).collect(Collectors.joining(" / ")) + ")";
    }
}
