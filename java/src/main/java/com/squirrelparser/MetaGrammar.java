package com.squirrelparser;

import static com.squirrelparser.Utils.unescapeChar;
import static com.squirrelparser.Utils.unescapeString;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * MetaGrammar: A grammar for defining PEG grammars.
 */
public final class MetaGrammar {
    private static final String TERMINAL_LABEL = "<Terminal>";

    /** The meta-grammar rules for parsing PEG grammars. */
    public static final Map<String, Clause> RULES;

    static {
        RULES = new HashMap<>();
        RULES.put("Grammar", new Seq(List.of(
            new Ref("WS"),
            new OneOrMore(new Seq(List.of(
                new Ref("Rule"),
                new Ref("WS")
            )))
        )));
        RULES.put("Rule", new Seq(List.of(
            new Optional(new Str("~")),
            new Ref("Identifier"),
            new Ref("WS"),
            new Str("<-"),
            new Ref("WS"),
            new Ref("Expression"),
            new Ref("WS"),
            new Str(";"),
            new Ref("WS")
        )));
        RULES.put("Expression", new Ref("Choice"));
        RULES.put("Choice", new Seq(List.of(
            new Ref("Sequence"),
            new ZeroOrMore(new Seq(List.of(
                new Ref("WS"),
                new Str("/"),
                new Ref("WS"),
                new Ref("Sequence")
            )))
        )));
        RULES.put("Sequence", new Seq(List.of(
            new Ref("Prefix"),
            new ZeroOrMore(new Seq(List.of(
                new Ref("WS"),
                new Ref("Prefix")
            )))
        )));
        RULES.put("Prefix", new First(List.of(
            new Seq(List.of(new Str("&"), new Ref("WS"), new Ref("Prefix"))),
            new Seq(List.of(new Str("!"), new Ref("WS"), new Ref("Prefix"))),
            new Seq(List.of(new Str("~"), new Ref("WS"), new Ref("Prefix"))),
            new Ref("Suffix")
        )));
        RULES.put("Suffix", new First(List.of(
            new Seq(List.of(new Ref("Suffix"), new Ref("WS"), new Str("*"))),
            new Seq(List.of(new Ref("Suffix"), new Ref("WS"), new Str("+"))),
            new Seq(List.of(new Ref("Suffix"), new Ref("WS"), new Str("?"))),
            new Ref("Primary")
        )));
        RULES.put("Primary", new First(List.of(
            new Ref("Identifier"),
            new Ref("StringLiteral"),
            new Ref("CharLiteral"),
            new Ref("CharClass"),
            new Ref("AnyChar"),
            new Ref("Parens")
        )));
        RULES.put("Parens", new Seq(List.of(
            new Str("("),
            new Ref("WS"),
            new Optional(new Ref("Expression")),
            new Ref("WS"),
            new Str(")")
        )));
        RULES.put("Identifier", new Seq(List.of(
            new First(List.of(
                CharSet.range("a", "z"),
                CharSet.range("A", "Z"),
                new Char("_")
            )),
            new ZeroOrMore(new First(List.of(
                CharSet.range("a", "z"),
                CharSet.range("A", "Z"),
                CharSet.range("0", "9"),
                new Char("_")
            )))
        )));
        RULES.put("StringLiteral", new Seq(List.of(
            new Str("\""),
            new ZeroOrMore(new First(List.of(
                new Ref("EscapeSequence"),
                new Seq(List.of(
                    new NotFollowedBy(new First(List.of(new Str("\""), new Str("\\")))),
                    new AnyChar()
                ))
            ))),
            new Str("\"")
        )));
        RULES.put("CharLiteral", new Seq(List.of(
            new Str("'"),
            new First(List.of(
                new Ref("EscapeSequence"),
                new Seq(List.of(
                    new NotFollowedBy(new First(List.of(new Str("'"), new Str("\\")))),
                    new AnyChar()
                ))
            )),
            new Str("'")
        )));
        RULES.put("EscapeSequence", new Seq(List.of(
            new Str("\\"),
            new First(List.of(
                new Char("n"),
                new Char("r"),
                new Char("t"),
                new Char("\\"),
                new Char("\""),
                new Char("'"),
                new Char("["),
                new Char("]"),
                new Char("-")
            ))
        )));
        RULES.put("CharClass", new Seq(List.of(
            new Str("["),
            new Optional(new Str("^")),
            new OneOrMore(new First(List.of(
                new Ref("CharRange"),
                new Ref("CharClassChar")
            ))),
            new Str("]")
        )));
        RULES.put("CharRange", new Seq(List.of(
            new Ref("CharClassChar"),
            new Str("-"),
            new Ref("CharClassChar")
        )));
        RULES.put("CharClassChar", new First(List.of(
            new Ref("EscapeSequence"),
            new Seq(List.of(
                new NotFollowedBy(new First(List.of(new Str("]"), new Str("\\"), new Str("-")))),
                new AnyChar()
            ))
        )));
        RULES.put("AnyChar", new Str("."));
        RULES.put("~WS", new ZeroOrMore(new First(List.of(
            new Char(" "),
            new Char("\t"),
            new Char("\n"),
            new Char("\r"),
            new Ref("Comment")
        ))));
        RULES.put("Comment", new Seq(List.of(
            new Str("#"),
            new ZeroOrMore(new Seq(List.of(
                new NotFollowedBy(new Char("\n")),
                new AnyChar()
            ))),
            new Optional(new Char("\n"))
        )));
    }

    /**
     * Parse a grammar specification and return the rules.
     */
    public static Map<String, Clause> parseGrammar(String grammarSpec) {
        var parser = new Parser(RULES, "Grammar", grammarSpec);
        var parseResult = parser.parse();
        if (parseResult.hasSyntaxErrors()) {
            var errors = parseResult.getSyntaxErrors().stream()
                .map(Object::toString)
                .toList();
            throw new IllegalArgumentException("Failed to parse grammar. Syntax errors:\n" +
                String.join("\n", errors));
        }

        var ast = ASTBuilder.buildAST(parseResult);
        var grammarMap = new HashMap<String, Clause>();

        for (var ruleNode : ast.children()) {
            if (!ruleNode.label().equals("Rule")) {
                continue;
            }

            ASTNode identifierNode = null;
            for (var child : ruleNode.children()) {
                if (child.label().equals("Identifier")) {
                    identifierNode = child;
                    break;
                }
            }
            if (identifierNode == null) {
                throw new IllegalArgumentException("Rule has no Identifier child");
            }
            String ruleName = identifierNode.getInputSpan(grammarSpec);

            ASTNode expressionNode = null;
            for (var child : ruleNode.children()) {
                if (child.label().equals("Expression")) {
                    expressionNode = child;
                    break;
                }
            }
            if (expressionNode == null) {
                throw new IllegalArgumentException("Rule has no Expression child");
            }

            boolean isTransparent = false;
            for (var child : ruleNode.children()) {
                if (child.label().equals(TERMINAL_LABEL) && child.getInputSpan(grammarSpec).equals("~")) {
                    isTransparent = true;
                    break;
                }
                if (child.label().equals("Identifier")) {
                    break;
                }
            }

            Clause clause = buildClause(expressionNode, grammarSpec);

            if (isTransparent) {
                grammarMap.put("~" + ruleName, clause);
            } else {
                grammarMap.put(ruleName, clause);
            }
        }

        // Validate rules
        for (var key : grammarMap.keySet()) {
            if (key.startsWith("~") && grammarMap.containsKey(key.substring(1)) ||
                !key.startsWith("~") && grammarMap.containsKey("~" + key)) {
                throw new IllegalArgumentException("Rule \"" + key + "\" cannot be both transparent and non-transparent");
            }
        }
        for (var clause : grammarMap.values()) {
            clause.checkRuleRefs(grammarMap);
        }

        return grammarMap;
    }

    private static Clause buildClause(ASTNode node, String input) {
        switch (node.label()) {
            case "Expression" -> {
                if (node.children().size() == 1) {
                    return buildClause(node.children().getFirst(), input);
                }
                throw new IllegalArgumentException("Expression should have exactly one child, got " + node.children().size());
            }
            case "Choice" -> {
                var sequences = node.children().stream()
                    .filter(c -> c.label().equals("Sequence"))
                    .map(c -> buildClause(c, input))
                    .toList();
                if (sequences.isEmpty()) {
                    throw new IllegalArgumentException("Choice has no Sequence children");
                }
                return sequences.size() == 1 ? sequences.getFirst() : new First(sequences);
            }
            case "Sequence" -> {
                var prefixes = node.children().stream()
                    .filter(c -> c.label().equals("Prefix"))
                    .map(c -> buildClause(c, input))
                    .toList();
                if (prefixes.isEmpty()) {
                    throw new IllegalArgumentException("Sequence has no Prefix children");
                }
                return prefixes.size() == 1 ? prefixes.getFirst() : new Seq(prefixes);
            }
            case "Prefix" -> {
                String prefixOp = null;
                for (var child : node.children()) {
                    if (child.label().equals(TERMINAL_LABEL)) {
                        String text = child.getInputSpan(input);
                        if (text.equals("&") || text.equals("!") || text.equals("~")) {
                            prefixOp = text;
                            break;
                        }
                    }
                }

                ASTNode operand = null;
                for (var child : node.children()) {
                    if (child.label().equals("Prefix") || child.label().equals("Suffix")) {
                        operand = child;
                        break;
                    }
                }
                if (operand == null) {
                    throw new IllegalArgumentException("Prefix has no Prefix/Suffix child");
                }
                Clause operandClause = buildClause(operand, input);

                return switch (prefixOp) {
                    case "&" -> new FollowedBy(operandClause);
                    case "!" -> new NotFollowedBy(operandClause);
                    case "~" -> operandClause;
                    case null -> operandClause;
                    default -> operandClause;
                };
            }
            case "Suffix" -> {
                String suffixOp = null;
                for (var child : node.children()) {
                    if (child.label().equals(TERMINAL_LABEL)) {
                        String text = child.getInputSpan(input);
                        if (text.equals("*") || text.equals("+") || text.equals("?")) {
                            suffixOp = text;
                            break;
                        }
                    }
                }

                ASTNode operand = null;
                for (var child : node.children()) {
                    if (child.label().equals("Suffix") || child.label().equals("Primary")) {
                        operand = child;
                        break;
                    }
                }
                if (operand == null) {
                    throw new IllegalArgumentException("Suffix has no Suffix/Primary child");
                }
                Clause operandClause = buildClause(operand, input);

                return switch (suffixOp) {
                    case "*" -> new ZeroOrMore(operandClause);
                    case "+" -> new OneOrMore(operandClause);
                    case "?" -> new Optional(operandClause);
                    case null -> operandClause;
                    default -> operandClause;
                };
            }
            case "Primary" -> {
                for (var child : node.children()) {
                    if (!child.label().equals(TERMINAL_LABEL)) {
                        return buildClause(child, input);
                    }
                }
                throw new IllegalArgumentException("Primary has no semantic child");
            }
            case "Parens" -> {
                for (var child : node.children()) {
                    if (child.label().equals("Expression")) {
                        return buildClause(child, input);
                    }
                }
                return new Nothing();
            }
            case "Identifier" -> {
                return new Ref(node.getInputSpan(input));
            }
            case "StringLiteral" -> {
                String text = node.getInputSpan(input);
                return new Str(unescapeString(text.substring(1, text.length() - 1)));
            }
            case "CharLiteral" -> {
                String text = node.getInputSpan(input);
                return new Char(unescapeChar(text.substring(1, text.length() - 1)));
            }
            case "CharClass" -> {
                return buildCharClass(node, input);
            }
            case "AnyChar" -> {
                return new AnyChar();
            }
            default -> throw new IllegalArgumentException("Unknown AST node label: " + node.label());
        }
    }

    private static Clause buildCharClass(ASTNode node, String input) {
        boolean negated = false;
        for (var child : node.children()) {
            if (child.label().equals(TERMINAL_LABEL) && child.getInputSpan(input).equals("^")) {
                negated = true;
                break;
            }
        }

        List<int[]> ranges = new ArrayList<>();
        for (var child : node.children()) {
            if (child.label().equals("CharRange")) {
                var charClassChars = child.children().stream()
                    .filter(c -> c.label().equals("CharClassChar"))
                    .toList();
                if (charClassChars.size() != 2) {
                    throw new IllegalArgumentException("CharRange must have exactly 2 CharClassChar children");
                }
                String lo = extractCharClassCharValue(charClassChars.get(0), input);
                String hi = extractCharClassCharValue(charClassChars.get(1), input);
                ranges.add(new int[]{lo.codePointAt(0), hi.codePointAt(0)});
            } else if (child.label().equals("CharClassChar")) {
                String ch = extractCharClassCharValue(child, input);
                int cp = ch.codePointAt(0);
                ranges.add(new int[]{cp, cp});
            }
        }

        if (ranges.isEmpty()) {
            throw new IllegalArgumentException("CharClass has no character items");
        }

        return new CharSet(ranges, negated);
    }

    private static String extractCharClassCharValue(ASTNode node, String input) {
        for (var child : node.children()) {
            if (child.label().equals("EscapeSequence")) {
                return unescapeChar(child.getInputSpan(input));
            }
        }
        return unescapeChar(node.getInputSpan(input));
    }
}
