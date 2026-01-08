# The Squirrel Parser 🐿️ -- Dart Implementation

This is the Dart implementation of the squirrel parser: a fast linear-time PEG packrat parser capable of handling all forms of left recursion, with optimal error recovery.

The squirrel parser handles all forms of left recursion, including cases of multiple interwoven direct or indirect left recursive cycles, and preserves perfect linear performance in the length of the input regardless of the number of syntax errors encountered: both parsing and error recovery have linear performance.

See the details on the derivation of the squirrel parsing algorithm in [the paper](paper/squirrel_parser.pdf).

## Usage

### With Metagrammar (PEG Syntax) - Recommended

```dart
import 'package:squirrel_parser/squirrel_parser.dart';

// Define grammar using PEG syntax
final grammarStr = """
    number <- [0-9]+
    expr <- expr '+' number / number
    """;

// Parse input with error handling
final (ast, errors) = squirrelParse(grammarStr, "1+2+3", 'expr');

print('AST:');
print(ast.toPrettyString());
if (errors.isNotEmpty) {
  print('Syntax errors found:');
  for (final error in errors) {
    print('  ${error.toString()}');
  }
}
```

### Without Metagrammar (Direct API)

```dart
import 'package:squirrel_parser/squirrel_parser.dart';

// Define grammar rules directly
final rules = <String, Clause>{
  "number": OneOrMore(CharRange('0', '9')),
  "expr": First([
    Seq([Ref("expr"), Str("+"), Ref("number")]),
    Ref("number")
  ])
};
var toprule = "expr";
var input = "1+2+3";

// Parse input
final (ast, syntaxErrors) = squirrelParseWithRuleMap(rules, toprule, input);

if (ast != null) {
  print("AST:");
  print(ast.toPrettyString());
}
if (syntaxErrors.isNotEmpty) {
  print('Syntax errors:');
  for (final error in syntaxErrors) {
    print('  ${error.toString()}');
  }
}
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

Transparent rules (prefixed with `~`) are flattened in the AST.

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

Matches nothing - always succeeds without consuming any input. Useful for optional elements and epsilon productions.

You can use either `∅` or empty parentheses `()` to match Nothing.

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

## Complete Example: JSON Grammar

```dart
import 'package:squirrel_parser/squirrel_parser.dart';

final jsonGrammar = r"""
# JSON Grammar
JSON <- _ Value _ ;
Value <- Object / Array / String / Number / Boolean / Null ;

Object <- '{' _ (Pair (',' _ Pair)*)? _ '}' ;
Pair <- String _ ':' _ Value ;

Array <- '[' _ (Value (',' _ Value)*)? _ ']' ;

String <- '"' StringChar* '"' ;
~StringChar <- [^"\\] / '\\' EscapeChar ;
~EscapeChar <- ["\\/bfnrt] ;

Number <- '-'? [0-9]+ ('.' [0-9]+)? ;

Boolean <- "true" / "false" ;
Null <- "null" ;

~_ <- [ \t\n\r]* ;
"""

// Test with JSON input
final jsonInput = '{"name": "Alice", "age": 30, "active": true}';
final (ast, errors) = squirrelParse(jsonGrammar, jsonInput, 'JSON');

if (ast != null) {
  print("AST:");
  print(ast.toPrettyString());
}
if (errors.isNotEmpty) {
  print('Syntax errors found:');
  for (final error in errors) {
    print('  ${error.toString()}');
  }
}
```

## Example: Calculator with Actions

```dart
import 'package:squirrel_parser/squirrel_parser.dart';

// Define grammar
final calcGrammar = """
Expr <- Term (('+' / '-') Term)* ;
Term <- Factor (('*' / '/') Factor)* ;
Factor <- Number / '(' Expr ')' ;
Number <- [0-9]+ ;
"""

// Parse input and get AST
final (ast, errors) = squirrelParse(calcGrammar, "2+3*4", 'Expr');

// Define evaluation function
double evalAST(ASTNode node) {
  if (node.label == 'Number') {
    return double.parse(node.text);
  } else if (node.label == 'Factor') {
    if (node.children.length == 1) {
      return evalAST(node.children[0]);
    } else { // Parenthesized expression
      return evalAST(node.children[1]);
    }
  } else if (node.label == 'Term') {
    var result = evalAST(node.children[0]);
    var i = 1;
    while (i < node.children.length) {
      final op = node.children[i].text;
      final operand = evalAST(node.children[i + 1]);
      if (op == '*') {
        result *= operand;
      } else if (op == '/') {
        result /= operand;
      }
      i += 2;
    }
    return result;
  } else if (node.label == 'Expr') {
    var result = evalAST(node.children[0]);
    var i = 1;
    while (i < node.children.length) {
      final op = node.children[i].text;
      final operand = evalAST(node.children[i + 1]);
      if (op == '+') {
        result += operand;
      } else if (op == '-') {
        result -= operand;
      }
      i += 2;
    }
    return result;
  } else {
    // Recursively evaluate children
    if (node.children.isNotEmpty) {
      return evalAST(node.children[0]);
    }
    return 0.0;
  }
}

if (ast != null) {
  final result = evalAST(ast);
  print("Result: $result"); // Output: Result: 14.0
}
if (errors.isNotEmpty) {
  print('Syntax errors found:');
  for (final error in errors) {
    print('  ${error.toString()}');
  }
}
```

## Error Handling

```dart
import 'package:squirrel_parser/squirrel_parser.dart';

try {
  final rules = MetaGrammar.parseGrammar(grammarText);
} catch (e) {
  print("Grammar parse error: $e");
}
```

## Tips

1. **Use Transparent Rules** for whitespace and other structural elements you don't want in the AST -- prefix the rule name with `~` and no AST node will be created when the rule matches:
   ```
   ~_ <- [ \t\n\r]* ;
   ```

2. **Add Comments** to document your grammar:
   ```
   # This rule matches identifiers
   Identifier <- [a-zA-Z_][a-zA-Z0-9_]* ;
   ```

3. **Handle Whitespace Explicitly** where needed:
   ```
   # Require whitespace between tokens
   Statement <- Keyword _ Identifier ;

   # Optional whitespace
   Expression <- Term (_ ('+' / '-') _ Term)* ;
   ```

## Debugging

Use `toPrettyString()` to visualize the AST:

```dart
final (ast, _) = parser.parseToAST('Expression');
if (ast != null) {
  print(ast.toPrettyString());
}
```

This will show the hierarchical structure of your parsed input.

## Building

```bash
dart pub get      # Install dependencies
dart test         # Run tests
```