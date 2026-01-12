# Squirrel Parser - TypeScript

A fast linear-time PEG packrat parser with full left recursion support and optimal error recovery.

## Features

- Linear-time PEG parsing with memoization
- Full support for left-recursive grammars
- Optimal error recovery with syntax error reporting
- Meta-grammar for defining PEG grammars
- AST and CST construction

See [the paper](../paper/squirrel_parser.pdf) for details on the algorithm.

## Requirements

- Node.js 18+ or Bun
- TypeScript 5.0+

## Installation

```bash
npm install
```

## Building

```bash
npm run build
```

## Testing

```bash
npm test
```

## Usage

The parser provides three levels of API:

1. **`squirrelParsePT()`** - Returns raw `ParseResult` with full parse tree
2. **`squirrelParseAST()`** - Returns `ASTNode` tree (transparent rules elided)
3. **`squirrelParseCST()`** - Builds custom `CSTNode` tree from AST using factories

```typescript
import { squirrelParsePT, squirrelParseAST, squirrelParseCST } from 'squirrel-parser';

const grammar = 'Number <- [0-9]+ ;';
const input = '42';

// Option 1: Get raw parse result
const pt = squirrelParsePT({ grammarSpec: grammar, topRuleName: 'Number', input });

// Option 2: Get abstract syntax tree
const ast = squirrelParseAST({ grammarSpec: grammar, topRuleName: 'Number', input });

// Option 3: Build concrete syntax tree with custom nodes
const cst = squirrelParseCST({ grammarSpec: grammar, topRuleName: 'Number',
                               factories, input, allowSyntaxErrors: false });
```

## CST Example: Parsing Variable Assignments

This example parses `x=32;y=0x20;` and converts numeric literals to actual integers:

```typescript
import { ASTNode, CSTNode, CSTNodeFactory, squirrelParseCST } from 'squirrel-parser';

// Grammar for variable assignments with decimal and hex numbers
const GRAMMAR = `
    Assignments <- Assignment+ ;
    Assignment <- Name '=' Number ';' ;
    Name <- [a-zA-Z_][a-zA-Z0-9_]* ;
    Number <- HexNumber / DecNumber ;
    HexNumber <- "0x" [0-9a-fA-F]+ ;
    DecNumber <- [0-9]+ ;
`;

// Custom CST node classes
class AssignmentsNode extends CSTNode {
  readonly assignments: AssignmentNode[];
  constructor(astNode: ASTNode, children: readonly CSTNode[]) {
    super(astNode, children);
    this.assignments = children.filter((c): c is AssignmentNode => c instanceof AssignmentNode);
  }
}

class AssignmentNode extends CSTNode {
  constructor(
    astNode: ASTNode,
    readonly name: string,
    readonly value: number,
  ) {
    super(astNode, []);
  }
}

class NumberNode extends CSTNode {
  constructor(
    astNode: ASTNode,
    readonly value: number,
  ) {
    super(astNode, []);
  }
}

class TerminalNode extends CSTNode {
  constructor(astNode: ASTNode) {
    super(astNode, []);
  }
}

// Factory functions that parse values during CST construction
function createFactories(input: string): CSTNodeFactory[] {
  return [
    {
      ruleName: 'Assignments',
      factory: (astNode, children) => new AssignmentsNode(astNode, children),
    },
    {
      ruleName: 'Assignment',
      factory: (astNode, children) => {
        const nameNode = children[0];
        const valueNode = children[1] as NumberNode;
        const name = input.substring(nameNode.pos, nameNode.pos + nameNode.len);
        return new AssignmentNode(astNode, name, valueNode.value);
      },
    },
    {
      ruleName: 'Name',
      factory: (astNode) => new TerminalNode(astNode),
    },
    {
      ruleName: 'Number',
      factory: (_, children) => children[0] as NumberNode,
    },
    {
      ruleName: 'HexNumber',
      factory: (astNode) => {
        const text = input.substring(astNode.pos, astNode.pos + astNode.len);
        return new NumberNode(astNode, parseInt(text.substring(2), 16));
      },
    },
    {
      ruleName: 'DecNumber',
      factory: (astNode) => {
        const text = input.substring(astNode.pos, astNode.pos + astNode.len);
        return new NumberNode(astNode, parseInt(text, 10));
      },
    },
    {
      ruleName: '<Terminal>',
      factory: (astNode) => new TerminalNode(astNode),
    },
  ];
}

// Main
const input = 'x=32;y=0x20;z=255;';

const cst = squirrelParseCST({
  grammarSpec: GRAMMAR,
  topRuleName: 'Assignments',
  factories: createFactories(input),
  input,
}) as AssignmentsNode;

for (const assignment of cst.assignments) {
  console.log(`${assignment.name} = ${assignment.value}`);
}
// Output:
//   x = 32
//   y = 32   (0x20 parsed as hex)
//   z = 255
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

## License

MIT License - see LICENSE file for details.
