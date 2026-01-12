"""JSON Parsing tests."""

from __future__ import annotations

import re
from dataclasses import dataclass


from squirrelparser import (
    ASTNode,
    CSTNode,
    CSTNodeFactoryFn,
    squirrel_parse_cst,
    squirrel_parse_pt,
)


# ============================================================================
# JSON CST Node Classes
# ============================================================================


class JsonValue(CSTNode):
    """Base class for JSON values."""

    def __init__(self, ast_node: ASTNode, children: list[CSTNode]):
        super().__init__(ast_node, children)


class JsonObject(JsonValue):
    """JSON object node."""

    def __init__(self, ast_node: ASTNode, children: list[CSTNode], members: list[JsonMember]):
        super().__init__(ast_node, children)
        self.members = members


class JsonArray(JsonValue):
    """JSON array node."""

    def __init__(self, ast_node: ASTNode, children: list[CSTNode], elements: list[JsonValue]):
        super().__init__(ast_node, children)
        self.elements = elements


class JsonString(JsonValue):
    """JSON string node."""

    def __init__(self, ast_node: ASTNode, children: list[CSTNode], value: str):
        super().__init__(ast_node, children)
        self.value = value


class JsonNumber(JsonValue):
    """JSON number node."""

    def __init__(self, ast_node: ASTNode, children: list[CSTNode], value: float):
        super().__init__(ast_node, children)
        self.value = value


class JsonBoolean(JsonValue):
    """JSON boolean node."""

    def __init__(self, ast_node: ASTNode, children: list[CSTNode], value: bool):
        super().__init__(ast_node, children)
        self.value = value


class JsonNull(JsonValue):
    """JSON null node."""

    def __init__(self, ast_node: ASTNode, children: list[CSTNode]):
        super().__init__(ast_node, children)


class JsonMember(CSTNode):
    """JSON object member node."""

    def __init__(self, ast_node: ASTNode, children: list[CSTNode], key: str, value: JsonValue):
        super().__init__(ast_node, children)
        self.key = key
        self.value = value


class JsonTerminal(CSTNode):
    """JSON terminal node."""

    def __init__(self, ast_node: ASTNode):
        super().__init__(ast_node, [])


# ============================================================================
# Full JSON Grammar according to json.org specification
# ============================================================================

JSON_GRAMMAR = r'''
JSON <- WS Value WS;
Value <- Object / Array / String / Number / Boolean / Null;
Object <- '{' WS (Member (WS ',' WS Member)*)? WS '}';
Member <- String WS ':' WS Value;
Array <- '[' WS (Value (WS ',' WS Value)*)? WS ']';
String <- '"' Character* '"';
Character <- [^"\\] / ('\\' Escape);
Escape <- '"' / '\\' / '/' / 'b' / 'f' / 'n' / 'r' / 't' / ('u' [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F]);
Number <- Integer Fraction? Exponent?;
Integer <- '-'? (([1-9] [0-9]+) / [0-9]);
Fraction <- '.' [0-9]+;
Exponent <- ("e" / "E") ("+" / "-")? [0-9]+;
Boolean <- "true" / "false";
Null <- "null";
~WS <- [ \t\n\r]*;
'''


# ============================================================================
# Helper Functions
# ============================================================================


def extract_string_value(quoted_string: str) -> str:
    """Extract and unescape a JSON string value."""
    if len(quoted_string) < 2:
        return ''
    content = quoted_string[1:-1]

    content = (
        content.replace('\\"', '"')
        .replace('\\\\', '\\')
        .replace('\\/', '/')
        .replace('\\b', '\b')
        .replace('\\f', '\f')
        .replace('\\n', '\n')
        .replace('\\r', '\r')
        .replace('\\t', '\t')
    )

    def replace_unicode(match: re.Match[str]) -> str:
        hex_str = match.group(1)
        code_unit = int(hex_str, 16)
        return chr(code_unit)

    content = re.sub(r'\\u([0-9a-fA-F]{4})', replace_unicode, content)

    return content


def parse_number(num_str: str) -> float:
    """Parse a JSON number string."""
    try:
        return float(num_str)
    except ValueError:
        # If parsing fails, return 0 as a fallback
        # This can happen with invalid numbers due to error recovery
        return 0.0


# ============================================================================
# Parse Function
# ============================================================================


@dataclass
class ParseJsonResult:
    """Result of parsing JSON."""

    cst: CSTNode
    errors: list[str]


def parse_json(input_str: str, allow_errors: bool = False) -> ParseJsonResult:
    """Parse JSON and return CST with errors."""
    # Parse and get syntax errors using high-level API
    parse_result = squirrel_parse_pt(
        grammar_spec=JSON_GRAMMAR,
        top_rule_name='JSON',
        input=input_str,
    )

    syntax_errors = parse_result.get_syntax_errors()
    error_strings = [input_str[e.pos : e.pos + e.len] for e in syntax_errors]

    def json_factory(ast_node: ASTNode, children: list[CSTNode]) -> CSTNode:
        values = [c for c in children if isinstance(c, JsonValue)]
        if not values:
            return JsonNull(ast_node, children)
        return values[0]

    def value_factory(ast_node: ASTNode, children: list[CSTNode]) -> CSTNode:
        values = [c for c in children if isinstance(c, JsonValue)]
        if not values:
            return JsonNull(ast_node, children)
        return values[0]

    def object_factory(ast_node: ASTNode, children: list[CSTNode]) -> CSTNode:
        members = [c for c in children if isinstance(c, JsonMember)]
        return JsonObject(ast_node, children, members)

    def member_factory(ast_node: ASTNode, children: list[CSTNode]) -> CSTNode:
        key_node: JsonString | None = None
        value_node: JsonValue | None = None

        for child in children:
            if isinstance(child, JsonString) and key_node is None:
                key_node = child
            if isinstance(child, JsonValue) and not isinstance(child, JsonString) and value_node is None:
                value_node = child

        key_str = key_node.value if key_node else ''
        return JsonMember(
            ast_node,
            children,
            key_str,
            value_node if value_node else JsonNull(ast_node, []),
        )

    def array_factory(ast_node: ASTNode, children: list[CSTNode]) -> CSTNode:
        elements = [c for c in children if isinstance(c, JsonValue)]
        return JsonArray(ast_node, children, elements)

    def string_factory(ast_node: ASTNode, children: list[CSTNode]) -> CSTNode:
        quoted = ast_node.get_input_span(input_str)
        value = extract_string_value(quoted)
        return JsonString(ast_node, children, value)

    def character_factory(ast_node: ASTNode, children: list[CSTNode]) -> CSTNode:
        return JsonString(ast_node, children, ast_node.get_input_span(input_str))

    def escape_factory(ast_node: ASTNode, children: list[CSTNode]) -> CSTNode:
        return JsonString(ast_node, children, '')

    def number_factory(ast_node: ASTNode, children: list[CSTNode]) -> CSTNode:
        num_str = ast_node.get_input_span(input_str)
        return JsonNumber(ast_node, children, parse_number(num_str))

    def integer_factory(ast_node: ASTNode, children: list[CSTNode]) -> CSTNode:
        return JsonNull(ast_node, children)

    def fraction_factory(ast_node: ASTNode, children: list[CSTNode]) -> CSTNode:
        return JsonNull(ast_node, children)

    def exponent_factory(ast_node: ASTNode, children: list[CSTNode]) -> CSTNode:
        return JsonNull(ast_node, children)

    def boolean_factory(ast_node: ASTNode, children: list[CSTNode]) -> CSTNode:
        bool_str = ast_node.get_input_span(input_str)
        return JsonBoolean(ast_node, children, bool_str == 'true')

    def null_factory(ast_node: ASTNode, children: list[CSTNode]) -> CSTNode:
        return JsonNull(ast_node, children)

    def terminal_factory(ast_node: ASTNode, children: list[CSTNode]) -> CSTNode:
        return JsonTerminal(ast_node)

    def syntax_error_factory(ast_node: ASTNode, children: list[CSTNode]) -> CSTNode:
        return JsonNull(ast_node, children)

    factories: dict[str, CSTNodeFactoryFn] = {
        'JSON': json_factory,
        'Value': value_factory,
        'Object': object_factory,
        'Member': member_factory,
        'Array': array_factory,
        'String': string_factory,
        'Character': character_factory,
        'Escape': escape_factory,
        'Number': number_factory,
        'Integer': integer_factory,
        'Fraction': fraction_factory,
        'Exponent': exponent_factory,
        'Boolean': boolean_factory,
        'Null': null_factory,
        '<Terminal>': terminal_factory,
        '<SyntaxError>': syntax_error_factory,
    }

    try:
        cst = squirrel_parse_cst(
            grammar_spec=JSON_GRAMMAR,
            top_rule_name='JSON',
            factories=factories,
            input=input_str,
            allow_syntax_errors=True,  # Always allow syntax errors during parsing for recovery
        )
        return ParseJsonResult(cst=cst, errors=error_strings)
    except ValueError as e:
        return ParseJsonResult(
            cst=JsonNull(ASTNode(label='Error', pos=0, length=0, children=[]), []),
            errors=[str(e)],
        )


# ============================================================================
# Tests
# ============================================================================


class TestJsonParsingBasicValues:
    """JSON Parsing - Basic Values tests."""

    def test_parses_json_null(self):
        result = parse_json('null')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonNull)

    def test_parses_json_boolean_true(self):
        result = parse_json('true')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonBoolean)
        bool_node = result.cst
        assert bool_node.value is True

    def test_parses_json_boolean_false(self):
        result = parse_json('false')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonBoolean)
        bool_node = result.cst
        assert bool_node.value is False

    def test_parses_json_integer(self):
        result = parse_json('42')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonNumber)
        num_node = result.cst
        assert num_node.value == 42

    def test_parses_json_negative_number(self):
        result = parse_json('-123')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonNumber)
        num_node = result.cst
        assert num_node.value == -123

    def test_parses_json_decimal_number(self):
        result = parse_json('3.14')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonNumber)
        num_node = result.cst
        assert num_node.value == 3.14

    def test_parses_json_number_with_exponent(self):
        result = parse_json('1e3')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonNumber)

    def test_parses_empty_json_string(self):
        result = parse_json('""')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonString)
        str_node = result.cst
        assert str_node.value == ''

    def test_parses_json_string_with_content(self):
        result = parse_json('"hello"')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonString)

    def test_parses_empty_json_array(self):
        result = parse_json('[]')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonArray)
        arr_node = result.cst
        assert len(arr_node.elements) == 0

    def test_parses_json_array_with_single_element(self):
        result = parse_json('[42]')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonArray)
        arr_node = result.cst
        assert len(arr_node.elements) == 1

    def test_parses_json_array_with_multiple_elements(self):
        result = parse_json('[1, 2, 3]')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonArray)
        arr_node = result.cst
        assert len(arr_node.elements) == 3

    def test_parses_empty_json_object(self):
        result = parse_json('{}')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonObject)
        obj_node = result.cst
        assert len(obj_node.members) == 0

    def test_parses_json_object_with_single_property(self):
        result = parse_json('{"key": 42}')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonObject)
        obj_node = result.cst
        assert len(obj_node.members) == 1

    def test_parses_json_object_with_multiple_properties(self):
        result = parse_json('{"a": 1, "b": 2, "c": 3}')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonObject)
        obj_node = result.cst
        assert len(obj_node.members) == 3


class TestJsonParsingNestedStructures:
    """JSON Parsing - Nested Structures tests."""

    def test_parses_nested_array_of_arrays(self):
        result = parse_json('[[1, 2], [3, 4]]')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonArray)
        arr_node = result.cst
        assert len(arr_node.elements) == 2

    def test_parses_nested_object_in_array(self):
        result = parse_json('[{"key": "value"}]')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonArray)
        arr_node = result.cst
        assert len(arr_node.elements) == 1

    def test_parses_nested_array_in_object(self):
        result = parse_json('{"array": [1, 2, 3]}')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonObject)
        obj_node = result.cst
        assert len(obj_node.members) == 1

    def test_parses_complex_nested_structure(self):
        result = parse_json(
            '''{
              "users": [
                {"name": "Alice", "age": 30},
                {"name": "Bob", "age": 25}
              ],
              "active": true
            }'''
        )
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonObject)


class TestJsonParsingWhitespaceHandling:
    """JSON Parsing - Whitespace Handling tests."""

    def test_parses_with_leading_whitespace(self):
        result = parse_json('  null')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonNull)

    def test_parses_with_trailing_whitespace(self):
        result = parse_json('null  ')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonNull)

    def test_parses_with_whitespace_around_structure(self):
        result = parse_json('  {  "key"  :  42  }  ')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonObject)

    def test_parses_with_newlines_and_tabs(self):
        result = parse_json('{\n\t"key": 42\n}')
        assert len(result.errors) == 0
        assert isinstance(result.cst, JsonObject)


class TestJsonParsingErrorCases:
    """JSON Parsing - Error Cases tests."""

    def test_detects_incomplete_array(self):
        result = parse_json('[1, 2')
        assert len(result.errors) > 0

    def test_detects_incomplete_object(self):
        result = parse_json('{"key": "value"')
        assert len(result.errors) > 0

    def test_detects_invalid_number(self):
        result = parse_json('[1, 2.3.4, 5]')
        assert len(result.errors) > 0

    def test_detects_missing_value(self):
        result = parse_json('[1, , 3]')
        assert len(result.errors) > 0

    def test_detects_trailing_comma_in_array(self):
        result = parse_json('[1, 2, 3,]')
        assert len(result.errors) > 0

    def test_detects_missing_colon_in_object(self):
        result = parse_json('{"key" 42}')
        assert len(result.errors) > 0

    def test_detects_trailing_comma_in_object(self):
        result = parse_json('{"key": 42,}')
        assert len(result.errors) > 0

    def test_detects_unquoted_key(self):
        result = parse_json('{key: 42}')
        assert len(result.errors) > 0
