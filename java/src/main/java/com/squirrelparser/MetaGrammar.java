package com.squirrelparser;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.FollowedBy;
import com.squirrelparser.Combinators.NotFollowedBy;
import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Combinators.ZeroOrMore;
import com.squirrelparser.Terminals.AnyChar;
import com.squirrelparser.Terminals.Char;
import com.squirrelparser.Terminals.CharRange;
import com.squirrelparser.Terminals.Str;

/**
 * MetaGrammar - A grammar for defining PEG grammars.
 *
 * <p>Syntax:
 * <ul>
 *   <li>Rule: IDENT <- EXPR ;
 *   <li>Sequence: EXPR EXPR
 *   <li>Choice: EXPR / EXPR
 *   <li>ZeroOrMore: EXPR*
 *   <li>OneOrMore: EXPR+
 *   <li>Optional: EXPR?
 *   <li>Positive lookahead: &EXPR
 *   <li>Negative lookahead: !EXPR
 *   <li>String literal: "text" or 'char'
 *   <li>Character class: [a-z] or [^a-z]
 *   <li>Any character: .
 *   <li>Grouping: (EXPR)
 * </ul>
 */
public class MetaGrammar {

    /**
     * The meta-grammar rules for parsing PEG grammars.
     */
    public static final Map<String, Clause> rules = Map.ofEntries(
        Map.entry("Grammar", new Seq(List.of(
            new Ref("_"),
            new OneOrMore(new Ref("Rule")),
            new Ref("_")
        ))),
        Map.entry("Rule", new Seq(List.of(
            new Combinators.Optional(new Str("~")),
            new Ref("Identifier"),
            new Ref("_"),
            new Str("<-"),
            new Ref("_"),
            new Ref("Expression"),
            new Ref("_"),
            new Str(";"),
            new Ref("_")
        ))),
        Map.entry("Expression", new Ref("Choice")),
        Map.entry("Choice", new Seq(List.of(
            new Ref("Sequence"),
            new ZeroOrMore(new Seq(List.of(
                new Ref("_"),
                new Str("/"),
                new Ref("_"),
                new Ref("Sequence")
            )))
        ))),
        // CRITICAL: The correct whitespace handling is here
        Map.entry("Sequence", new Seq(List.of(
            new Ref("Prefix"),
            new ZeroOrMore(new Seq(List.of(
                new Ref("_"),
                new Ref("Prefix")
            )))
        ))),
        Map.entry("Prefix", new First(List.of(
            new Seq(List.of(new Str("&"), new Ref("_"), new Ref("Prefix"))),
            new Seq(List.of(new Str("!"), new Ref("_"), new Ref("Prefix"))),
            new Seq(List.of(new Str("~"), new Ref("_"), new Ref("Prefix"))),
            new Ref("Suffix")
        ))),
        Map.entry("Suffix", new First(List.of(
            new Seq(List.of(new Ref("Suffix"), new Ref("_"), new Str("*"))),
            new Seq(List.of(new Ref("Suffix"), new Ref("_"), new Str("+"))),
            new Seq(List.of(new Ref("Suffix"), new Ref("_"), new Str("?"))),
            new Ref("Primary")
        ))),
        Map.entry("Primary", new First(List.of(
            new Ref("Identifier"),
            new Ref("StringLiteral"),
            new Ref("CharLiteral"),
            new Ref("CharClass"),
            new Ref("AnyChar"),
            new Seq(List.of(new Str("("), new Ref("_"), new Ref("Expression"), new Ref("_"), new Str(")")))
        ))),
        Map.entry("Identifier", new Seq(List.of(
            new First(List.of(
                new CharRange("a", "z"),
                new CharRange("A", "Z"),
                new Char("_")
            )),
            new ZeroOrMore(new First(List.of(
                new CharRange("a", "z"),
                new CharRange("A", "Z"),
                new CharRange("0", "9"),
                new Char("_")
            )))
        ))),
        Map.entry("StringLiteral", new Seq(List.of(
            new Str("\""),
            new ZeroOrMore(new First(List.of(
                new Ref("EscapeSequence"),
                new Seq(List.of(
                    new NotFollowedBy(new First(List.of(new Str("\""), new Str("\\")))),
                    new AnyChar()
                ))
            ))),
            new Str("\"")
        ))),
        Map.entry("CharLiteral", new Seq(List.of(
            new Str("'"),
            new First(List.of(
                new Ref("EscapeSequence"),
                new Seq(List.of(
                    new NotFollowedBy(new First(List.of(new Str("'"), new Str("\\")))),
                    new AnyChar()
                ))
            )),
            new Str("'")
        ))),
        Map.entry("EscapeSequence", new Seq(List.of(
            new Str("\\"),
            new First(List.of(
                new Char("n"),
                new Char("r"),
                new Char("t"),
                new Char("\\"),
                new Char("\""),
                new Char("'")
            ))
        ))),
        Map.entry("CharClass", new Seq(List.of(
            new Str("["),
            new Combinators.Optional(new Str("^")),
            new OneOrMore(new First(List.of(
                new Ref("CharRange"),
                new Ref("CharClassChar")
            ))),
            new Str("]")
        ))),
        Map.entry("CharRange", new Seq(List.of(
            new Ref("CharClassChar"),
            new Str("-"),
            new Ref("CharClassChar")
        ))),
        Map.entry("CharClassChar", new First(List.of(
            new Ref("EscapeSequence"),
            new Seq(List.of(
                new NotFollowedBy(new First(List.of(new Str("]"), new Str("\\"), new Str("-")))),
                new AnyChar()
            ))
        ))),
        Map.entry("AnyChar", new Str(".")),
        Map.entry("_", new ZeroOrMore(new First(List.of(
            new Char(" "),
            new Char("\t"),
            new Char("\n"),
            new Char("\r"),
            new Ref("Comment")
        )))),
        Map.entry("Comment", new Seq(List.of(
            new Str("#"),
            new ZeroOrMore(new Seq(List.of(
                new NotFollowedBy(new Char("\n")),
                new AnyChar()
            ))),
            new Combinators.Optional(new Char("\n"))
        )))
    );

    /**
     * Parse a grammar specification and return the rules.
     */
    public static Map<String, Clause> parseGrammar(String grammarText) {
        Parser.SquirrelParseResult result = Parser.squirrelParse(rules, "Grammar", grammarText);

        if (!result.syntaxErrors().isEmpty()) {
            String errorMessages = result.syntaxErrors().stream()
                .map(e -> e.toString())
                .collect(java.util.stream.Collectors.joining("\n"));
            throw new IllegalArgumentException("Failed to parse grammar. Syntax errors:\n" + errorMessages);
        }

        return buildGrammarRules(result.ast(), grammarText);
    }

    /**
     * Build grammar rules from the AST.
     */
    private static Map<String, Clause> buildGrammarRules(ASTNode ast, String input) {
        Map<String, Clause> result = new LinkedHashMap<>();
        Set<String> transparentRules = new HashSet<>();

        // First pass: collect all rules
        for (ASTNode ruleNode : ast.children) {
            if (!ruleNode.label.equals("Rule")) {
                continue;
            }

            // Get rule name (first Identifier child)
            ASTNode ruleNameNode = ruleNode.children.stream()
                .filter(c -> c.label.equals("Identifier"))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Rule node has no Identifier child"));
            String ruleName = ruleNameNode.text();

            // Get rule body (first Expression child)
            ASTNode ruleBody = ruleNode.children.stream()
                .filter(c -> c.label.equals("Expression"))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Rule node has no Expression child"));

            // Check for transparent marker (has a Str child with text '~')
            boolean hasTransparentMarker = ruleNode.children.stream()
                .anyMatch(c -> c.label.equals("Str") && c.text().equals("~"));

            if (hasTransparentMarker) {
                transparentRules.add(ruleName);
            }

            result.put(ruleName, buildClause(ruleBody, input, false, transparentRules));
        }

        return result;
    }

    /**
     * Build a Clause from an AST node.
     */
    private static Clause buildClause(ASTNode node, String input, boolean transparent, Set<String> transparentRules) {
        // Skip whitespace and other non-semantic nodes
        if (shouldSkipNode(node.label)) {
            // If this node has children, try to build from them
            if (!node.children.isEmpty()) {
                List<ASTNode> semanticChildren = node.children.stream()
                    .filter(c -> !shouldSkipNode(c.label))
                    .collect(Collectors.toList());
                if (semanticChildren.size() == 1) {
                    return buildClause(semanticChildren.get(0), input, transparent, transparentRules);
                }
            }
            throw new IllegalArgumentException("Cannot build clause from: " + node.label);
        }

        // For nodes that are wrappers/intermediate nodes, recurse into their children
        if (isWrapperNode(node.label)) {
            // For wrapper nodes, filter out whitespace and other non-semantic nodes
            List<ASTNode> semanticChildren = node.children.stream()
                .filter(c -> !shouldSkipNode(c.label))
                .collect(Collectors.toList());
            if (semanticChildren.isEmpty()) {
                throw new IllegalArgumentException("Wrapper node " + node.label + " has no semantic children");
            }
            if (semanticChildren.size() == 1) {
                return buildClause(semanticChildren.get(0), input, transparent, transparentRules);
            }
            // Multiple children - treat as sequence
            return new Seq(
                semanticChildren.stream()
                    .map(c -> buildClause(c, input, false, transparentRules))
                    .collect(Collectors.toList()),
                transparent
            );
        }

        return switch (node.label) {
            case "Prefix" -> {
                // Check if there's a prefix operator (&, !, ~)
                java.util.Optional<ASTNode> operatorNode = node.children.stream()
                    .filter(c -> c.label.equals("Str"))
                    .findFirst();
                // Prefix can contain either another Prefix (for stacking) or a Suffix
                java.util.Optional<ASTNode> childNodeOpt = node.children.stream()
                    .filter(c -> c.label.equals("Prefix") || c.label.equals("Suffix"))
                    .findFirst();

                if (childNodeOpt.isEmpty()) {
                    throw new IllegalArgumentException("Prefix node has no Prefix/Suffix child");
                }

                ASTNode childNode = childNodeOpt.get();
                Clause childClause = buildClause(childNode, input, false, transparentRules);

                if (operatorNode.isEmpty()) {
                    // No prefix operator, just return the child
                    yield childClause;
                }

                yield switch (operatorNode.get().text()) {
                    case "&" -> new FollowedBy(childClause);
                    case "!" -> new NotFollowedBy(childClause);
                    case "~" ->
                        // Transparent marker - return child with transparent flag
                        buildClause(childNode, input, true, transparentRules);
                    default -> throw new IllegalArgumentException("Unknown prefix operator: " + operatorNode.get().text());
                };
            }

            case "Suffix" -> {
                // Check if there's a suffix operator (*, +, ?)
                java.util.Optional<ASTNode> operatorNode = node.children.stream()
                    .filter(c -> c.label.equals("Str"))
                    .findFirst();
                // Suffix can contain either another Suffix (for stacking) or a Primary
                java.util.Optional<ASTNode> childNodeOpt = node.children.stream()
                    .filter(c -> c.label.equals("Suffix") || c.label.equals("Primary"))
                    .findFirst();

                if (childNodeOpt.isEmpty()) {
                    throw new IllegalArgumentException("Suffix node has no Suffix/Primary child");
                }

                ASTNode childNode = childNodeOpt.get();
                Clause childClause = buildClause(childNode, input, false, transparentRules);

                if (operatorNode.isEmpty()) {
                    // No suffix operator, just return the child
                    yield childClause;
                }

                yield switch (operatorNode.get().text()) {
                    case "*" -> new ZeroOrMore(childClause, transparent);
                    case "+" -> new OneOrMore(childClause, transparent);
                    case "?" -> new Combinators.Optional(childClause, transparent);
                    default -> throw new IllegalArgumentException("Unknown suffix operator: " + operatorNode.get().text());
                };
            }

            case "Choice" -> {
                List<ASTNode> semanticChildren = node.children.stream()
                    .filter(c -> !shouldSkipNode(c.label))
                    .collect(Collectors.toList());
                List<Clause> sequences = semanticChildren.stream()
                    .map(child -> buildClause(child, input, false, transparentRules))
                    .collect(Collectors.toList());
                yield sequences.size() == 1 ? sequences.get(0) : new First(sequences, transparent);
            }

            case "Sequence" -> {
                List<ASTNode> semanticChildren = node.children.stream()
                    .filter(c -> !shouldSkipNode(c.label))
                    .collect(Collectors.toList());
                List<Clause> items = semanticChildren.stream()
                    .map(child -> buildClause(child, input, false, transparentRules))
                    .collect(Collectors.toList());
                yield items.size() == 1 ? items.get(0) : new Seq(items, transparent);
            }

            case "Identifier" -> {
                // This is a rule reference - check if the referenced rule is transparent
                boolean isRefTransparent = transparent || transparentRules.contains(node.text());
                yield new Ref(node.text(), isRefTransparent);
            }

            case "StringLiteral" -> {
                String text = node.text();
                yield new Str(unescapeString(text.substring(1, text.length() - 1)));
            }

            case "CharLiteral" -> {
                String text = node.text();
                yield new Char(unescapeChar(text.substring(1, text.length() - 1)));
            }

            case "CharClass" -> buildCharClass(node, input);

            case "AnyChar" -> new AnyChar();

            default -> {
                // For unlabeled nodes, recursively build their children
                if (node.children.isEmpty()) {
                    throw new IllegalArgumentException("Cannot build clause from: " + node.label);
                }
                if (node.children.size() == 1) {
                    yield buildClause(node.children.get(0), input, transparent, transparentRules);
                }
                yield new Seq(node.children.stream()
                    .map(child -> buildClause(child, input, false, transparentRules))
                    .collect(Collectors.toList()));
            }
        };
    }

    /**
     * Build a character class clause.
     */
    private static Clause buildCharClass(ASTNode node, String input) {
        // Check if there's a "^" character indicating negation
        boolean negated = node.children.stream()
            .anyMatch(c -> c.label.equals("Str") && c.text().equals("^"));
        List<Clause> items = new ArrayList<>();

        for (ASTNode child : node.children) {
            if (child.label.equals("CharRange")) {
                // CharRange has two CharClassChar children (and a Str: "-" in between)
                List<ASTNode> charClassChars = child.children.stream()
                    .filter(c -> c.label.equals("CharClassChar"))
                    .collect(Collectors.toList());
                if (charClassChars.size() != 2) {
                    throw new IllegalArgumentException("CharRange must have exactly 2 CharClassChar children");
                }
                String lo = unescapeChar(charClassChars.get(0).text());
                String hi = unescapeChar(charClassChars.get(1).text());
                items.add(new CharRange(lo, hi));
            } else if (child.label.equals("CharClassChar")) {
                String ch = unescapeChar(child.text());
                items.add(new Char(ch));
            }
        }

        Clause clause = items.size() == 1 ? items.get(0) : new First(items);
        // Negated character class: ![class] . (not in class, then consume any char)
        return negated ? new Seq(List.of(new NotFollowedBy(clause), new AnyChar())) : clause;
    }

    /**
     * Unescape a string literal.
     */
    private static String unescapeString(String str) {
        return str.replace("\\n", "\n")
                  .replace("\\r", "\r")
                  .replace("\\t", "\t")
                  .replace("\\\\", "\\")
                  .replace("\\\"", "\"")
                  .replace("\\'", "'");
    }

    /**
     * Unescape a character literal.
     */
    private static String unescapeChar(String str) {
        if (str.length() == 1) {
            return str;
        }
        if (str.startsWith("\\") && str.length() == 2) {
            return switch (str.charAt(1)) {
                case 'n' -> "\n";
                case 'r' -> "\r";
                case 't' -> "\t";
                case '\\' -> "\\";
                case '"' -> "\"";
                case '\'' -> "'";
                default -> String.valueOf(str.charAt(1));
            };
        }
        return str;
    }

    /**
     * Check if a node should be skipped when building clauses.
     */
    private static boolean shouldSkipNode(String label) {
        return label.equals("_") ||           // Whitespace
               label.equals("Whitespace") ||  // Whitespace alternative name
               label.equals("Comment") ||     // Comments
               label.equals("Str") ||         // Terminal string match
               label.equals("Char") || // Terminal char match
               label.equals("CharRange");     // Terminal char range match
    }

    /**
     * Check if a node is a wrapper/intermediate grammatical node.
     */
    private static boolean isWrapperNode(String label) {
        return label.equals("Expression") ||
               label.equals("RuleBody") ||
               label.equals("Primary") ||
               label.equals("Group");
    }
}
