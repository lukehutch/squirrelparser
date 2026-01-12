"""MetaGrammar: A grammar for defining PEG grammars."""

from __future__ import annotations

from .clause import Clause
from .combinators import (
    First,
    FollowedBy,
    NotFollowedBy,
    OneOrMore,
    Optional,
    Ref,
    Seq,
    ZeroOrMore,
)
from .terminals import AnyChar, Char, CharSet, Nothing, Str
from .parser import Parser
from .cst_node import ASTNode, build_ast
from .utils import unescape_char, unescape_string

_TERMINAL_LABEL = '<Terminal>'


class MetaGrammar:
    """MetaGrammar: A grammar for defining PEG grammars."""

    # The meta-grammar rules for parsing PEG grammars.
    rules: dict[str, Clause] = {
        'Grammar': Seq([Ref('WS'), OneOrMore(Seq([Ref('Rule'), Ref('WS')]))]),
        'Rule': Seq([
            Optional(Str('~')),
            Ref('Identifier'),
            Ref('WS'),
            Str('<-'),
            Ref('WS'),
            Ref('Expression'),
            Ref('WS'),
            Str(';'),
            Ref('WS'),
        ]),
        'Expression': Ref('Choice'),
        'Choice': Seq([
            Ref('Sequence'),
            ZeroOrMore(Seq([Ref('WS'), Str('/'), Ref('WS'), Ref('Sequence')])),
        ]),
        'Sequence': Seq([Ref('Prefix'), ZeroOrMore(Seq([Ref('WS'), Ref('Prefix')]))]),
        'Prefix': First([
            Seq([Str('&'), Ref('WS'), Ref('Prefix')]),
            Seq([Str('!'), Ref('WS'), Ref('Prefix')]),
            Seq([Str('~'), Ref('WS'), Ref('Prefix')]),
            Ref('Suffix'),
        ]),
        'Suffix': First([
            Seq([Ref('Suffix'), Ref('WS'), Str('*')]),
            Seq([Ref('Suffix'), Ref('WS'), Str('+')]),
            Seq([Ref('Suffix'), Ref('WS'), Str('?')]),
            Ref('Primary'),
        ]),
        'Primary': First([
            Ref('Identifier'),
            Ref('StringLiteral'),
            Ref('CharLiteral'),
            Ref('CharClass'),
            Ref('AnyChar'),
            Ref('Parens'),
        ]),
        'Parens': Seq([Str('('), Ref('WS'), Optional(Ref('Expression')), Ref('WS'), Str(')')]),
        'Identifier': Seq([
            First([CharSet.range('a', 'z'), CharSet.range('A', 'Z'), Char('_')]),
            ZeroOrMore(First([
                CharSet.range('a', 'z'),
                CharSet.range('A', 'Z'),
                CharSet.range('0', '9'),
                Char('_'),
            ])),
        ]),
        'StringLiteral': Seq([
            Str('"'),
            ZeroOrMore(First([
                Ref('EscapeSequence'),
                Seq([NotFollowedBy(First([Str('"'), Str('\\')])), AnyChar()]),
            ])),
            Str('"'),
        ]),
        'CharLiteral': Seq([
            Str("'"),
            First([
                Ref('EscapeSequence'),
                Seq([NotFollowedBy(First([Str("'"), Str('\\')])), AnyChar()]),
            ]),
            Str("'"),
        ]),
        'EscapeSequence': Seq([
            Str('\\'),
            First([
                Char('n'),
                Char('r'),
                Char('t'),
                Char('\\'),
                Char('"'),
                Char("'"),
                Char('['),
                Char(']'),
                Char('-'),
            ]),
        ]),
        'CharClass': Seq([
            Str('['),
            Optional(Str('^')),
            OneOrMore(First([Ref('CharRange'), Ref('CharClassChar')])),
            Str(']'),
        ]),
        'CharRange': Seq([Ref('CharClassChar'), Str('-'), Ref('CharClassChar')]),
        'CharClassChar': First([
            Ref('EscapeSequence'),
            Seq([NotFollowedBy(First([Str(']'), Str('\\'), Str('-')])), AnyChar()]),
        ]),
        'AnyChar': Str('.'),
        '~WS': ZeroOrMore(First([
            Char(' '),
            Char('\t'),
            Char('\n'),
            Char('\r'),
            Ref('Comment'),
        ])),
        'Comment': Seq([
            Str('#'),
            ZeroOrMore(Seq([NotFollowedBy(Char('\n')), AnyChar()])),
            Optional(Char('\n')),
        ]),
    }

    @classmethod
    def parse_grammar(cls, grammar_spec: str) -> dict[str, Clause]:
        """Parse a grammar specification and return the rules."""
        parser = Parser(rules=cls.rules, top_rule_name='Grammar', input=grammar_spec)
        parse_result = parser.parse()
        if parse_result.has_syntax_errors:
            errors = [str(e) for e in parse_result.get_syntax_errors()]
            raise ValueError(f"Failed to parse grammar. Syntax errors:\n{chr(10).join(errors)}")

        ast = build_ast(parse_result)
        grammar_map: dict[str, Clause] = {}

        for rule_node in ast.children:
            if rule_node.label != 'Rule':
                continue

            identifier_node = next((c for c in rule_node.children if c.label == 'Identifier'), None)
            if identifier_node is None:
                raise ValueError('Rule has no Identifier child')
            rule_name = identifier_node.get_input_span(grammar_spec)

            expression_node = next((c for c in rule_node.children if c.label == 'Expression'), None)
            if expression_node is None:
                raise ValueError('Rule has no Expression child')

            is_transparent = False
            for child in rule_node.children:
                if child.label == _TERMINAL_LABEL and child.get_input_span(grammar_spec) == '~':
                    is_transparent = True
                    break
                if child.label == 'Identifier':
                    break

            clause = _build_clause(expression_node, grammar_spec)

            if is_transparent:
                grammar_map[f'~{rule_name}'] = clause
            else:
                grammar_map[rule_name] = clause

        # Validate rules
        for key in grammar_map:
            if ((key.startswith('~') and key[1:] in grammar_map) or
                (not key.startswith('~') and f'~{key}' in grammar_map)):
                raise ValueError(f'Rule "{key}" cannot be both transparent and non-transparent')
        for clause in grammar_map.values():
            clause.check_rule_refs(grammar_map)

        return grammar_map


# ------------------------------------------------------------------------------------------------------------------


def _build_clause(node: ASTNode, input_str: str) -> Clause:
    match node.label:
        case 'Expression':
            if len(node.children) == 1:
                return _build_clause(node.children[0], input_str)
            raise ValueError(f'Expression should have exactly one child, got {len(node.children)}')

        case 'Choice':
            sequences = [_build_clause(c, input_str) for c in node.children if c.label == 'Sequence']
            if not sequences:
                raise ValueError('Choice has no Sequence children')
            return sequences[0] if len(sequences) == 1 else First(sequences)

        case 'Sequence':
            prefixes = [_build_clause(c, input_str) for c in node.children if c.label == 'Prefix']
            if not prefixes:
                raise ValueError('Sequence has no Prefix children')
            return prefixes[0] if len(prefixes) == 1 else Seq(prefixes)

        case 'Prefix':
            prefix_op = None
            for child in node.children:
                if child.label == _TERMINAL_LABEL:
                    text = child.get_input_span(input_str)
                    if text in ('&', '!', '~'):
                        prefix_op = text
                        break

            operand = next((c for c in node.children if c.label in ('Prefix', 'Suffix')), None)
            if operand is None:
                raise ValueError('Prefix has no Prefix/Suffix child')
            operand_clause = _build_clause(operand, input_str)

            match prefix_op:
                case '&':
                    return FollowedBy(operand_clause)
                case '!':
                    return NotFollowedBy(operand_clause)
                case '~':
                    return operand_clause
                case _:
                    return operand_clause

        case 'Suffix':
            suffix_op = None
            for child in node.children:
                if child.label == _TERMINAL_LABEL:
                    text = child.get_input_span(input_str)
                    if text in ('*', '+', '?'):
                        suffix_op = text
                        break

            operand = next((c for c in node.children if c.label in ('Suffix', 'Primary')), None)
            if operand is None:
                raise ValueError('Suffix has no Suffix/Primary child')
            operand_clause = _build_clause(operand, input_str)

            match suffix_op:
                case '*':
                    return ZeroOrMore(operand_clause)
                case '+':
                    return OneOrMore(operand_clause)
                case '?':
                    return Optional(operand_clause)
                case _:
                    return operand_clause

        case 'Primary':
            for child in node.children:
                if child.label != _TERMINAL_LABEL:
                    return _build_clause(child, input_str)
            raise ValueError('Primary has no semantic child')

        case 'Parens':
            for child in node.children:
                if child.label == 'Expression':
                    return _build_clause(child, input_str)
            return Nothing()

        case 'Identifier':
            return Ref(node.get_input_span(input_str))

        case 'StringLiteral':
            text = node.get_input_span(input_str)
            return Str(unescape_string(text[1:-1]))

        case 'CharLiteral':
            text = node.get_input_span(input_str)
            return Char(unescape_char(text[1:-1]))

        case 'CharClass':
            return _build_char_class(node, input_str)

        case 'AnyChar':
            return AnyChar()

        case _:
            raise ValueError(f'Unknown AST node label: {node.label}')


# ------------------------------------------------------------------------------------------------------------------


def _build_char_class(node: ASTNode, input_str: str) -> Clause:
    negated = False
    for child in node.children:
        if child.label == _TERMINAL_LABEL and child.get_input_span(input_str) == '^':
            negated = True
            break

    ranges: list[tuple[int, int]] = []
    for child in node.children:
        if child.label == 'CharRange':
            char_class_chars = [c for c in child.children if c.label == 'CharClassChar']
            if len(char_class_chars) != 2:
                raise ValueError('CharRange must have exactly 2 CharClassChar children')
            lo = _extract_char_class_char_value(char_class_chars[0], input_str)
            hi = _extract_char_class_char_value(char_class_chars[1], input_str)
            ranges.append((ord(lo), ord(hi)))
        elif child.label == 'CharClassChar':
            ch = _extract_char_class_char_value(child, input_str)
            cp = ord(ch)
            ranges.append((cp, cp))

    if not ranges:
        raise ValueError('CharClass has no character items')

    return CharSet(ranges, inverted=negated)


# ------------------------------------------------------------------------------------------------------------------


def _extract_char_class_char_value(node: ASTNode, input_str: str) -> str:
    for child in node.children:
        if child.label == 'EscapeSequence':
            return unescape_char(child.get_input_span(input_str))
    return unescape_char(node.get_input_span(input_str))
