# The Squirrel Parser 🐿️

A fast linear-time PEG packrat parser with full left recursion support and optimal error recovery.

## Features

- Linear-time PEG parsing with memoization
- Full support for left-recursive grammars
- Optimal error recovery with syntax error reporting
- Meta-grammar for defining PEG grammars
- AST and CST construction

See [the paper](../paper/squirrel_parser.pdf) for details on the algorithm, and see [the GitHub repo](https://github.com/lukehutch/squirrelparser) for ports to other languages.

## Requirements

- Dart 3.0+

## Installation

```bash
dart pub add squirrel_parser
```

## Usage

The parser provides three levels of API:

1. **`squirrelParsePT()`** - Returns raw `ParseResult` with full parse tree
2. **`squirrelParseAST()`** - Returns `ASTNode` tree (transparent rules elided)
3. **`squirrelParseCST()`** - Builds custom `CSTNode` tree from AST using factories

```dart
import 'package:squirrel_parser/squirrel_parser.dart';

const grammar = 'Number <- [0-9]+ ;';
const input = '42';

// Option 1: Get raw parse result
final pt = squirrelParsePT(grammarSpec: grammar, topRuleName: 'Number', input: input);

// Option 2: Get abstract syntax tree
final ast = squirrelParseAST(grammarSpec: grammar, topRuleName: 'Number', input: input);

// Option 3: Build concrete syntax tree with custom nodes
final cst = squirrelParseCST(grammarSpec: grammar, topRuleName: 'Number',
                            factories: factories, input: input, allowSyntaxErrors: false);
```

## CST Example: Parsing Variable Assignments

This example parses `x=32;y=0x20;` and converts numeric literals to actual integers:

```dart
import 'package:squirrel_parser/squirrel_parser.dart';

// Grammar for variable assignments with decimal and hex numbers
const grammar = r'''
  Assignments <- Assignment+ ;
  Assignment <- Name '=' Number ';' ;
  Name <- [a-zA-Z_][a-zA-Z0-9_]* ;
  Number <- HexNumber / DecNumber ;
  HexNumber <- "0x" [0-9a-fA-F]+ ;
  DecNumber <- [0-9]+ ;
''';

// Custom CST node classes
class AssignmentsNode extends CSTNode {
  final List<AssignmentNode> assignments;
  AssignmentsNode({required super.astNode, required this.assignments})
      : super(children: assignments);
}

class AssignmentNode extends CSTNode {
  final String name;
  final int value;
  AssignmentNode({required super.astNode, required this.name, required this.value})
      : super(children: const []);
}

class NumberNode extends CSTNode {
  final int value;
  NumberNode({required super.astNode, required this.value})
      : super(children: const []);
}

class TerminalNode extends CSTNode {
  TerminalNode({required super.astNode}) : super(children: const []);
}

// Factory map that creates CST nodes (input captured by closure)
Map<String, CSTNodeFactoryFn> createFactories(String input) => {
  'Assignments': (astNode, children) => AssignmentsNode(
        astNode: astNode,
        assignments: children.cast<AssignmentNode>(),
      ),
  'Assignment': (astNode, children) {
    final nameNode = children[0];
    final valueNode = children[1] as NumberNode;
    return AssignmentNode(
      astNode: astNode,
      name: input.substring(nameNode.pos, nameNode.pos + nameNode.len),
      value: valueNode.value,
    );
  },
  'Name': (astNode, children) => TerminalNode(astNode: astNode),
  'Number': (astNode, children) => children.first as NumberNode,
  'HexNumber': (astNode, children) {
    final text = input.substring(astNode.pos, astNode.pos + astNode.len);
    return NumberNode(astNode: astNode, value: int.parse(text.substring(2), radix: 16));
  },
  'DecNumber': (astNode, children) {
    final text = input.substring(astNode.pos, astNode.pos + astNode.len);
    return NumberNode(astNode: astNode, value: int.parse(text));
  },
  '<Terminal>': (astNode, children) => TerminalNode(astNode: astNode),
};

void main() {
  const input = 'x=32;y=0x20;z=255;';

  final cst = squirrelParseCST(
    grammarSpec: grammar,
    topRuleName: 'Assignments',
    factories: createFactories(input),
    input: input,
  ) as AssignmentsNode;

  for (final assignment in cst.assignments) {
    print('${assignment.name} = ${assignment.value}');
  }
  // Output:
  //   x = 32
  //   y = 32   (0x20 parsed as hex)
  //   z = 255
}
```

## Grammar Syntax

| Syntax | Description |
|--------|-------------|
| `Rule <- Expr ;` | Rule definition |
| `~Rule <- Expr ;` | Transparent rule (no AST/CST node) |
| `"text"` | String literal |
| `'c'` | Character literal |
| `[a-z]` | Character class |
| `[^a-z]` | Negated character class |
| `.` | Any character |
| `()` | Nothing (epsilon) |
| `A B` | Sequence |
| `A / B` | Ordered choice |
| `A*` | Zero or more |
| `A+` | One or more |
| `A?` | Optional |
| `&A` | Positive lookahead |
| `!A` | Negative lookahead |
| `(A)` | Grouping |
| `# comment` | Comment |

Escape sequences: `\n`, `\r`, `\t`, `\\`, `\"`, `\'`

## Building

```bash
dart pub get      # Install dependencies
dart test         # Run tests
dart analyze      # Run analysis
```

## License

MIT License - see LICENSE file for details.
