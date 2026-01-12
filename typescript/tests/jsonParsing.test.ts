import {
  ASTNode,
  CSTNode,
  CSTNodeFactory,
  squirrelParseCST,
  squirrelParsePT,
} from '../src/index.js';

// ============================================================================
// JSON CST Node Classes
// ============================================================================

abstract class JsonValue extends CSTNode {
  constructor(astNode: ASTNode, children: readonly CSTNode[]) {
    super(astNode, children);
  }
}

class JsonObject extends JsonValue {
  readonly members: JsonMember[];

  constructor(astNode: ASTNode, children: readonly CSTNode[], members: JsonMember[]) {
    super(astNode, children);
    this.members = members;
  }
}

class JsonArray extends JsonValue {
  readonly elements: JsonValue[];

  constructor(astNode: ASTNode, children: readonly CSTNode[], elements: JsonValue[]) {
    super(astNode, children);
    this.elements = elements;
  }
}

class JsonString extends JsonValue {
  readonly value: string;

  constructor(astNode: ASTNode, children: readonly CSTNode[], value: string) {
    super(astNode, children);
    this.value = value;
  }
}

class JsonNumber extends JsonValue {
  readonly value: number;

  constructor(astNode: ASTNode, children: readonly CSTNode[], value: number) {
    super(astNode, children);
    this.value = value;
  }
}

class JsonBoolean extends JsonValue {
  readonly value: boolean;

  constructor(astNode: ASTNode, children: readonly CSTNode[], value: boolean) {
    super(astNode, children);
    this.value = value;
  }
}

class JsonNull extends JsonValue {
  constructor(astNode: ASTNode, children: readonly CSTNode[]) {
    super(astNode, children);
  }
}

class JsonMember extends CSTNode {
  readonly key: string;
  readonly value: JsonValue;

  constructor(astNode: ASTNode, children: readonly CSTNode[], key: string, value: JsonValue) {
    super(astNode, children);
    this.key = key;
    this.value = value;
  }
}

class JsonTerminal extends CSTNode {
  constructor(astNode: ASTNode) {
    super(astNode, []);
  }
}

// ============================================================================
// Full JSON Grammar according to json.org specification
// ============================================================================

const jsonGrammar = `
JSON <- WS Value WS;
Value <- Object / Array / String / Number / Boolean / Null;
Object <- '{' WS (Member (WS ',' WS Member)*)? WS '}';
Member <- String WS ':' WS Value;
Array <- '[' WS (Value (WS ',' WS Value)*)? WS ']';
String <- '"' Character* '"';
Character <- [^\\"\\\\] / ('\\\\' Escape);
Escape <- '"' / '\\\\' / '/' / 'b' / 'f' / 'n' / 'r' / 't' / ('u' [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F]);
Number <- Integer Fraction? Exponent?;
Integer <- '-'? (([1-9] [0-9]+) / [0-9]);
Fraction <- '.' [0-9]+;
Exponent <- ("e" / "E") ("+" / "-")? [0-9]+;
Boolean <- "true" / "false";
Null <- "null";
~WS <- [ \\t\\n\\r]*;
`;

// ============================================================================
// Helper Functions
// ============================================================================

function extractStringValue(quotedString: string): string {
  if (quotedString.length < 2) return '';
  let content = quotedString.substring(1, quotedString.length - 1);

  content = content
    .replace(/\\"/g, '"')
    .replace(/\\\\/g, '\\')
    .replace(/\\\//g, '/')
    .replace(/\\b/g, '\b')
    .replace(/\\f/g, '\f')
    .replace(/\\n/g, '\n')
    .replace(/\\r/g, '\r')
    .replace(/\\t/g, '\t')
    .replace(/\\u([0-9a-fA-F]{4})/g, (_, hex) => {
      const codeUnit = parseInt(hex, 16);
      return String.fromCharCode(codeUnit);
    });

  return content;
}

function parseNumber(numStr: string): number {
  try {
    return parseFloat(numStr);
  } catch {
    // If parsing fails, return 0 as a fallback
    // This can happen with invalid numbers due to error recovery
    return 0;
  }
}

// ============================================================================
// Parse Function
// ============================================================================

interface ParseJsonResult {
  cst: CSTNode;
  errors: string[];
}

function parseJson(input: string, _allowErrors = false): ParseJsonResult {
  // Parse and get syntax errors using high-level API
  const parseResult = squirrelParsePT({
    grammarSpec: jsonGrammar,
    topRuleName: 'JSON',
    input,
  });

  const syntaxErrors = parseResult.getSyntaxErrors();
  const errorStrings = syntaxErrors.map((e) => input.substring(e.pos, e.pos + e.len));

  const factories: CSTNodeFactory[] = [
    {
      ruleName: 'JSON',
      factory: (astNode, children) => {
        const values = children.filter((c): c is JsonValue => c instanceof JsonValue);
        if (values.length === 0) return new JsonNull(astNode, [...children]);
        return values[0];
      },
    },
    {
      ruleName: 'Value',
      factory: (astNode, children) => {
        const values = children.filter((c): c is JsonValue => c instanceof JsonValue);
        if (values.length === 0) return new JsonNull(astNode, [...children]);
        return values[0];
      },
    },
    {
      ruleName: 'Object',
      factory: (astNode, children) => {
        const members = children.filter((c): c is JsonMember => c instanceof JsonMember);
        return new JsonObject(astNode, children, members);
      },
    },
    {
      ruleName: 'Member',
      factory: (astNode, children) => {
        let keyNode: JsonString | null = null;
        let valueNode: JsonValue | null = null;

        for (const child of children) {
          if (child instanceof JsonString && keyNode === null) {
            keyNode = child;
          }
          if (child instanceof JsonValue && !(child instanceof JsonString) && valueNode === null) {
            valueNode = child;
          }
        }

        const keyStr = keyNode?.value ?? '';
        return new JsonMember(astNode, children, keyStr, valueNode ?? new JsonNull(astNode, []));
      },
    },
    {
      ruleName: 'Array',
      factory: (astNode, children) => {
        const elements = children.filter((c): c is JsonValue => c instanceof JsonValue);
        return new JsonArray(astNode, children, elements);
      },
    },
    {
      ruleName: 'String',
      factory: (astNode, children) => {
        const quoted = astNode.getInputSpan(input);
        const value = extractStringValue(quoted);
        return new JsonString(astNode, children, value);
      },
    },
    {
      ruleName: 'Character',
      factory: (astNode, children) => new JsonString(astNode, children, astNode.getInputSpan(input)),
    },
    {
      ruleName: 'Escape',
      factory: (astNode, children) => new JsonString(astNode, children, ''),
    },
    {
      ruleName: 'Number',
      factory: (astNode, children) => {
        const numStr = astNode.getInputSpan(input);
        return new JsonNumber(astNode, children, parseNumber(numStr));
      },
    },
    {
      ruleName: 'Integer',
      factory: (astNode, children) => new JsonNull(astNode, children),
    },
    {
      ruleName: 'Fraction',
      factory: (astNode, children) => new JsonNull(astNode, children),
    },
    {
      ruleName: 'Exponent',
      factory: (astNode, children) => new JsonNull(astNode, children),
    },
    {
      ruleName: 'Boolean',
      factory: (astNode, children) => {
        const boolStr = astNode.getInputSpan(input);
        return new JsonBoolean(astNode, children, boolStr === 'true');
      },
    },
    {
      ruleName: 'Null',
      factory: (astNode, children) => new JsonNull(astNode, children),
    },
    {
      ruleName: '<Terminal>',
      factory: (astNode, _children) => new JsonTerminal(astNode),
    },
    {
      ruleName: '<SyntaxError>',
      factory: (astNode, children) => new JsonNull(astNode, children),
    },
  ];

  try {
    const cst = squirrelParseCST({
      grammarSpec: jsonGrammar,
      topRuleName: 'JSON',
      factories,
      input,
      allowSyntaxErrors: true, // Always allow syntax errors during parsing for recovery
    });
    return { cst, errors: errorStrings };
  } catch (e) {
    return {
      cst: new JsonNull(ASTNode.of('Error', 0, 0, []), []),
      errors: [String(e)],
    };
  }
}

// ============================================================================
// Tests
// ============================================================================

describe('JSON Parsing - Basic Values', () => {
  it('parses JSON null', () => {
    const result = parseJson('null');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonNull);
  });

  it('parses JSON boolean true', () => {
    const result = parseJson('true');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonBoolean);
    const boolNode = result.cst as JsonBoolean;
    expect(boolNode.value).toBe(true);
  });

  it('parses JSON boolean false', () => {
    const result = parseJson('false');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonBoolean);
    const boolNode = result.cst as JsonBoolean;
    expect(boolNode.value).toBe(false);
  });

  it('parses JSON integer', () => {
    const result = parseJson('42');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonNumber);
    const numNode = result.cst as JsonNumber;
    expect(numNode.value).toBe(42);
  });

  it('parses JSON negative number', () => {
    const result = parseJson('-123');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonNumber);
    const numNode = result.cst as JsonNumber;
    expect(numNode.value).toBe(-123);
  });

  it('parses JSON decimal number', () => {
    const result = parseJson('3.14');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonNumber);
    const numNode = result.cst as JsonNumber;
    expect(numNode.value).toBe(3.14);
  });

  it('parses JSON number with exponent', () => {
    const result = parseJson('1e3');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonNumber);
  });

  it('parses empty JSON string', () => {
    const result = parseJson('""');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonString);
    const strNode = result.cst as JsonString;
    expect(strNode.value).toBe('');
  });

  it('parses JSON string with content', () => {
    const result = parseJson('"hello"');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonString);
  });

  it('parses empty JSON array', () => {
    const result = parseJson('[]');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonArray);
    const arrNode = result.cst as JsonArray;
    expect(arrNode.elements).toHaveLength(0);
  });

  it('parses JSON array with single element', () => {
    const result = parseJson('[42]');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonArray);
    const arrNode = result.cst as JsonArray;
    expect(arrNode.elements).toHaveLength(1);
  });

  it('parses JSON array with multiple elements', () => {
    const result = parseJson('[1, 2, 3]');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonArray);
    const arrNode = result.cst as JsonArray;
    expect(arrNode.elements).toHaveLength(3);
  });

  it('parses empty JSON object', () => {
    const result = parseJson('{}');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonObject);
    const objNode = result.cst as JsonObject;
    expect(objNode.members).toHaveLength(0);
  });

  it('parses JSON object with single property', () => {
    const result = parseJson('{"key": 42}');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonObject);
    const objNode = result.cst as JsonObject;
    expect(objNode.members).toHaveLength(1);
  });

  it('parses JSON object with multiple properties', () => {
    const result = parseJson('{"a": 1, "b": 2, "c": 3}');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonObject);
    const objNode = result.cst as JsonObject;
    expect(objNode.members).toHaveLength(3);
  });
});

describe('JSON Parsing - Nested Structures', () => {
  it('parses nested array of arrays', () => {
    const result = parseJson('[[1, 2], [3, 4]]');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonArray);
    const arrNode = result.cst as JsonArray;
    expect(arrNode.elements).toHaveLength(2);
  });

  it('parses nested object in array', () => {
    const result = parseJson('[{"key": "value"}]');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonArray);
    const arrNode = result.cst as JsonArray;
    expect(arrNode.elements).toHaveLength(1);
  });

  it('parses nested array in object', () => {
    const result = parseJson('{"array": [1, 2, 3]}');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonObject);
    const objNode = result.cst as JsonObject;
    expect(objNode.members).toHaveLength(1);
  });

  it('parses complex nested structure', () => {
    const result = parseJson(`{
      "users": [
        {"name": "Alice", "age": 30},
        {"name": "Bob", "age": 25}
      ],
      "active": true
    }`);
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonObject);
  });
});

describe('JSON Parsing - Whitespace Handling', () => {
  it('parses with leading whitespace', () => {
    const result = parseJson('  null');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonNull);
  });

  it('parses with trailing whitespace', () => {
    const result = parseJson('null  ');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonNull);
  });

  it('parses with whitespace around structure', () => {
    const result = parseJson('  {  "key"  :  42  }  ');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonObject);
  });

  it('parses with newlines and tabs', () => {
    const result = parseJson('{\n\t"key": 42\n}');
    expect(result.errors).toHaveLength(0);
    expect(result.cst).toBeInstanceOf(JsonObject);
  });
});

describe('JSON Parsing - Error Cases', () => {
  it('detects incomplete array', () => {
    const result = parseJson('[1, 2');
    expect(result.errors.length).toBeGreaterThan(0);
  });

  it('detects incomplete object', () => {
    const result = parseJson('{"key": "value"');
    expect(result.errors.length).toBeGreaterThan(0);
  });

  it('detects invalid number', () => {
    const result = parseJson('[1, 2.3.4, 5]');
    expect(result.errors.length).toBeGreaterThan(0);
  });

  it('detects missing value', () => {
    const result = parseJson('[1, , 3]');
    expect(result.errors.length).toBeGreaterThan(0);
  });

  it('detects trailing comma in array', () => {
    const result = parseJson('[1, 2, 3,]');
    expect(result.errors.length).toBeGreaterThan(0);
  });

  it('detects missing colon in object', () => {
    const result = parseJson('{"key" 42}');
    expect(result.errors.length).toBeGreaterThan(0);
  });

  it('detects trailing comma in object', () => {
    const result = parseJson('{"key": 42,}');
    expect(result.errors.length).toBeGreaterThan(0);
  });

  it('detects unquoted key', () => {
    const result = parseJson('{key: 42}');
    expect(result.errors.length).toBeGreaterThan(0);
  });
});
