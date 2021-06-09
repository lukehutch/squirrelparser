//
// This file is part of the squirrel parser reference implementation:
//
//     https://github.com/lukehutch/squirrelparser
//
// This software is provided under the MIT license:
//
// Copyright 2021 Luke A. D. Hutchison
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
// and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions
// of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
// TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
// CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
//
package squirrelparser.utils;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.concurrent.atomic.AtomicInteger;

import squirrelparser.grammar.Rule;
import squirrelparser.grammar.clause.nonterminal.First;
import squirrelparser.grammar.clause.nonterminal.RuleRef;

/**
 * Rewrite a grammar from precedence-associativity form into plain PEG rules.
 * 
 * <code>
        For all but the highest precedence level:
        
        E[0] <- E (Op E)+  =>  E[0] <- (E[1] (Op E[1])+) / E[1] 
        E[0,L] <- E Op E   =>  E[0] <- (E[0] Op E[1]) / E[1] 
        E[0,R] <- E Op E   =>  E[0] <- (E[1] Op E[0]) / E[1]
        E[3] <- '-' E      =>  E[3] <- '-' (E[3] / E[4]) / E[4]
        
        For highest precedence level, next highest precedence wraps back to lowest precedence level:
        
        E[5] <- '(' E ')'  =>  E[5] <- '(' E[0] ')'
 * </code>
 * 
 */
public class PrecAssocRuleRewriter {
    /** Rewrite self-references in a precedence hierarchy into precedence-climbing form. */
    private static void rewriteRuleGroup(List<PrecAssocRule> ruleGroup,
            Map<String, String> ruleNameToLowestPrecedenceLevelRuleNameOut) {
        var ruleNameWithoutPrecedence = ruleGroup.get(0).ruleName;

        // Check there are no duplicate precedence levels
        var precedenceToRule = new TreeMap<Integer, PrecAssocRule>();
        for (var rule : ruleGroup) {
            if (precedenceToRule.put(rule.precedence, rule) != null) {
                throw new IllegalArgumentException("Multiple rules with name " + ruleNameWithoutPrecedence
                        + (rule.precedence == -1 ? "" : " and precedence " + rule.precedence));
            }
        }
        // Get rules in ascending order of precedence
        var precedenceOrder = new ArrayList<>(precedenceToRule.values());

        // Rename rules to include precedence level
        var numPrecedenceLevels = ruleGroup.size();
        for (int precedenceIdx = 0; precedenceIdx < numPrecedenceLevels; precedenceIdx++) {
            // Since there is more than one precedence level, update rule name to include precedence
            var rule = precedenceOrder.get(precedenceIdx);
            rule.ruleName += "[" + rule.precedence + "]";
        }

        // Transform grammar rule to handle precence
        for (int precedenceIdx = 0; precedenceIdx < numPrecedenceLevels; precedenceIdx++) {
            var rule = precedenceOrder.get(precedenceIdx);

            // Count the number of self-references among descendant clauses of rule
            var numSelfRefs = new AtomicInteger(0);
            rule.traverse(clause -> {
                if (clause instanceof RuleRef
                        && ((RuleRef) clause).refdRuleName.equals(ruleNameWithoutPrecedence)) {
                    numSelfRefs.incrementAndGet();
                    if (numSelfRefs.get() > 2) {
                        throw new IllegalArgumentException(
                                "Cannot infer how to re-write precedence rule " + ruleNameWithoutPrecedence
                                        + " since there are more than 2 self references in a single rule");
                    }
                }
                return clause;
            });

            var currPrecRuleName = rule.ruleName;
            var nextHighestPrecRuleName = precedenceOrder.get((precedenceIdx + 1) % numPrecedenceLevels).ruleName;

            // If a rule has 1+ self-references, need to rewrite rule to handle precedence and associativity
            var isHighestPrec = precedenceIdx == numPrecedenceLevels - 1;
            if (numSelfRefs.get() >= 1) {
                // Rewrite self-references to higher precedence or left- and right-recursive forms.
                // (the toplevel clause of the rule, rule.clause, can't be a self-reference,
                // since we already checked for that, and IllegalArgumentException would have been thrown.)
                var numSelfRefsSoFar = new AtomicInteger(0);
                rule.traverse(clause -> {
                    if (clause instanceof RuleRef) {
                        if (((RuleRef) clause).refdRuleName.equals(ruleNameWithoutPrecedence)) {
                            numSelfRefsSoFar.incrementAndGet();
                            if (numSelfRefs.get() == 2) {
                                // Change name of self-references to implement precedence climbing:
                                // For leftmost operand of left-recursive rule:
                                // E[i] <- E X E  =>  E[i] = E[i] X E[i+1]
                                // For rightmost operand of right-recursive rule:
                                // E[i] <- E X E  =>  E[i] = E[i+1] X E[i]
                                // For non-associative rule:
                                // E[i] = E E  =>  E[i] = E[i+1] E[i+1]
                                return new RuleRef(
                                        (rule.associativity == Associativity.LEFT && numSelfRefsSoFar.get() == 1)
                                                || (rule.associativity == Associativity.RIGHT
                                                        && numSelfRefsSoFar.get() == numSelfRefs.get())
                                                                ? currPrecRuleName
                                                                : nextHighestPrecRuleName);
                            } else if (numSelfRefs.get() == 1) {
                                if (!isHighestPrec) {
                                    // Move subclause (and its AST node label, if any) inside a First clause that
                                    // climbs precedence to the next level:
                                    // E[i] <- X E Y  =>  E[i] <- X (E[i] / E[(i+1)%N]) Y
                                    return new First(new RuleRef(currPrecRuleName),
                                            new RuleRef(nextHighestPrecRuleName));
                                } else {
                                    // Except for highest precedence, just defer back to lowest-prec level:
                                    // E[N-1] <- '(' E ')'  =>  E[N-1] <- '(' E[0] ')'        
                                    return new RuleRef(nextHighestPrecRuleName);
                                }
                            }
                        }
                    }
                    return clause;
                });
            }

            // Defer to next highest level of precedence if the rule doesn't match, except at the highest level of
            // precedence, which is assumed to be a precedence-breaking pattern (like parentheses), so should not
            // defer back to the lowest precedence level unless the pattern itself matches
            if (!isHighestPrec) {
                // Move rule's toplevel clause (and any AST node label it has) into the first subclause of
                // a First clause that fails over to the next highest precedence level
                rule.clause = new First(rule.clause, new RuleRef(nextHighestPrecRuleName));
            }
        }

        // Map the bare rule name (without precedence suffix) to the lowest precedence level rule name
        var lowestPrecRule = precedenceOrder.get(0);
        ruleNameToLowestPrecedenceLevelRuleNameOut.put(ruleNameWithoutPrecedence, lowestPrecRule.ruleName);
    }

    /** Rewrite a list of rules in precedence-associativity form into plain PEG form. */
    public static List<Rule> rewrite(List<PrecAssocRule> precAssocRules) {
        if (precAssocRules.isEmpty()) {
            throw new IllegalArgumentException("Need at least one rule");
        }
        var topRuleName = precAssocRules.get(0).ruleName;

        // Group rules with identical names (these all need to have different precedence levels,
        // otherwise an exception will be thrown later)
        var ruleNameToRuleGroup = new HashMap<String, List<PrecAssocRule>>();
        for (var rule : precAssocRules) {
            var ruleGroup = ruleNameToRuleGroup.get(rule.ruleName);
            if (ruleGroup == null) {
                ruleNameToRuleGroup.put(rule.ruleName, ruleGroup = new ArrayList<>());
            }
            ruleGroup.add(rule);
        }

        // Rewrite rules for any rule group with at least two different precedence levels, by creating a new
        // clause tree that implements the precedence and associativity rules of each rule in the rule group
        var ruleNameToLowestPrecedenceLevelRuleName = new HashMap<String, String>();
        for (var ent : ruleNameToRuleGroup.entrySet()) {
            var ruleGroup = ent.getValue();
            if (ruleGroup.size() > 1) {
                // Rule group contains at least 2 precedence levels
                rewriteRuleGroup(ruleGroup, ruleNameToLowestPrecedenceLevelRuleName);
            }
        }

        // Rewrite RuleRefs that refer to a precedence group to refer to the lowest clause in the precedence group
        for (var precRewrittenRule : precAssocRules) {
            precRewrittenRule.traverse(clause -> {
                if (clause instanceof RuleRef) {
                    var ruleRef = (RuleRef) clause;
                    var refdRuleName = ruleRef.refdRuleName;
                    var refdRuleNameLowestPrecLevel = ruleNameToLowestPrecedenceLevelRuleName.get(refdRuleName);
                    if (refdRuleNameLowestPrecLevel != null) {
                        ruleRef.refdRuleName = refdRuleNameLowestPrecLevel;
                    }
                }
                return clause;
            });
        }
        if (ruleNameToLowestPrecedenceLevelRuleName.containsKey(topRuleName)) {
            topRuleName = ruleNameToLowestPrecedenceLevelRuleName.get(topRuleName);
        }

        // Now the precedence level and associativity can be dropped, converting PrecAssocRule into Rule
        var rules = new ArrayList<Rule>();
        var topRule = (Rule) null;
        for (var precRewrittenRule : precAssocRules) {
            var rewrittenRule = new Rule(precRewrittenRule.ruleName, precRewrittenRule.clause);
            if (rewrittenRule.ruleName.equals(topRuleName)) {
                topRule = rewrittenRule;
            } else {
                rules.add(rewrittenRule);
            }
        }

        // Move top rule to the beginning of the list
        if (topRule == null) {
            throw new IllegalArgumentException("Could not find top rule " + topRuleName);
        }
        rules.add(0, topRule);

        return rules;
    }
}
