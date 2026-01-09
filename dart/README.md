# The Squirrel Parser 🐿️

This is the **Dart** implementation of the squirrel parser: a fast linear-time PEG packrat parser capable of handling all forms of left recursion, with optimal error recovery.

The squirrel parser handles all forms of left recursion, including cases of multiple interwoven direct or indirect left recursive cycles, and preserves perfect linear performance in the length of the input regardless of the number of syntax errors encountered: both parsing and error recovery have linear performance.

See the details on the derivation of the squirrel parsing algorithm in [the paper](../paper/squirrel_parser.pdf).

## Usage

The Squirrel Parser uses a **Concrete Syntax Tree (CST)** approach with custom factory functions. This allows you to build exactly the data structure you need from the parse tree.

### Key Concept: Transparent Rules

In the Squirrel Parser grammar, rules prefixed with `~` are **transparent** and don't create CST nodes:

```dart
final grammar = '''
  ~_ <- [ \t\n\r]*;        // Transparent: won't create a CST node
  ~Whitespace <- ' '+;      // Transparent: won't create a CST node
  Number <- [0-9]+;         // Non-transparent: will create a CST node
  Expr <- Number ('+' Number)*;  // Non-transparent: will create a CST node
''';
```

**Important**: You only need to create factories for **non-transparent** grammar rules. Transparent rules are automatically excluded from factory requirements. In the example above, you would only need factories for `Number` and `Expr`, not for `_` or `Whitespace`.

### Basic Example with CST

```dart
import 'package:squirrel_parser/squirrel_parser.dart';

// 1. Define your grammar using PEG metagrammar syntax
// Note: Operators are named rules (AddOp, MulOp) so we can capture which operator was used
final grammar = '''
  Expr   <- Term (AddOp Term)*;
  Term   <- Factor (MulOp Factor)*;
  Factor <- Number / '(' Expr ')';
  Number <- [0-9]+;
  AddOp  <- '+' / '-';
  MulOp  <- '*' / '/';
  ~_ <- [ \t\n\r]*;
''';

// 2. Define custom CST node classes for each concrete syntax element type
// (we'll just create a generic one here for simplicity)
class CalcNode extends CSTNode {
  final List<CalcNode> children;
  final int? value;

  CalcNode({
    required super.name,
    required this.children,
    this.value,
  });

  @override
  String toString() => value != null ? value.toString() : name;
}

// 3. Create factories for each NON-TRANSPARENT grammar rule
// Note: factories should be in the same order as the grammar rules are defined
final factories = [
  CSTNodeFactory<CalcNode>(
    ruleName: 'Expr',
    expectedChildren: ['Term', 'AddOp'],
    factory: (ruleName, expectedChildren, children) {
      return CalcNode(name: ruleName, children: children);
    },
  ),
  CSTNodeFactory<CalcNode>(
    ruleName: 'Term',
    expectedChildren: ['Factor', 'MulOp'],
    factory: (ruleName, expectedChildren, children) {
      return CalcNode(name: ruleName, children: children);
    },
  ),
  CSTNodeFactory<CalcNode>(
    ruleName: 'Factor',
    expectedChildren: ['Number', 'Expr'],
    factory: (ruleName, expectedChildren, children) {
      return CalcNode(name: ruleName, children: children);
    },
  ),
  CSTNodeFactory<CalcNode>(
    ruleName: 'Number',
    expectedChildren: ['<Terminal>'],
    factory: (ruleName, expectedChildren, children) {
      return CalcNode(
        name: ruleName,
        children: [],
        value: int.parse(children.isEmpty ? '0' : children[0].toString()),
      );
    },
  ),
  CSTNodeFactory<CalcNode>(
    ruleName: 'AddOp',
    expectedChildren: ['<Terminal>'],
    factory: (ruleName, expectedChildren, children) {
      // Capture the operator symbol
      return CalcNode(name: ruleName, children: children);
    },
  ),
  CSTNodeFactory<CalcNode>(
    ruleName: 'MulOp',
    expectedChildren: ['<Terminal>'],
    factory: (ruleName, expectedChildren, children) {
      // Capture the operator symbol
      return CalcNode(name: ruleName, children: children);
    },
  ),
];

// 4. Parse input and get the CST
final (cst, errors) = squirrelParse(grammar, "2+3*4", 'Expr', factories);

if (errors.isEmpty) {
  print('Parse successful!');
  print('CST root: ${cst.name}');
} else {
  print('Syntax errors:');
  for (final error in errors) {
    print('  ${error.toString()}');
  }
}
```

### Understanding CST Factories

Each non-transparent grammar rule needs a corresponding factory. The factory function receives:

- **ruleName**: The name of the grammar rule
- **expectedChildren**: The expected child rule names (useful for validation)
- **children**: The actual CST child nodes built from the parse tree

```dart
CSTNodeFactory<MyNode>(
  ruleName: 'RuleName',
  expectedChildren: ['Child1', 'Child2'],  // Expected children
  factory: (ruleName, expectedChildren, children) {
    // Build and return your custom node
    return MyNode(name: ruleName, children: children);
  },
)
```

## Grammar Syntax Reference

### Rules

```
RuleName <- Expression ;
```

Rules are defined with a name, followed by `<-`, then an expression, ending with `;`.

### Transparent Rules

```
~RuleName <- Expression ;
```

Transparent rules (prefixed with `~`) don't create CST nodes and don't require factories.

### Sequences

```
Rule <- "a" "b" "c" ;
```

Sequences match expressions in order.

### Choices

```
Rule <- "a" / "b" / "c" ;
```

Choices try alternatives in order, returning the first match.

### Repetition

```
ZeroOrMore <- "a"* ;
OneOrMore <- "a"+ ;
Optional <- "a"? ;
```

### Lookahead

```
PositiveLookahead <- &"a" "b" ;
NegativeLookahead <- !"a" "b" ;
```

Lookahead doesn't consume input.

### Grouping

```
Rule <- ("a" / "b") "c" ;
```

Parentheses control precedence.

### String Literals

```
Rule <- "hello world" ;
```

Double-quoted strings match literal text.

### Character Literals

```
Rule <- 'a' ;
```

Single-quoted characters match a single character.

### Character Classes

```
Digit <- [0-9] ;
Letter <- [a-zA-Z] ;
NotDigit <- [^0-9] ;
```

Character classes match ranges or sets. `^` negates the class.

### Any Character

```
Rule <- . ;
```

Matches any single character.

### Nothing

```
Rule <- ∅ ;
Rule <- () ;
```

Matches nothing - always succeeds without consuming any input. Useful for optional elements and epsilon productions. You can use either `∅` or empty parentheses `()`.

### Escape Sequences

Supported in strings and character literals:
- `\n` - newline
- `\r` - carriage return
- `\t` - tab
- `\\` - backslash
- `\"` - double quote
- `\'` - single quote

### Comments

```
# This is a comment
Rule <- "a" ; # Comments can appear anywhere
```

## Complete Example: JSON Parser with CST

```dart
import 'package:squirrel_parser/squirrel_parser.dart';

// Custom CST node for JSON
class JsonNode extends CSTNode {
  final dynamic value;
  final List<JsonNode> children;

  JsonNode({
    required super.name,
    required this.children,
    this.value,
  });
}

final jsonGrammar = r'''
JSON <- _ Value _ ;
Value <- Object / Array / String / Number / Boolean / Null ;

Object <- '{' _ (Pair (',' _ Pair)*)? _ '}' ;
Pair <- String _ ':' _ Value ;

Array <- '[' _ (Value (',' _ Value)*)? _ ']' ;

String <- '"' StringChar* '"' ;
~StringChar <- [^"\\] / '\\' . ;

Number <- '-'? [0-9]+ ('.' [0-9]+)? ;

Boolean <- "true" / "false" ;
Null <- "null" ;

~_ <- [ \t\n\r]* ;
''';

// CST factories - note: only for non-transparent rules (JSON, Value, Object, etc)
final factories = [
  CSTNodeFactory<JsonNode>(
    ruleName: 'JSON',
    expectedChildren: ['Value'],
    factory: (ruleName, expectedChildren, children) {
      return JsonNode(
        name: ruleName,
        children: children,
        value: children.isNotEmpty ? children[0].value : null,
      );
    },
  ),
  CSTNodeFactory<JsonNode>(
    ruleName: 'Value',
    expectedChildren: ['Object', 'Array', 'String', 'Number', 'Boolean', 'Null'],
    factory: (ruleName, expectedChildren, children) {
      return JsonNode(
        name: ruleName,
        children: children,
        value: children.isNotEmpty ? children[0].value : null,
      );
    },
  ),
  // ... factories for other non-transparent rules ...
];

// Parse JSON
final jsonInput = '{"name": "Alice", "age": 30}';
final (cst, errors) = squirrelParse(jsonGrammar, jsonInput, 'JSON', factories);

if (errors.isEmpty) {
  print('JSON parsed successfully');
} else {
  for (final error in errors) {
    print('Error: ${error.toString()}');
  }
}
```

## Error Handling

### Factory Validation Errors

```dart
try {
  final (cst, errors) = squirrelParse(grammar, input, 'Rule', factories);
} on CSTFactoryValidationException catch (e) {
  print('Missing factories: ${e.missing}');
  print('Extra factories: ${e.extra}');
} on DuplicateRuleNameException catch (e) {
  print('Duplicate rule name: ${e.ruleName} (appears ${e.count} times)');
} on CSTConstructionException catch (e) {
  print('CST construction failed: ${e.message}');
}
```

### Syntax Errors

The parser returns syntax errors separately from the CST:

```dart
final (cst, syntaxErrors) = squirrelParse(grammar, input, 'Rule', factories);

if (syntaxErrors.isNotEmpty) {
  print('Syntax errors found:');
  for (final error in syntaxErrors) {
    print('  ${error.toString()}');
  }
}
```

### Defining Custom Node Classes

Your CST node classes should capture the semantic information you need:

```dart
class MyNode extends CSTNode {
  final List<MyNode> children;
  final String? value;

  MyNode({required super.name, required this.children, this.value});
}
```

### Using Transparent Rules for Whitespace

Use transparent rules to handle whitespace and other structural elements:

```dart
final grammar = '''
  ~_ <- [ \t\n\r]* ;
  Expression <- Term (_ ('+' / '-') _ Term)* ;
  Term <- Factor (_ ('*' / '/') _ Factor)* ;
  Factor <- Number / '(' _ Expression _ ')' ;
  Number <- [0-9]+ ;
''';

// You only need factories for Expression, Term, Factor, and Number
// NOT for _ (which is transparent)
```

### Factory Functions Can Validate Input

You can perform validation within your factory functions:

```dart
CSTNodeFactory<MyNode>(
  ruleName: 'MyRule',
  expectedChildren: ['Child1', 'Child2'],
  factory: (ruleName, expectedChildren, children) {
    if (children.isEmpty) {
      throw CSTConstructionException('$ruleName requires children');
    }
    return MyNode(name: ruleName, children: children);
  },
)
```

### Handling Terminal Nodes

Terminal rules (which match literal text or character classes) have `expectedChildren: ['<Terminal>']`:

```dart
// Terminals have expectedChildren: ['<Terminal>']
CSTNodeFactory<MyNode>(
  ruleName: 'Number',
  expectedChildren: ['<Terminal>'],
  factory: (ruleName, _, children) {
    // Extract raw text from terminal
    return MyNode(
      name: ruleName,
      children: [],
      value: children.isEmpty ? null : children[0].toString(),
    );
  },
)
```

## Building

```bash
dart pub get      # Install dependencies
dart test         # Run tests
dart analyze      # Run analysis
```

## Testing

See `example/cst_calculator_example.dart` for a complete working example of CST-based parsing.
