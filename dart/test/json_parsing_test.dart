import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

// ============================================================================
// JSON CST Node Classes
// ============================================================================

abstract class JsonValue extends CSTNode {
  JsonValue({required super.astNode, required super.children});
}

class JsonObject extends JsonValue {
  final List<JsonMember> members;

  JsonObject({required super.astNode, required super.children, required this.members});
}

class JsonArray extends JsonValue {
  final List<JsonValue> elements;

  JsonArray({required super.astNode, required super.children, required this.elements});
}

class JsonString extends JsonValue {
  final String value;

  JsonString({required super.astNode, required super.children, required this.value});
}

class JsonNumber extends JsonValue {
  final num value;

  JsonNumber({required super.astNode, required super.children, required this.value});
}

class JsonBoolean extends JsonValue {
  final bool value;

  JsonBoolean({required super.astNode, required super.children, required this.value});
}

class JsonNull extends JsonValue {
  JsonNull({required super.astNode, required super.children});
}

class JsonMember extends CSTNode {
  final String key;
  final JsonValue value;

  JsonMember({required super.astNode, required super.children, required this.key, required this.value});
}

class JsonTerminal extends CSTNode {
  JsonTerminal({required super.astNode}) : super(children: []);
}

// ============================================================================
// Full JSON Grammar according to json.org specification
// ============================================================================

const String jsonGrammar = '''
JSON <- WS Value WS;
Value <- Object / Array / String / Number / Boolean / Null;
Object <- '{' WS (Member (WS ',' WS Member)*)? WS '}';
Member <- String WS ':' WS Value;
Array <- '[' WS (Value (WS ',' WS Value)*)? WS ']';
String <- '"' Character* '"';
Character <- [^"\\\\] / ('\\\\' Escape);
Escape <- '"' / '\\\\' / '/' / 'b' / 'f' / 'n' / 'r' / 't' / ('u' [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F]);
Number <- Integer Fraction? Exponent?;
Integer <- '-'? (([1-9] [0-9]+) / [0-9]);
Fraction <- '.' [0-9]+;
Exponent <- ("e" / "E") ("+" / "-")? [0-9]+;
Boolean <- "true" / "false";
Null <- "null";
~WS <- [ \\t\\n\\r]*;
''';

// ============================================================================
// Helper Functions
// ============================================================================

String extractStringValue(String quotedString) {
  if (quotedString.length < 2) return '';
  String content = quotedString.substring(1, quotedString.length - 1);

  return content
      .replaceAll(r'\"', '"')
      .replaceAll(r'\\', '\\')
      .replaceAll(r'\/', '/')
      .replaceAll(r'\b', '\b')
      .replaceAll(r'\f', '\f')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\r', '\r')
      .replaceAll(r'\t', '\t')
      .replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (m) {
    final hex = m.group(1)!;
    final codeUnit = int.parse(hex, radix: 16);
    return String.fromCharCode(codeUnit);
  });
}

num parseNumber(String numStr) {
  try {
    return num.parse(numStr);
  } catch (e) {
    // If parsing fails, return 0 as a fallback
    // This can happen with invalid numbers due to error recovery
    return 0;
  }
}

// ============================================================================
// Parse Function
// ============================================================================

(CSTNode, List<String>) parseJson(String input, {bool allowErrors = false}) {
  // Parse and get syntax errors using high-level API
  final parseResult = squirrelParsePT(
    grammarSpec: jsonGrammar,
    topRuleName: 'JSON',
    input: input,
  );

  final syntaxErrors = parseResult.getSyntaxErrors();
  final errorStrings = syntaxErrors.map((e) => input.substring(e.pos, e.pos + e.len)).toList();

  final factories = [
    CSTNodeFactory(
      ruleName: 'JSON',
      factory: (astNode, children) {
        var values = children.whereType<JsonValue>().toList();
        if (values.isEmpty) return JsonNull(astNode: astNode, children: children);
        return values[0];
      },
    ),
    CSTNodeFactory(
      ruleName: 'Value',
      factory: (astNode, children) {
        var values = children.whereType<JsonValue>().toList();
        if (values.isEmpty) return JsonNull(astNode: astNode, children: children);
        return values[0];
      },
    ),
    CSTNodeFactory(
      ruleName: 'Object',
      factory: (astNode, children) {
        var members = children.whereType<JsonMember>().toList();
        return JsonObject(astNode: astNode, children: children, members: members);
      },
    ),
    CSTNodeFactory(
      ruleName: 'Member',
      factory: (astNode, children) {
        JsonString? keyNode;
        JsonValue? valueNode;

        for (var child in children) {
          if (child is JsonString && keyNode == null) {
            keyNode = child;
          }
          if (child is JsonValue && child is! JsonString && valueNode == null) {
            valueNode = child;
          }
        }

        String keyStr = keyNode?.value ?? '';
        return JsonMember(
          astNode: astNode,
          children: children,
          key: keyStr,
          value: valueNode ?? JsonNull(astNode: astNode, children: []),
        );
      },
    ),
    CSTNodeFactory(
      ruleName: 'Array',
      factory: (astNode, children) {
        var elements = children.whereType<JsonValue>().toList();
        return JsonArray(astNode: astNode, children: children, elements: elements);
      },
    ),
    CSTNodeFactory(
      ruleName: 'String',
      factory: (astNode, children) {
        final quoted = astNode.getInputSpan(input);
        final value = extractStringValue(quoted);
        return JsonString(astNode: astNode, children: children, value: value);
      },
    ),
    CSTNodeFactory(
      ruleName: 'Character',
      factory: (astNode, children) {
        return JsonString(astNode: astNode, children: children, value: astNode.getInputSpan(input));
      },
    ),
    CSTNodeFactory(
      ruleName: 'Escape',
      factory: (astNode, children) {
        return JsonString(astNode: astNode, children: children, value: '');
      },
    ),
    CSTNodeFactory(
      ruleName: 'Number',
      factory: (astNode, children) {
        final numStr = astNode.getInputSpan(input);
        return JsonNumber(astNode: astNode, children: children, value: parseNumber(numStr));
      },
    ),
    CSTNodeFactory(
      ruleName: 'Integer',
      factory: (astNode, children) {
        return JsonNull(astNode: astNode, children: children);
      },
    ),
    CSTNodeFactory(
      ruleName: 'Fraction',
      factory: (astNode, children) {
        return JsonNull(astNode: astNode, children: children);
      },
    ),
    CSTNodeFactory(
      ruleName: 'Exponent',
      factory: (astNode, children) {
        return JsonNull(astNode: astNode, children: children);
      },
    ),
    CSTNodeFactory(
      ruleName: 'Boolean',
      factory: (astNode, children) {
        final boolStr = astNode.getInputSpan(input);
        return JsonBoolean(astNode: astNode, children: children, value: boolStr == 'true');
      },
    ),
    CSTNodeFactory(
      ruleName: 'Null',
      factory: (astNode, children) {
        return JsonNull(astNode: astNode, children: children);
      },
    ),
    CSTNodeFactory(
      ruleName: '<Terminal>',
      factory: (astNode, children) {
        // Return a terminal node, not a JsonValue
        return JsonTerminal(astNode: astNode);
      },
    ),
    CSTNodeFactory(
      ruleName: '<SyntaxError>',
      factory: (astNode, children) {
        return JsonNull(astNode: astNode, children: children);
      },
    ),
  ];

  try {
    final cst = squirrelParseCST(
      grammarSpec: jsonGrammar,
      topRuleName: 'JSON',
      factories: factories,
      input: input,
      allowSyntaxErrors: true,  // Always allow syntax errors during parsing for recovery
    );
    return (cst, errorStrings);
  } on ArgumentError catch (e) {
    return (JsonNull(astNode: ASTNode(label: 'Error', children: [], pos: 0, len: 0), children: []), [e.toString()]);
  }
}

// ============================================================================
// Tests
// ============================================================================

void main() {
  group('JSON Parsing - Basic Values', () {
    test('parses JSON null', () {
      final (cst, errors) = parseJson('null');
      expect(errors, isEmpty);
      expect(cst, isA<JsonNull>());
    });

    test('parses JSON boolean true', () {
      final (cst, errors) = parseJson('true');
      expect(errors, isEmpty);
      expect(cst, isA<JsonBoolean>());
      final boolNode = cst as JsonBoolean;
      expect(boolNode.value, isTrue);
    });

    test('parses JSON boolean false', () {
      final (cst, errors) = parseJson('false');
      expect(errors, isEmpty);
      expect(cst, isA<JsonBoolean>());
      final boolNode = cst as JsonBoolean;
      expect(boolNode.value, isFalse);
    });

    test('parses JSON integer', () {
      final (cst, errors) = parseJson('42');
      expect(errors, isEmpty);
      expect(cst, isA<JsonNumber>());
      final numNode = cst as JsonNumber;
      expect(numNode.value, equals(42));
    });

    test('parses JSON negative number', () {
      final (cst, errors) = parseJson('-123');
      expect(errors, isEmpty);
      expect(cst, isA<JsonNumber>());
      final numNode = cst as JsonNumber;
      expect(numNode.value, equals(-123));
    });

    test('parses JSON decimal number', () {
      final (cst, errors) = parseJson('3.14');
      expect(errors, isEmpty);
      expect(cst, isA<JsonNumber>());
      final numNode = cst as JsonNumber;
      expect(numNode.value, equals(3.14));
    });

    test('parses JSON number with exponent', () {
      final (cst, errors) = parseJson('1e3');
      expect(errors, isEmpty);
      expect(cst, isA<JsonNumber>());
    });

    test('parses empty JSON string', () {
      final (cst, errors) = parseJson('""');
      expect(errors, isEmpty);
      expect(cst, isA<JsonString>());
      final strNode = cst as JsonString;
      expect(strNode.value, isEmpty);
    });

    test('parses JSON string with content', () {
      final (cst, errors) = parseJson('"hello"');
      expect(errors, isEmpty);
      expect(cst, isA<JsonString>());
    });

    test('parses empty JSON array', () {
      final (cst, errors) = parseJson('[]');
      expect(errors, isEmpty);
      expect(cst, isA<JsonArray>());
      final arrNode = cst as JsonArray;
      expect(arrNode.elements, isEmpty);
    });

    test('parses JSON array with single element', () {
      final (cst, errors) = parseJson('[42]');
      expect(errors, isEmpty);
      expect(cst, isA<JsonArray>());
      final arrNode = cst as JsonArray;
      expect(arrNode.elements.length, equals(1));
    });

    test('parses JSON array with multiple elements', () {
      final (cst, errors) = parseJson('[1, 2, 3]');
      expect(errors, isEmpty);
      expect(cst, isA<JsonArray>());
      final arrNode = cst as JsonArray;
      expect(arrNode.elements.length, equals(3));
    });

    test('parses empty JSON object', () {
      final (cst, errors) = parseJson('{}');
      expect(errors, isEmpty);
      expect(cst, isA<JsonObject>());
      final objNode = cst as JsonObject;
      expect(objNode.members, isEmpty);
    });

    test('parses JSON object with single property', () {
      final (cst, errors) = parseJson('{"key": 42}');
      expect(errors, isEmpty);
      expect(cst, isA<JsonObject>());
      final objNode = cst as JsonObject;
      expect(objNode.members.length, equals(1));
    });

    test('parses JSON object with multiple properties', () {
      final (cst, errors) = parseJson('{"a": 1, "b": 2, "c": 3}');
      expect(errors, isEmpty);
      expect(cst, isA<JsonObject>());
      final objNode = cst as JsonObject;
      expect(objNode.members.length, equals(3));
    });
  });

  group('JSON Parsing - Nested Structures', () {
    test('parses nested array of arrays', () {
      final (cst, errors) = parseJson('[[1, 2], [3, 4]]');
      expect(errors, isEmpty);
      expect(cst, isA<JsonArray>());
      final arrNode = cst as JsonArray;
      expect(arrNode.elements.length, equals(2));
    });

    test('parses nested object in array', () {
      final (cst, errors) = parseJson('[{"key": "value"}]');
      expect(errors, isEmpty);
      expect(cst, isA<JsonArray>());
      final arrNode = cst as JsonArray;
      expect(arrNode.elements.length, equals(1));
    });

    test('parses nested array in object', () {
      final (cst, errors) = parseJson('{"array": [1, 2, 3]}');
      expect(errors, isEmpty);
      expect(cst, isA<JsonObject>());
      final objNode = cst as JsonObject;
      expect(objNode.members.length, equals(1));
    });

    test('parses complex nested structure', () {
      final (cst, errors) = parseJson('''{
        "users": [
          {"name": "Alice", "age": 30},
          {"name": "Bob", "age": 25}
        ],
        "active": true
      }''');
      expect(errors, isEmpty);
      expect(cst, isA<JsonObject>());
    });
  });

  group('JSON Parsing - Whitespace Handling', () {
    test('parses with leading whitespace', () {
      final (cst, errors) = parseJson('  null');
      expect(errors, isEmpty);
      expect(cst, isA<JsonNull>());
    });

    test('parses with trailing whitespace', () {
      final (cst, errors) = parseJson('null  ');
      expect(errors, isEmpty);
      expect(cst, isA<JsonNull>());
    });

    test('parses with whitespace around structure', () {
      final (cst, errors) = parseJson('  {  "key"  :  42  }  ');
      expect(errors, isEmpty);
      expect(cst, isA<JsonObject>());
    });

    test('parses with newlines and tabs', () {
      final (cst, errors) = parseJson('{\n\t"key": 42\n}');
      expect(errors, isEmpty);
      expect(cst, isA<JsonObject>());
    });
  });

  group('JSON Parsing - Error Cases', () {
    test('detects incomplete array', () {
      final (cst, errors) = parseJson('[1, 2');
      expect(errors, isNotEmpty);
    });

    test('detects incomplete object', () {
      final (cst, errors) = parseJson('{"key": "value"');
      expect(errors, isNotEmpty);
    });

    test('detects invalid number', () {
      final (cst, errors) = parseJson('[1, 2.3.4, 5]');
      expect(errors, isNotEmpty);
    });

    test('detects missing value', () {
      final (cst, errors) = parseJson('[1, , 3]');
      expect(errors, isNotEmpty);
    });

    test('detects trailing comma in array', () {
      final (cst, errors) = parseJson('[1, 2, 3,]');
      expect(errors, isNotEmpty);
    });

    test('detects missing colon in object', () {
      final (cst, errors) = parseJson('{"key" 42}');
      expect(errors, isNotEmpty);
    });

    test('detects trailing comma in object', () {
      final (cst, errors) = parseJson('{"key": 42,}');
      expect(errors, isNotEmpty);
    });

    test('detects unquoted key', () {
      final (cst, errors) = parseJson('{key: 42}');
      expect(errors, isNotEmpty);
    });
  });
}
