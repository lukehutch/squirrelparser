"""MetaGrammar - A grammar for defining PEG grammars.

Syntax:
- Rule: IDENT <- EXPR ;
- Sequence: EXPR EXPR
- Choice: EXPR / EXPR
- ZeroOrMore: EXPR*
- OneOrMore: EXPR+
- Optional: EXPR?
- Positive lookahead: &EXPR
- Negative lookahead: !EXPR
- String literal: "text" or 'char'
- Character class: [a-z] or [^a-z]
- Any character: .
- Grouping: (EXPR)
"""

from __future__ import annotations
from typing import TYPE_CHECKING

from .squirrel_parse import squirrel_parse
from .ast_node import ASTNode
from .terminals import Str, Char, CharRange, AnyChar
from .combinators import Seq, First, OneOrMore, ZeroOrMore, Optional, NotFollowedBy, FollowedBy, Ref

if TYPE_CHECKING:
    from .clause import Clause


class MetaGrammar:
    """MetaGrammar - A grammar for defining PEG grammars."""

    # The meta-grammar rules for parsing PEG grammars.
    rules: dict[str, Clause] = {
        'Grammar': Seq(
            Ref('_'),
            OneOrMore(Ref('Rule')),
            Ref('_'),
        ),
        'Rule': Seq(
            Optional(Str('~')),
            Ref('Identifier'),
            Ref('_'),
            Str('<-'),
            Ref('_'),
            Ref('Expression'),
            Ref('_'),
            Str(';'),
            Ref('_'),
        ),
        'Expression': Ref('Choice'),
        'Choice': Seq(
            Ref('Sequence'),
            ZeroOrMore(Seq(
                Ref('_'),
                Str('/'),
                Ref('_'),
                Ref('Sequence'),
            )),
        ),
        'Sequence': Seq(
            Ref('Prefix'),
            ZeroOrMore(Seq(
                Ref('_'),
                Ref('Prefix'),
            )),
        ),
        'Prefix': First(
            Seq(Str('&'), Ref('_'), Ref('Prefix')),
            Seq(Str('!'), Ref('_'), Ref('Prefix')),
            Seq(Str('~'), Ref('_'), Ref('Prefix')),
            Ref('Suffix'),
        ),
        'Suffix': First(
            Seq(Ref('Suffix'), Ref('_'), Str('*')),
            Seq(Ref('Suffix'), Ref('_'), Str('+')),
            Seq(Ref('Suffix'), Ref('_'), Str('?')),
            Ref('Primary'),
        ),
        'Primary': First(
            Ref('Identifier'),
            Ref('StringLiteral'),
            Ref('CharLiteral'),
            Ref('CharClass'),
            Ref('AnyChar'),
            Seq(Str('('), Ref('_'), Ref('Expression'), Ref('_'), Str(')')),
        ),
        'Identifier': Seq(
            First(
                CharRange('a', 'z'),
                CharRange('A', 'Z'),
                Char('_'),
            ),
            ZeroOrMore(First(
                CharRange('a', 'z'),
                CharRange('A', 'Z'),
                CharRange('0', '9'),
                Char('_'),
            )),
        ),
        'StringLiteral': Seq(
            Str('"'),
            ZeroOrMore(First(
                Ref('EscapeSequence'),
                Seq(
                    NotFollowedBy(First(Str('"'), Str('\\'))),
                    AnyChar(),
                ),
            )),
            Str('"'),
        ),
        'CharLiteral': Seq(
            Str("'"),
            First(
                Ref('EscapeSequence'),
                Seq(
                    NotFollowedBy(First(Str("'"), Str('\\'))),
                    AnyChar(),
                ),
            ),
            Str("'"),
        ),
        'EscapeSequence': Seq(
            Str('\\'),
            First(
                Char('n'),
                Char('r'),
                Char('t'),
                Char('\\'),
                Char('"'),
                Char("'"),
            ),
        ),
        'CharClass': Seq(
            Str('['),
            Optional(Str('^')),
            OneOrMore(First(
                Ref('CharRange'),
                Ref('CharClassChar'),
            )),
            Str(']'),
        ),
        'CharRange': Seq(
            Ref('CharClassChar'),
            Str('-'),
            Ref('CharClassChar'),
        ),
        'CharClassChar': First(
            Seq(Str('\\'), AnyChar()),  # Any escaped character
            Seq(
                NotFollowedBy(First(Str(']'), Str('\\'), Str('-'))),
                AnyChar(),
            ),
        ),
        'AnyChar': Str('.'),
        '_': ZeroOrMore(First(
            Char(' '),
            Char('\t'),
            Char('\n'),
            Char('\r'),
            Ref('Comment'),
        )),
        'Comment': Seq(
            Str('#'),
            ZeroOrMore(Seq(
                NotFollowedBy(Char('\n')),
                AnyChar(),
            )),
            Optional(Char('\n')),
        ),
    }

    @staticmethod
    def parse_grammar(grammar_text: str) -> dict[str, Clause]:
        """Parse a grammar specification and return the rules."""
        ast, syntax_errors = squirrel_parse(MetaGrammar.rules, 'Grammar', grammar_text)

        if syntax_errors:
            error_msgs = '\n'.join(str(e) for e in syntax_errors)
            raise ValueError(
                f'Failed to parse grammar. Syntax errors:\n{error_msgs}'
            )

        return MetaGrammar._build_grammar_rules(ast, grammar_text)

    @staticmethod
    def _build_grammar_rules(ast: ASTNode, input_str: str) -> dict[str, Clause]:
        """Build grammar rules from the AST."""
        result: dict[str, Clause] = {}
        transparent_rules: set[str] = set()

        for rule_node in ast.children:
            if rule_node.label != 'Rule':
                continue

            # Get rule name (first Identifier child)
            rule_name_node = next(c for c in rule_node.children if c.label == 'Identifier')
            rule_name = rule_name_node.text

            # Get rule body (first Expression child)
            rule_body = next(c for c in rule_node.children if c.label == 'Expression')

            # Check for transparent marker (first child is Str with text '~')
            has_transparent_marker = any(
                c.label == 'Str' and c.text == '~' for c in rule_node.children
            )

            if has_transparent_marker:
                transparent_rules.add(rule_name)

            result[rule_name] = MetaGrammar._build_clause(
                rule_body, input_str, transparent_rules=transparent_rules
            )

        return result

    @staticmethod
    def _build_clause(
        node: ASTNode,
        input_str: str,
        transparent: bool = False,
        transparent_rules: set[str] | None = None
    ) -> Clause:
        """Build a Clause from an AST node."""
        if transparent_rules is None:
            transparent_rules = set()

        # Skip whitespace and other non-semantic nodes
        if MetaGrammar._should_skip_node(node.label):
            # If this node has children, try to build from them
            if node.children:
                semantic_children = [
                    c for c in node.children
                    if not MetaGrammar._should_skip_node(c.label)
                ]
                if len(semantic_children) == 1:
                    return MetaGrammar._build_clause(
                        semantic_children[0], input_str,
                        transparent=transparent,
                        transparent_rules=transparent_rules
                    )
            raise ValueError(f'Cannot build clause from: {node.label}')

        # For nodes that are wrappers/intermediate nodes, recurse into their children
        if MetaGrammar._is_wrapper_node(node.label):
            # For wrapper nodes, filter out whitespace and other non-semantic nodes
            semantic_children = [
                c for c in node.children
                if not MetaGrammar._should_skip_node(c.label)
            ]
            if not semantic_children:
                raise ValueError(f'Wrapper node {node.label} has no semantic children')
            if len(semantic_children) == 1:
                return MetaGrammar._build_clause(
                    semantic_children[0], input_str,
                    transparent=transparent,
                    transparent_rules=transparent_rules
                )
            # Multiple children - treat as sequence
            return Seq(
                *[MetaGrammar._build_clause(c, input_str, transparent_rules=transparent_rules)
                  for c in semantic_children],
                transparent=transparent
            )

        if node.label == 'Prefix':
            # Check if there's a prefix operator (&, !, ~)
            operator_node = next((c for c in node.children if c.label == 'Str'), None)
            # Prefix can contain either another Prefix (for stacking) or a Suffix
            child_node = next((c for c in node.children if c.label in ('Prefix', 'Suffix')), None)

            if child_node is None:
                raise ValueError('Prefix node has no Prefix/Suffix child')

            child_clause = MetaGrammar._build_clause(
                child_node, input_str, transparent_rules=transparent_rules
            )

            if operator_node is None:
                # No prefix operator, just return the child
                return child_clause

            if operator_node.text == '&':
                return FollowedBy(child_clause)
            elif operator_node.text == '!':
                return NotFollowedBy(child_clause)
            elif operator_node.text == '~':
                # Transparent marker - return child with transparent flag
                return MetaGrammar._build_clause(
                    child_node, input_str,
                    transparent=True,
                    transparent_rules=transparent_rules
                )
            else:
                raise ValueError(f'Unknown prefix operator: {operator_node.text}')

        elif node.label == 'Suffix':
            # Check if there's a suffix operator (*, +, ?)
            operator_node = next((c for c in node.children if c.label == 'Str'), None)
            # Suffix can contain either another Suffix (for stacking) or a Primary
            child_node = next((c for c in node.children if c.label in ('Suffix', 'Primary')), None)

            if child_node is None:
                raise ValueError('Suffix node has no Suffix/Primary child')

            child_clause = MetaGrammar._build_clause(
                child_node, input_str, transparent_rules=transparent_rules
            )

            if operator_node is None:
                # No suffix operator, just return the child
                return child_clause

            if operator_node.text == '*':
                return ZeroOrMore(child_clause, transparent=transparent)
            elif operator_node.text == '+':
                return OneOrMore(child_clause, transparent=transparent)
            elif operator_node.text == '?':
                return Optional(child_clause, transparent=transparent)
            else:
                raise ValueError(f'Unknown suffix operator: {operator_node.text}')

        elif node.label == 'Choice':
            semantic_children = [
                c for c in node.children
                if not MetaGrammar._should_skip_node(c.label)
            ]
            sequences = [
                MetaGrammar._build_clause(child, input_str, transparent_rules=transparent_rules)
                for child in semantic_children
            ]
            return sequences[0] if len(sequences) == 1 else First(*sequences, transparent=transparent)

        elif node.label == 'Sequence':
            semantic_children = [
                c for c in node.children
                if not MetaGrammar._should_skip_node(c.label)
            ]
            items = [
                MetaGrammar._build_clause(child, input_str, transparent_rules=transparent_rules)
                for child in semantic_children
            ]
            return items[0] if len(items) == 1 else Seq(*items, transparent=transparent)

        elif node.label == 'And':
            return FollowedBy(
                MetaGrammar._build_clause(node.children[0], input_str, transparent_rules=transparent_rules)
            )

        elif node.label == 'Not':
            return NotFollowedBy(
                MetaGrammar._build_clause(node.children[0], input_str, transparent_rules=transparent_rules)
            )

        elif node.label == 'Transparent':
            # Mark the child clause as transparent
            return MetaGrammar._build_clause(
                node.children[0], input_str,
                transparent=True,
                transparent_rules=transparent_rules
            )

        elif node.label == 'ZeroOrMore':
            return ZeroOrMore(
                MetaGrammar._build_clause(node.children[0], input_str, transparent_rules=transparent_rules),
                transparent=transparent
            )

        elif node.label == 'OneOrMore':
            return OneOrMore(
                MetaGrammar._build_clause(node.children[0], input_str, transparent_rules=transparent_rules),
                transparent=transparent
            )

        elif node.label == 'Optional':
            return Optional(
                MetaGrammar._build_clause(node.children[0], input_str, transparent_rules=transparent_rules),
                transparent=transparent
            )

        elif node.label == 'Identifier':
            # This is a rule reference - check if the referenced rule is transparent
            is_ref_transparent = transparent or node.text in transparent_rules
            return Ref(node.text, transparent=is_ref_transparent)

        elif node.label == 'StringLiteral':
            return Str(MetaGrammar._unescape_string(node.text[1:-1]))

        elif node.label == 'CharLiteral':
            return Char(MetaGrammar._unescape_char(node.text[1:-1]))

        elif node.label == 'CharClass':
            return MetaGrammar._build_char_class(node, input_str)

        elif node.label == 'AnyChar':
            return AnyChar()

        elif node.label == 'Group':
            return MetaGrammar._build_clause(
                node.children[0], input_str,
                transparent=transparent,
                transparent_rules=transparent_rules
            )

        else:
            # For unlabeled nodes, recursively build their children
            if not node.children:
                raise ValueError(f'Cannot build clause from: {node.label}')
            if len(node.children) == 1:
                return MetaGrammar._build_clause(
                    node.children[0], input_str,
                    transparent=transparent,
                    transparent_rules=transparent_rules
                )
            return Seq(*[
                MetaGrammar._build_clause(child, input_str, transparent_rules=transparent_rules)
                for child in node.children
            ])

    @staticmethod
    def _build_char_class(node: ASTNode, input_str: str) -> Clause:
        """Build a character class clause."""
        # Check if there's a "^" character indicating negation
        negated = any(c.label == 'Str' and c.text == '^' for c in node.children)
        items: list[Clause] = []

        for child in node.children:
            if child.label == 'CharRange':
                # CharRange has two CharClassChar children (and a Str: "-" in between)
                char_class_chars = [c for c in child.children if c.label == 'CharClassChar']
                if len(char_class_chars) != 2:
                    raise ValueError('CharRange must have exactly 2 CharClassChar children')
                lo = MetaGrammar._unescape_char(char_class_chars[0].text)
                hi = MetaGrammar._unescape_char(char_class_chars[1].text)
                items.append(CharRange(lo, hi))
            elif child.label == 'CharClassChar':
                ch = MetaGrammar._unescape_char(child.text)
                items.append(Char(ch))

        clause = items[0] if len(items) == 1 else First(*items)
        # Negated character class: ![class] . (not in class, then consume any char)
        return Seq(NotFollowedBy(clause), AnyChar()) if negated else clause

    @staticmethod
    def _unescape_string(s: str) -> str:
        """Unescape a string literal."""
        return (s
                .replace('\\n', '\n')
                .replace('\\r', '\r')
                .replace('\\t', '\t')
                .replace('\\\\', '\\')
                .replace('\\"', '"')
                .replace("\\'", "'"))

    @staticmethod
    def _unescape_char(s: str) -> str:
        """Unescape a character literal."""
        if len(s) == 1:
            return s
        if s.startswith('\\'):
            if len(s) > 1:
                if s[1] == 'n':
                    return '\n'
                elif s[1] == 'r':
                    return '\r'
                elif s[1] == 't':
                    return '\t'
                elif s[1] == '\\':
                    return '\\'
                elif s[1] == '"':
                    return '"'
                elif s[1] == "'":
                    return "'"
                else:
                    return s[1]
        return s

    @staticmethod
    def _should_skip_node(label: str) -> bool:
        """Check if a node should be skipped when building clauses."""
        return label in ('_', 'Whitespace', 'Comment', 'Str', 'Char', 'CharRange')

    @staticmethod
    def _is_wrapper_node(label: str) -> bool:
        """Check if a node is a wrapper/intermediate grammatical node."""
        return label in ('Expression', 'RuleBody', 'Primary', 'Group')
