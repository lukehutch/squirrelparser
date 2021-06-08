package squirrelparser.utils;

import static java.util.Map.entry;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.BitSet;
import java.util.List;
import java.util.Map;

import squirrelparser.clause.Clause;
import squirrelparser.clause.nonterminal.First;
import squirrelparser.clause.nonterminal.FollowedBy;
import squirrelparser.clause.nonterminal.NotFollowedBy;
import squirrelparser.clause.nonterminal.OneOrMore;
import squirrelparser.clause.nonterminal.Optional;
import squirrelparser.clause.nonterminal.RuleRef;
import squirrelparser.clause.nonterminal.Seq;
import squirrelparser.clause.nonterminal.ZeroOrMore;
import squirrelparser.clause.terminal.CharSeq;
import squirrelparser.clause.terminal.CharSet;
import squirrelparser.clause.terminal.Nothing;
import squirrelparser.clause.terminal.Terminal;
import squirrelparser.node.ASTNode;
import squirrelparser.parser.Parser;
import squirrelparser.rule.Grammar;
import squirrelparser.utils.PrecAssocRuleRewriter.Associativity;
import squirrelparser.utils.PrecAssocRuleRewriter.PrecAssocRule;

/**
 * A "meta-grammar" that produces a runtime parser generator, allowing a grammar to be defined using ASCII notation.
 */
public class MetaGrammar {

    // Object construction methods for shorter notation:

    /** Construct a {@link PrecAssocRule}. */
    private static PrecAssocRule rule(String ruleName, Clause clause) {
        // Use -1 as precedence if rule group has only one precedence
        return rule(ruleName, -1, /* associativity = */ null, clause);
    }

    /** Construct a {@link PrecAssocRule} with the given precedence and associativity. */
    private static PrecAssocRule rule(String ruleName, int precedence, Associativity associativity, Clause clause) {
        var rule = new PrecAssocRule(ruleName, precedence, associativity, clause);
        return rule;
    }

    /** Construct a {@link Seq} clause. */
    private static Clause seq(Clause... subClauses) {
        return new Seq(subClauses);
    }

    /** Construct a {@link OneOrMore} clause. */
    private static Clause oneOrMore(Clause subClause) {
        // It doesn't make sense to wrap these clause types in OneOrMore, but the OneOrMore should have
        // no effect if this does occur in the grammar, so remove it
        if (subClause instanceof OneOrMore || subClause instanceof Nothing || subClause instanceof FollowedBy
                || subClause instanceof NotFollowedBy) {
            return subClause;
        }
        return new OneOrMore(subClause);
    }

    /** Construct an {@link Optional} clause. */
    private static Clause optional(Clause subClause) {
        return new Optional(subClause);
    }

    /** Construct a {@link ZeroOrMore} clause. */
    private static Clause zeroOrMore(Clause subClause) {
        return new ZeroOrMore(subClause);
    }

    /** Construct a {@link First} clause. */
    private static Clause first(Clause... subClauses) {
        return new First(subClauses);
    }

    /** Construct a {@link FollowedBy} clause. */
    private static Clause followedBy(Clause subClause) {
        if (subClause instanceof Nothing || subClause instanceof FollowedBy || subClause instanceof NotFollowedBy) {
            return subClause;
        }
        return new FollowedBy(subClause);
    }

    /** Construct a {@link NotFollowedBy} clause. */
    private static Clause notFollowedBy(Clause subClause) {
        if (subClause instanceof Nothing) {
            throw new IllegalArgumentException(NotFollowedBy.class.getSimpleName() + "("
                    + Nothing.class.getSimpleName() + ") will never match anything");
        } else if (subClause instanceof NotFollowedBy) {
            // Doubling NotFollowedBy yields FollowedBy.
            // N.B. this will not catch the case of "X <- !Y; Y <- !Z;", since RuleRefs are
            // not resolved yet
            return new FollowedBy(((NotFollowedBy) subClause).subClause);
        } else if (subClause instanceof FollowedBy) {
            return ((FollowedBy) subClause).subClause;
        }
        return new NotFollowedBy(subClause);
    }

    /** Construct a {@link Nothing} terminal. */
    private static Clause nothing() {
        return new Nothing();
    }

    /** Construct a terminal that matches a string token. */
    private static Clause str(String str) {
        if (str.length() == 1) {
            return c(str.charAt(0));
        } else {
            return new CharSeq(str);
        }
    }

    /** Construct a terminal that matches one instance of any character given in the varargs param. */
    private static CharSet c(char... chrs) {
        return new CharSet(chrs);
    }

    //	/** Construct a terminal that matches one instance of any character in a given string. */
    //	private static CharSet cInStr(String str) {
    //		return new CharSet(str.toCharArray());
    //	}

    /** Construct a terminal that matches a character range. */
    private static CharSet cRange(char minChar, char maxChar) {
        if (maxChar < minChar) {
            throw new IllegalArgumentException("maxChar < minChar");
        }
        char[] chars = new char[maxChar - minChar + 1];
        for (char c = minChar; c <= maxChar; c++) {
            chars[c - minChar] = c;
        }
        return new CharSet(chars);
    }

    /**
     * Construct a terminal that matches a character range, specified using regexp notation without the square
     * brackets.
     */
    private static CharSet cRange(String charRangeStr) {
        boolean invert = charRangeStr.startsWith("^");
        var charList = StringUtils.getCharRangeChars(invert ? charRangeStr.substring(1) : charRangeStr);
        var chars = new BitSet(128);
        for (int i = 0; i < charList.size(); i++) {
            var c = charList.get(i);
            if (c.length() == 2) {
                // Unescape \^, \-, \], \\
                c = c.substring(1);
            }
            var c0 = c.charAt(0);
            if (i <= charList.size() - 3 && charList.get(i + 1).equals("-")) {
                var cEnd = charList.get(i + 2);
                if (cEnd.length() == 2) {
                    // Unescape \^, \-, \], \\
                    cEnd = cEnd.substring(1);
                }
                var cEnd0 = cEnd.charAt(0);
                if (cEnd0 < c0) {
                    throw new IllegalArgumentException("Char range limits out of order: " + c0 + ", " + cEnd0);
                }
                chars.set(c0, cEnd0 + 1);
                i += 2;
            } else {
                chars.set(c0);
            }
        }
        return invert ? new CharSet(chars).invert() : new CharSet(chars);
    }

    /** Construct a character set as the union of other character sets. */
    private static CharSet c(CharSet... charSets) {
        return new CharSet(charSets);
    }

    /** Set the AST node label of a clause, then return the clause. */
    private static Clause ast(String astNodeLabel, Clause clause) {
        clause.astNodeLabel = astNodeLabel;
        return clause;
    }

    /** Construct a {@link RuleRef}. */
    private static Clause ruleRef(String ruleName) {
        return new RuleRef(ruleName);
    }

    // -------------------------------------------------------------------------------------------------------------

    // Precedence levels (should correspond to levels in metagrammar):

    private static Map<Class<? extends Clause>, Integer> clauseTypeToPrecedence = //
            Map.ofEntries( //
                    entry(Terminal.class, 7), //
                    entry(RuleRef.class, 7), //
                    entry(OneOrMore.class, 6), //
                    entry(ZeroOrMore.class, 6), //
                    entry(NotFollowedBy.class, 5), //
                    entry(FollowedBy.class, 5), //
                    entry(Optional.class, 4), //
                    // astNodeLabel has precedence 3
                    entry(Seq.class, 2), //
                    entry(First.class, 1) //
            );

    private static final int AST_NODE_LABEL_PRECEDENCE = 3;

    // Rule names:

    private static final String GRAMMAR = "GRAMMAR";
    private static final String WSC = "WSC";
    private static final String COMMENT = "COMMENT";
    private static final String RULE = "RULE";
    private static final String CLAUSE = "CLAUSE";
    private static final String IDENT = "IDENT";
    private static final String PREC = "PREC";
    private static final String NUM = "NUM";
    private static final String NAME_CHAR = "NAME_CHAR";
    private static final String CHAR_SET = "CHARSET";
    private static final String HEX = "HEX";
    private static final String CHAR_RANGE = "CHAR_RANGE";
    private static final String CHAR_RANGE_CHAR = "CHAR_RANGE_CHAR";
    private static final String QUOTED_STRING = "QUOTED_STR";
    private static final String ESCAPED_CTRL_CHAR = "ESCAPED_CTRL_CHAR";
    private static final String SINGLE_QUOTED_CHAR = "SINGLE_QUOTED_CHAR";
    private static final String STR_QUOTED_CHAR = "STR_QUOTED_CHAR";
    private static final String NOTHING = "NOTHING";

    // AST node names:

    private static final String RULE_AST = "RuleAST";
    private static final String PREC_AST = "PrecAST";
    private static final String R_ASSOC_AST = "RAssocAST";
    private static final String L_ASSOC_AST = "LAssocAST";
    private static final String IDENT_AST = "IdentAST";
    private static final String LABEL_AST = "LabelAST";
    private static final String LABEL_NAME_AST = "LabelNameAST";
    private static final String LABEL_CLAUSE_AST = "LabelClauseAST";
    private static final String SEQ_AST = "SeqAST";
    private static final String FIRST_AST = "FirstAST";
    private static final String FOLLOWED_BY_AST = "FollowedByAST";
    private static final String NOT_FOLLOWED_BY_AST = "NotFollowedByAST";
    private static final String ONE_OR_MORE_AST = "OneOrMoreAST";
    private static final String ZERO_OR_MORE_AST = "ZeroOrMoreAST";
    private static final String OPTIONAL_AST = "OptionalAST";
    private static final String SINGLE_QUOTED_CHAR_AST = "SingleQuotedCharAST";
    private static final String CHAR_RANGE_AST = "CharRangeAST";
    private static final String QUOTED_STRING_AST = "QuotedStringAST";
    private static final String NOTHING_AST = "NothingAST";

    // Metagrammar:

    private static List<PrecAssocRule> precAssocRules = Arrays.asList(//
            rule(GRAMMAR, //
                    seq(ruleRef(WSC), oneOrMore(ruleRef(RULE)))), //

            rule(RULE, //
                    ast(RULE_AST, seq(ruleRef(IDENT), ruleRef(WSC), //
                            optional(ruleRef(PREC)), //
                            str("<-"), ruleRef(WSC), //
                            ruleRef(CLAUSE), ruleRef(WSC), c(';'), ruleRef(WSC)))), //

            // Define precedence order for clause sequences

            // Parens
            rule(CLAUSE, 8, /* associativity = */ null, //
                    seq(c('('), ruleRef(WSC), ruleRef(CLAUSE), ruleRef(WSC), c(')'))), //

            // Terminals
            rule(CLAUSE, 7, /* associativity = */ null, //
                    first( //
                            ruleRef(IDENT), // RuleRef
                            ruleRef(QUOTED_STRING), //
                            ruleRef(CHAR_SET), //
                            ruleRef(NOTHING))), //

            // OneOrMore / ZeroOrMore
            rule(CLAUSE, 6, /* associativity = */ null, //
                    first( //
                            seq(ast(ONE_OR_MORE_AST, ruleRef(CLAUSE)), ruleRef(WSC), c('+')),
                            seq(ast(ZERO_OR_MORE_AST, ruleRef(CLAUSE)), ruleRef(WSC), c('*')))), //

            // FollowedBy / NotFollowedBy
            rule(CLAUSE, 5, /* associativity = */ null, //
                    first( //
                            seq(c('&'), ast(FOLLOWED_BY_AST, ruleRef(CLAUSE))), //
                            seq(c('!'), ast(NOT_FOLLOWED_BY_AST, ruleRef(CLAUSE))))), //

            // Optional
            rule(CLAUSE, 4, /* associativity = */ null, //
                    seq(ast(OPTIONAL_AST, ruleRef(CLAUSE)), ruleRef(WSC), c('?'))), //

            // ASTNodeLabel
            rule(CLAUSE, 3, /* associativity = */ null, //
                    ast(LABEL_AST,
                            seq(ast(LABEL_NAME_AST, ruleRef(IDENT)), ruleRef(WSC), c(':'), ruleRef(WSC),
                                    ast(LABEL_CLAUSE_AST, ruleRef(CLAUSE)), ruleRef(WSC)))), //

            // Seq
            rule(CLAUSE, 2, /* associativity = */ null, //
                    ast(SEQ_AST,
                            seq(ruleRef(CLAUSE), ruleRef(WSC), oneOrMore(seq(ruleRef(CLAUSE), ruleRef(WSC)))))),

            // First
            rule(CLAUSE, 1, /* associativity = */ null, //
                    ast(FIRST_AST,
                            seq(ruleRef(CLAUSE), ruleRef(WSC),
                                    oneOrMore(seq(c('/'), ruleRef(WSC), ruleRef(CLAUSE), ruleRef(WSC)))))),

            // Whitespace or comment
            rule(WSC, //
                    zeroOrMore(first(c(' ', '\n', '\r', '\t'), ruleRef(COMMENT)))),

            // Comment
            rule(COMMENT, //
                    seq(c('#'), zeroOrMore(c('\n').invert()))),

            // Identifier
            rule(IDENT, //
                    ast(IDENT_AST,
                            seq(ruleRef(NAME_CHAR), zeroOrMore(first(ruleRef(NAME_CHAR), cRange('0', '9')))))), //

            // Number
            rule(NUM, //
                    oneOrMore(cRange('0', '9'))), //

            // Name character
            rule(NAME_CHAR, //
                    c(cRange('a', 'z'), cRange('A', 'Z'), c('_', '-'))),

            // Precedence and optional associativity modifiers for rule name
            rule(PREC, //
                    seq(c('['), ruleRef(WSC), //
                            ast(PREC_AST, ruleRef(NUM)), ruleRef(WSC), //
                            optional(seq(c(','), ruleRef(WSC), //
                                    first(ast(R_ASSOC_AST, first(c('r'), c('R'))),
                                            ast(L_ASSOC_AST, first(c('l'), c('L')))),
                                    ruleRef(WSC))), //
                            c(']'), ruleRef(WSC))), //

            // Character set
            rule(CHAR_SET, //
                    first( //
                            seq(c('\''), ast(SINGLE_QUOTED_CHAR_AST, ruleRef(SINGLE_QUOTED_CHAR)), c('\'')), //
                            seq(c('['), //
                                    ast(CHAR_RANGE_AST, seq(optional(c('^')), //
                                            oneOrMore(first( //
                                                    ruleRef(CHAR_RANGE), //
                                                    ruleRef(CHAR_RANGE_CHAR))))),
                                    c(']')))), //

            // Single quoted character
            rule(SINGLE_QUOTED_CHAR, //
                    first( //
                            ruleRef(ESCAPED_CTRL_CHAR), //
                            c('\'').invert())), // TODO: replace invert() with NotFollowedBy

            // Char range
            rule(CHAR_RANGE, //
                    seq(ruleRef(CHAR_RANGE_CHAR), c('-'), ruleRef(CHAR_RANGE_CHAR))), //

            // Char range character
            rule(CHAR_RANGE_CHAR, //
                    first( //
                            c('\\', ']').invert(), //
                            ruleRef(ESCAPED_CTRL_CHAR), //
                            str("\\-"), //
                            str("\\\\"), //
                            str("\\]"), //
                            str("\\^"))),

            // Quoted string
            rule(QUOTED_STRING, //
                    seq(c('"'), ast(QUOTED_STRING_AST, zeroOrMore(ruleRef(STR_QUOTED_CHAR))), c('"'))), //

            // Character within quoted string
            rule(STR_QUOTED_CHAR, //
                    first( //
                            ruleRef(ESCAPED_CTRL_CHAR), //
                            c('"', '\\').invert() //
                    )), //

            // Hex digit
            rule(HEX, c(cRange('0', '9'), cRange('a', 'f'), cRange('A', 'F'))), //

            // Escaped control character
            rule(ESCAPED_CTRL_CHAR, //
                    first( //
                            str("\\t"), //
                            str("\\b"), //
                            str("\\n"), //
                            str("\\r"), //
                            str("\\f"), //
                            str("\\'"), //
                            str("\\\""), //
                            str("\\\\"), //
                            seq(str("\\u"), ruleRef(HEX), ruleRef(HEX), ruleRef(HEX), ruleRef(HEX)))), //

            // Nothing (empty string match)
            rule(NOTHING, //
                    ast(NOTHING_AST, seq(c('('), ruleRef(WSC), c(')')))));

    /** Rules rewritten to handle precedence and associativity. */
    private static Grammar metaGrammar = new Grammar(PrecAssocRuleRewriter.rewrite(precAssocRules));

    // -------------------------------------------------------------------------------------------------------------

    /**
     * Return true if subClause precedence is less than or equal to parentClause precedence (or if subclause is a
     * {@link Seq} clause and parentClause is a {@link First} clause, for clarity, even though parens are not needed
     * because Seq has higher prrecedence).
     */
    public static boolean needToAddParensAroundSubClause(Clause parentClause, Clause subClause) {
        int clausePrec = parentClause instanceof Terminal ? clauseTypeToPrecedence.get(Terminal.class)
                : clauseTypeToPrecedence.get(parentClause.getClass());
        int subClausePrec = subClause instanceof Terminal ? clauseTypeToPrecedence.get(Terminal.class)
                : clauseTypeToPrecedence.get(subClause.getClass());
        if (subClause.astNodeLabel != null && subClausePrec < AST_NODE_LABEL_PRECEDENCE) {
            // If subclause has an AST node label and the labeled clause requires parens, then don't add
            // a second set of parens around the subclause
            return false;
        } else {
            // Always parenthesize Seq inside First for clarity, even though Seq has higher precedence
            return ((parentClause instanceof First && subClause instanceof Seq)
                    // Add parentheses around subclauses that are lower or equal precedence to parent clause
                    || subClausePrec <= clausePrec);
        }
    }

    /** Return true if subclause has lower precedence than an AST node label. */
    public static boolean needToAddParensAroundASTNodeLabel(Clause subClause) {
        int subClausePrec = subClause instanceof Terminal ? clauseTypeToPrecedence.get(Terminal.class)
                : clauseTypeToPrecedence.get(subClause.getClass());
        return subClausePrec < /* astNodeLabel precedence */ AST_NODE_LABEL_PRECEDENCE;
    }

    // -------------------------------------------------------------------------------------------------------------

    /**
     * Expect just a single clause in the list of clauses, and return it, or throw an exception if the length of the
     * list of clauses is not 1.
     */
    private static Clause expectOne(List<Clause> clauses, ASTNode astNode) {
        if (clauses.size() != 1) {
            throw new IllegalArgumentException("Expected one subclause, got " + clauses.size() + ": " + astNode);
        }
        return clauses.get(0);
    }

    /** Recursively convert a list of AST nodes into a list of Clauses. */
    private static List<Clause> parseASTNodes(List<ASTNode> astNodes) {
        List<Clause> clauses = new ArrayList<>(astNodes.size());
        for (ASTNode astNode : astNodes) {
            clauses.add(parseASTNode(astNode));
        }
        return clauses;
    }

    /** Recursively parse a single AST node. */
    private static Clause parseASTNode(ASTNode astNode) {
        Clause clause;
        switch (astNode.label) {
        case SEQ_AST:
            clause = seq(parseASTNodes(astNode.children).toArray(new Clause[0]));
            break;
        case FIRST_AST:
            clause = first(parseASTNodes(astNode.children).toArray(new Clause[0]));
            break;
        case ONE_OR_MORE_AST:
            clause = oneOrMore(expectOne(parseASTNodes(astNode.children), astNode));
            break;
        case ZERO_OR_MORE_AST:
            clause = zeroOrMore(expectOne(parseASTNodes(astNode.children), astNode));
            break;
        case OPTIONAL_AST:
            clause = optional(expectOne(parseASTNodes(astNode.children), astNode));
            break;
        case FOLLOWED_BY_AST:
            clause = followedBy(expectOne(parseASTNodes(astNode.children), astNode));
            break;
        case NOT_FOLLOWED_BY_AST:
            clause = notFollowedBy(expectOne(parseASTNodes(astNode.children), astNode));
            break;
        case LABEL_AST:
            clause = ast(astNode.getFirstChild().getText(), parseASTNode(astNode.getSecondChild().getFirstChild()));
            break;
        case IDENT_AST:
            clause = ruleRef(astNode.getText());
            break;
        case QUOTED_STRING_AST: // Doesn't include surrounding quotes
            clause = str(StringUtils.unescapeString(astNode.getText()));
            break;
        case SINGLE_QUOTED_CHAR_AST:
            clause = c(StringUtils.unescapeChar(astNode.getText()));
            break;
        case NOTHING_AST:
            clause = nothing();
            break;
        case CHAR_RANGE_AST:
            clause = cRange(astNode.getText());
            break;
        default:
            throw new IllegalArgumentException("Unexpected grammar AST node label: " + astNode.label);
        //            // Keep recursing for parens (the only type of AST node that doesn't have a label)
        //            clause = expectOne(parseASTNodes(astNode.children), astNode);
        //            break;
        }
        return clause;
    }

    /** Parse a rule in the AST, returning a new {@link PrecAssocRule}. */
    private static PrecAssocRule parseRule(ASTNode ruleNode) {
        String ruleName = ruleNode.getFirstChild().getText();
        var hasPrecedence = ruleNode.children.size() > 2;
        var associativity = ruleNode.children.size() < 4 ? null
                : ((ruleNode.getThirdChild().label.equals(L_ASSOC_AST) ? Associativity.LEFT
                        : ruleNode.getThirdChild().label.equals(R_ASSOC_AST) ? Associativity.RIGHT : null));
        int precedence = hasPrecedence ? Integer.parseInt(ruleNode.getSecondChild().getText()) : -1;
        if (hasPrecedence && precedence < 0) {
            throw new IllegalArgumentException("Precedence needs to be zero or positive (rule " + ruleName
                    + " has precedence level " + precedence + ")");
        }
        var astNode = ruleNode.getChild(ruleNode.children.size() - 1);
        Clause clause = parseASTNode(astNode);
        return rule(ruleName, precedence, associativity, clause);
    }

    /** Parse a grammar description in an input string, returning a new {@link Grammar} object. */
    public static Grammar parse(String input) {
        // System.out.println(metaGrammar);

        var parser = new Parser(metaGrammar, input);
        var topMatch = parser.parse();

        //		ParserInfo.printParseResult("GRAMMAR", memoTable, new String[] { "GRAMMAR", "RULE", "CLAUSE[1]" },
        //				/* showAllMatches = */ false);
        //
        //		System.out.println("\nParsed meta-grammar:");
        //		for (var clause : MetaGrammar.grammar.allClauses) {
        //			System.out.println("    " + clause.toStringWithRuleNames());
        //		}

        if (topMatch.len != input.length()) {
            throw new IllegalArgumentException("Failed to match all input -- matched " + topMatch.len
                    + " characters; input length: " + input.length()); // TODO: smarter error handling
        }

        // System.out.println(topMatch.toStringWholeTree(input));

        //        var syntaxErrors = memoTable.getSyntaxErrors(GRAMMAR, RULE,
        //                CLAUSE + "[" + clauseTypeToPrecedence.get(First.class) + "]");
        //        if (!syntaxErrors.isEmpty()) {
        //            ParserInfo.printSyntaxErrors(syntaxErrors);
        //        }
        //
        //        var topLevelMatches = metaGrammar.getNonOverlappingMatches(GRAMMAR, memoTable);
        //        if (topLevelMatches.isEmpty()) {
        //            throw new IllegalArgumentException("Toplevel rule \"" + GRAMMAR + "\" did not match");
        //        } else if (topLevelMatches.size() > 1) {
        //            System.out.println("\nMultiple toplevel matches:");
        //            for (var topLevelMatch : topLevelMatches) {
        //                var topLevelASTNode = new ASTNode(topLevelMatch, input);
        //                System.out.println(topLevelASTNode);
        //            }
        //            throw new IllegalArgumentException("Stopping");
        //        }

        var topLevelASTNode = new ASTNode(topMatch, input);

        // System.out.println(topLevelASTNode.toStringWholeTree());

        // Convert from grammar description AST to precedence-associativity rules
        var prevAssocRules = new ArrayList<PrecAssocRule>();
        for (ASTNode astNode : topLevelASTNode.children) {
            if (!astNode.label.equals(RULE_AST)) {
                throw new IllegalArgumentException("Wrong node type");
            }
            var rule = parseRule(astNode);
            prevAssocRules.add(rule);
        }

        // Rewrite from precedence-associativity form into raw PEG rules
        var rules = PrecAssocRuleRewriter.rewrite(prevAssocRules);

        return new Grammar(rules);
    }
}
