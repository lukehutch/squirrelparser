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

import static java.util.Map.entry;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.BitSet;
import java.util.List;
import java.util.Map;

import squirrelparser.grammar.Grammar;
import squirrelparser.grammar.clause.Clause;
import squirrelparser.grammar.clause.nonterminal.First;
import squirrelparser.grammar.clause.nonterminal.FollowedBy;
import squirrelparser.grammar.clause.nonterminal.Longest;
import squirrelparser.grammar.clause.nonterminal.NotFollowedBy;
import squirrelparser.grammar.clause.nonterminal.OneOrMore;
import squirrelparser.grammar.clause.nonterminal.Optional;
import squirrelparser.grammar.clause.nonterminal.RuleRef;
import squirrelparser.grammar.clause.nonterminal.Seq;
import squirrelparser.grammar.clause.nonterminal.ZeroOrMore;
import squirrelparser.grammar.clause.terminal.AnyChar;
import squirrelparser.grammar.clause.terminal.Char;
import squirrelparser.grammar.clause.terminal.CharRange;
import squirrelparser.grammar.clause.terminal.CharSeq;
import squirrelparser.grammar.clause.terminal.CharSet;
import squirrelparser.grammar.clause.terminal.Collect;
import squirrelparser.grammar.clause.terminal.Nothing;
import squirrelparser.grammar.clause.terminal.Terminal;
import squirrelparser.grammar.clause.terminal.Whitespace;
import squirrelparser.node.ASTNode;
import squirrelparser.parser.Parser;

/**
 * A "meta-grammar" that produces a runtime parser generator, allowing a grammar to be defined using ASCII notation.
 */
public class MetaGrammar {

    public static String RULE_DECL_SYMBOL = "<-";

    public static String RULE_END_SYMBOL = ";";

    public static String LINE_COMMENT_PREFIX = "//";

    public static String BLOCK_COMMENT_PREFIX = "/*";

    public static String BLOCK_COMMENT_SUFFIX = "*/";

    public static String ANY_CHAR_SYMBOL = "_";

    public static char FIRST_SEPARATOR = '/';

    public static char LONGEST_SEPARATOR = '|';

    public static char COLLECT_START = '{';

    public static char COLLECT_END = '}';

    // -------------------------------------------------------------------------------------------------------------

    // Precedence levels (should correspond to levels in metagrammar):

    public static Map<Class<? extends Clause>, Integer> clauseTypeToPrecedence = //
            Map.ofEntries( //
                    entry(Terminal.class, 8), //
                    entry(RuleRef.class, 8), //
                    entry(OneOrMore.class, 7), //
                    entry(ZeroOrMore.class, 7), //
                    entry(NotFollowedBy.class, 6), //
                    entry(FollowedBy.class, 6), //
                    entry(Optional.class, 5), //
                    // astNodeLabel has precedence 4 (everything above this precedence level
                    // has only a single subclause, so no parentheses are necessary around
                    // a labeled clause)
                    entry(Seq.class, 3), //
                    entry(First.class, 2), //
                    entry(Longest.class, 1) //
            );

    public static final int AST_NODE_LABEL_PRECEDENCE = 4;

    // Rule names:

    private static final String GRAMMAR = "GRAMMAR";
    private static final String WSC = "WSC";
    private static final String LINE_COMMENT = "LINE_COMMENT";
    private static final String BLOCK_COMMENT = "BLOCK_COMMENT";
    private static final String WHITESPACE = "WHITESPACE";
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
    private static final String ANY = "ANY";

    // AST node names:

    private static final String RULE_AST = "Rule";
    private static final String PREC_AST = "Prec";
    private static final String R_ASSOC_AST = "RAssoc";
    private static final String L_ASSOC_AST = "LAssoc";
    private static final String IDENT_AST = "Ident";
    private static final String LABEL_AST = "Label";
    private static final String LABEL_NAME_AST = "LabelName";
    private static final String LABEL_CLAUSE_AST = "LabelClause";
    private static final String SEQ_AST = "Seq";
    private static final String FIRST_AST = "First";
    private static final String LONGEST_AST = "Longest";
    private static final String FOLLOWED_BY_AST = "FollowedBy";
    private static final String NOT_FOLLOWED_BY_AST = "NotFollowedBy";
    private static final String ONE_OR_MORE_AST = "OneOrMore";
    private static final String ZERO_OR_MORE_AST = "ZeroOrMore";
    private static final String OPTIONAL_AST = "Optional";
    private static final String SINGLE_QUOTED_CHAR_AST = "SingleQuotedChar";
    private static final String CHAR_RANGE_AST = "CharRange";
    private static final String QUOTED_STRING_AST = "QuotedString";
    private static final String NOTHING_AST = "Nothing";
    private static final String WHITESPACE_AST = "Whitespace";
    private static final String ANY_AST = "Any";
    private static final String COLLECT_AST = "Collect";

    /** Metagrammar. */
    public static Grammar metaGrammar() {
        return new Grammar(PrecAssocRuleRewriter.rewrite(Arrays.asList(//
                predAssocRule(GRAMMAR, //
                        seq(ruleRef(WSC), oneOrMore(ruleRef(RULE)))), //

                predAssocRule(RULE, //
                        ast(RULE_AST, seq(ruleRef(IDENT), ruleRef(WSC), //
                                optional(ruleRef(PREC)), //
                                str(RULE_DECL_SYMBOL), ruleRef(WSC), //
                                ruleRef(CLAUSE), ruleRef(WSC), str(RULE_END_SYMBOL), ruleRef(WSC)))), //

                // Define precedence order for clause sequences

                // Parens / Collect
                predAssocRule(CLAUSE, 9, /* associativity = */ null, //
                        first(seq(c('('), ruleRef(WSC), ruleRef(CLAUSE), ruleRef(WSC), c(')')), //
                                ast(COLLECT_AST,
                                        seq(c(COLLECT_START), ruleRef(WSC), ruleRef(CLAUSE), ruleRef(WSC),
                                                c(COLLECT_END))))), //

                // Terminals
                predAssocRule(CLAUSE, 8, /* associativity = */ null, //
                        first( //
                                ruleRef(ANY), //
                                ruleRef(IDENT), // RuleRef
                                ruleRef(WHITESPACE), //
                                ruleRef(QUOTED_STRING), //
                                ruleRef(CHAR_SET), //
                                ruleRef(NOTHING))), //

                // OneOrMore / ZeroOrMore
                predAssocRule(CLAUSE, 7, /* associativity = */ null, //
                        first( //
                                seq(ast(ONE_OR_MORE_AST, ruleRef(CLAUSE)), ruleRef(WSC), c('+')),
                                seq(ast(ZERO_OR_MORE_AST, ruleRef(CLAUSE)), ruleRef(WSC), c('*')))), //

                // FollowedBy / NotFollowedBy
                predAssocRule(CLAUSE, 6, /* associativity = */ null, //
                        first( //
                                seq(c('&'), ast(FOLLOWED_BY_AST, ruleRef(CLAUSE))), //
                                seq(c('!'), ast(NOT_FOLLOWED_BY_AST, ruleRef(CLAUSE))))), //

                // Optional
                predAssocRule(CLAUSE, 5, /* associativity = */ null, //
                        seq(ast(OPTIONAL_AST, ruleRef(CLAUSE)), ruleRef(WSC), c('?'))), //

                // ASTNodeLabel
                predAssocRule(CLAUSE, 4, /* associativity = */ null, //
                        ast(LABEL_AST,
                                seq(ast(LABEL_NAME_AST, ruleRef(IDENT)), ruleRef(WSC), c(':'), ruleRef(WSC),
                                        ast(LABEL_CLAUSE_AST, ruleRef(CLAUSE)), ruleRef(WSC)))), //

                // Seq
                predAssocRule(CLAUSE, 3, /* associativity = */ null, //
                        ast(SEQ_AST,
                                seq(ruleRef(CLAUSE), ruleRef(WSC), oneOrMore(seq(ruleRef(CLAUSE), ruleRef(WSC)))))),

                // First
                predAssocRule(CLAUSE, 2, /* associativity = */ null, //
                        ast(FIRST_AST, seq(ruleRef(CLAUSE), ruleRef(WSC), //
                                oneOrMore(seq(c(FIRST_SEPARATOR), ruleRef(WSC), ruleRef(CLAUSE), ruleRef(WSC)))))),

                // Longest
                predAssocRule(CLAUSE, 1, /* associativity = */ null, //
                        ast(LONGEST_AST, seq(ruleRef(CLAUSE), ruleRef(WSC), //
                                oneOrMore(
                                        seq(c(LONGEST_SEPARATOR), ruleRef(WSC), ruleRef(CLAUSE), ruleRef(WSC)))))),

                // A whitespace-matching terminal
                predAssocRule(WHITESPACE, //
                        ast(WHITESPACE_AST, str(Whitespace.WS_DISPLAY_STR))),

                // Whitespace or comment in the grammar description
                predAssocRule(WSC, //
                        zeroOrMore(
                                first(cSet(' ', '\n', '\r', '\t'), ruleRef(LINE_COMMENT), ruleRef(BLOCK_COMMENT)))),

                // Line comment
                predAssocRule(LINE_COMMENT, //
                        seq(str(LINE_COMMENT_PREFIX), zeroOrMore(cNot('\n')))),

                // Block comment
                predAssocRule(BLOCK_COMMENT, //
                        seq(str(BLOCK_COMMENT_PREFIX),
                                zeroOrMore(seq(notFollowedBy(str(BLOCK_COMMENT_SUFFIX)), any())))),

                // Identifier
                predAssocRule(IDENT, //
                        ast(IDENT_AST,
                                seq(ruleRef(NAME_CHAR), zeroOrMore(first(ruleRef(NAME_CHAR), cRange('0', '9')))))), //

                // Number
                predAssocRule(NUM, //
                        oneOrMore(cRange('0', '9'))), //

                // Name character
                predAssocRule(NAME_CHAR, //
                        first(cRange('a', 'z'), cRange('A', 'Z'), cSet('_', '-'))),

                // Precedence and optional associativity modifiers for rule name
                predAssocRule(PREC, //
                        seq(c('['), ruleRef(WSC), //
                                ast(PREC_AST, ruleRef(NUM)), ruleRef(WSC), //
                                optional(seq(c(','), ruleRef(WSC), //
                                        first(ast(R_ASSOC_AST, first(c('r'), c('R'))),
                                                ast(L_ASSOC_AST, first(c('l'), c('L')))),
                                        ruleRef(WSC))), //
                                c(']'), ruleRef(WSC))), //

                // Character set
                predAssocRule(CHAR_SET, //
                        first( //
                                seq(c('\''), ast(SINGLE_QUOTED_CHAR_AST, ruleRef(SINGLE_QUOTED_CHAR)), c('\'')), //
                                seq(c('['), //
                                        ast(CHAR_RANGE_AST, seq(optional(c('^')), //
                                                oneOrMore(first( //
                                                        ruleRef(CHAR_RANGE), //
                                                        ruleRef(CHAR_RANGE_CHAR))))),
                                        c(']')))), //

                // Single quoted character
                predAssocRule(SINGLE_QUOTED_CHAR, //
                        first( //
                                ruleRef(ESCAPED_CTRL_CHAR), //
                                cNot('\''))),

                // Char range
                predAssocRule(CHAR_RANGE, //
                        seq(ruleRef(CHAR_RANGE_CHAR), c('-'), ruleRef(CHAR_RANGE_CHAR))), //

                // Char range character
                predAssocRule(CHAR_RANGE_CHAR, //
                        first( //
                                cSet(true, '\\', ']'), //
                                ruleRef(ESCAPED_CTRL_CHAR), //
                                str("\\-"), //
                                str("\\\\"), //
                                str("\\]"), //
                                str("\\^"))),

                // Quoted string
                predAssocRule(QUOTED_STRING, //
                        seq(c('"'), ast(QUOTED_STRING_AST, zeroOrMore(ruleRef(STR_QUOTED_CHAR))), c('"'))), //

                // Character within quoted string
                predAssocRule(STR_QUOTED_CHAR, //
                        first( //
                                ruleRef(ESCAPED_CTRL_CHAR), //
                                cSet(true, '"', '\\') //
                        )), //

                // Hex digit
                predAssocRule(HEX, first(cRange('0', '9'), cRange('a', 'f'), cRange('A', 'F'))), //

                // Escaped control character
                predAssocRule(ESCAPED_CTRL_CHAR, //
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
                predAssocRule(NOTHING, //
                        ast(NOTHING_AST, seq(c('('), ruleRef(WSC), c(')')))), //

                // Match any character
                predAssocRule(ANY, //
                        ast(ANY_AST, str(ANY_CHAR_SYMBOL))) //
        )));
    }

    // -------------------------------------------------------------------------------------------------------------

    // Object construction methods for shorter notation:

    /** Construct a {@link PrecAssocRule}. */
    public static PrecAssocRule predAssocRule(String ruleName, Clause clause) {
        // Use -1 as precedence if rule group has only one precedence
        return predAssocRule(ruleName, -1, /* associativity = */ null, clause);
    }

    /** Construct a {@link PrecAssocRule} with the given precedence and associativity. */
    public static PrecAssocRule predAssocRule(String ruleName, int precedence, Associativity associativity,
            Clause clause) {
        var rule = new PrecAssocRule(ruleName, precedence, associativity, clause);
        return rule;
    }

    /** Assign a rule name to a {@link Clause} (which should be the toplevel clause of a rule). */
    public static Clause rule(String ruleName, Clause clause) {
        clause.ruleName = ruleName;
        return clause;
    }

    /** Set the AST node label of a clause, then return the clause. */
    public static Clause ast(String astNodeLabel, Clause clause) {
        clause.astNodeLabel = astNodeLabel;
        return clause;
    }

    /** Construct a {@link Seq} clause. */
    public static Clause seq(Clause... subClauses) {
        return new Seq(subClauses);
    }

    /** Construct a {@link OneOrMore} clause. */
    public static Clause oneOrMore(Clause subClause) {
        // It doesn't make sense to wrap these clause types in OneOrMore, but the OneOrMore should have
        // no effect if this does occur in the grammar, so remove it
        if (subClause instanceof OneOrMore || subClause instanceof Nothing || subClause instanceof FollowedBy
                || subClause instanceof NotFollowedBy) {
            return subClause;
        }
        return new OneOrMore(subClause);
    }

    /** Construct an {@link Optional} clause. */
    public static Clause optional(Clause subClause) {
        return new Optional(subClause);
    }

    /** Construct a {@link ZeroOrMore} clause. */
    public static Clause zeroOrMore(Clause subClause) {
        return new ZeroOrMore(subClause);
    }

    /** Construct a {@link First} clause. */
    public static Clause first(Clause... subClauses) {
        return new First(subClauses);
    }

    /** Construct a {@link Longest} clause. */
    public static Clause longest(Clause... subClauses) {
        return new Longest(subClauses);
    }

    /** Construct a {@link FollowedBy} clause. */
    public static Clause followedBy(Clause subClause) {
        if (subClause instanceof Nothing || subClause instanceof FollowedBy || subClause instanceof NotFollowedBy) {
            return subClause;
        }
        return new FollowedBy(subClause);
    }

    /** Construct a {@link NotFollowedBy} clause. */
    public static Clause notFollowedBy(Clause subClause) {
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
    public static Clause nothing() {
        return new Nothing();
    }

    /** Construct a {@link Whitespace} terminal. */
    public static Clause whitespace() {
        return new Whitespace();
    }

    /** Construct a terminal that matches a string token. */
    public static Clause str(String str) {
        if (str.length() == 1) {
            return c(str.charAt(0));
        } else {
            return new CharSeq(str);
        }
    }

    /** Construct a terminal that matches a single character. */
    public static Char c(char chr) {
        return new Char(chr);
    }

    /** Construct a terminal that matches anything but a single character. */
    public static Char cNot(char chr) {
        return new Char(chr, true);
    }

    /** Construct a terminal that matches one instance of any character given in the varargs param. */
    public static CharSet cSet(char... chrs) {
        return new CharSet(chrs);
    }

    /**
     * Construct a terminal that matches one instance of any character given in the varargs param, unless invert is
     * true, then the matching is inverted.
     */
    public static CharSet cSet(boolean invert, char... chrs) {
        return new CharSet(invert, chrs);
    }

    /** Construct a terminal that matches one instance of any character in a given string. */
    public static CharSet cInStr(String str) {
        return new CharSet(str.toCharArray());
    }

    /** Construct a terminal that matches a character range. */
    public static CharRange cRange(char minChar, char maxChar) {
        if (maxChar < minChar) {
            throw new IllegalArgumentException("maxChar < minChar");
        }
        return new CharRange(minChar, maxChar);
    }

    /**
     * Construct a terminal that matches a character range, specified using regexp notation without the square
     * brackets.
     */
    public static Clause cRange(String charRangeStr) {
        boolean invert = charRangeStr.startsWith("^");
        var charList = StringUtils.getCharRangeChars(invert ? charRangeStr.substring(1) : charRangeStr);
        var chars = new char[charList.size()];
        for (var i = 0; i < charList.size(); i++) {
            // Unescape \^, \-, \], \\
            chars[i] = charList.get(i).charAt(charList.get(i).length() == 2 ? 1 : 0);
        }

        if (chars.length == 1) {
            return new Char(chars[0], invert);
        } else if (chars.length == 3 && chars[1] == '-') {
            // Just one character range
            return new CharRange(chars[0], chars[2], invert);
        }

        var bs = new BitSet(128);
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
                bs.set(c0, cEnd0 + 1);
                i += 2;
            } else {
                bs.set(c0);
            }
        }
        return new CharSet(bs, invert);
    }

    /** Construct a new {@link RuleRef}. */
    public static Clause ruleRef(String ruleName) {
        return new RuleRef(ruleName);
    }

    /** Construct a new {@link AnyChar}. */
    public static Clause any() {
        return new AnyChar();
    }

    /** Construct a new {@link Collect}. */
    public static Clause collect(Clause terminalClauseTree) {
        return new Collect(terminalClauseTree);
    }

    // -------------------------------------------------------------------------------------------------------------

    /**
     * Expect just a single clause in the list of clauses, and return it, or throw an exception if the length of the
     * list of clauses is not 1.
     */
    private static Clause expectOne(List<Clause> clauses, ASTNode astNode) {
        if (clauses.size() != 1) {
            // TODO: improve error reporting
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
        case LONGEST_AST:
            clause = longest(parseASTNodes(astNode.children).toArray(new Clause[0]));
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
        case WHITESPACE_AST:
            clause = whitespace();
            break;
        case ANY_AST:
            clause = any();
            break;
        case COLLECT_AST:
            clause = collect(expectOne(parseASTNodes(astNode.children), astNode));
            break;
        default:
            throw new IllegalArgumentException("Unexpected grammar AST node label: " + astNode.label);
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
        return predAssocRule(ruleName, precedence, associativity, clause);
    }

    /** Parse a grammar description in an input string, returning a new {@link Grammar} object. */
    public static Grammar parse(String metaGrammarStr) {
        // Don't debug metagrammar parsing
        var oldDebug = Parser.DEBUG;
        Parser.DEBUG = false;
        // System.out.println(metaGrammar);

        var parser = new Parser(metaGrammar());
        var topMatch = parser.parse(metaGrammarStr);

        //		ParserInfo.printParseResult("GRAMMAR", memoTable, new String[] { "GRAMMAR", "RULE", "CLAUSE[1]" },
        //				/* showAllMatches = */ false);
        //
        //		System.out.println("\nParsed meta-grammar:");
        //		for (var clause : MetaGrammar.grammar.allClauses) {
        //			System.out.println("    " + clause.toStringWithRuleNames());
        //		}

        if (topMatch.len != metaGrammarStr.length()) {
            var syntaxErrLocation = MemoUtils.findMaxEndPos(parser);
            // TODO: smarter error handling
            throw new IllegalArgumentException(
                    "Failed to match all input -- matched " + topMatch.len + " characters; syntax error location: "
                            + syntaxErrLocation + "; input length: " + metaGrammarStr.length());
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

        var topLevelASTNode = new ASTNode(topMatch, metaGrammarStr);

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

        Parser.DEBUG = oldDebug;

        return new Grammar(rules);
    }
}
