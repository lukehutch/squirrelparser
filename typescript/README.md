# The Squirrel Parser 🐿️

This is the **TypeScript** implementation of the squirrel parser: a fast linear-time PEG packrat parser capable of handling all forms of left recursion, with optimal error recovery.

The squirrel parser handles all forms of left recursion, including cases of multiple interwoven direct or indirect left recursive cycles, and preserves perfect linear performance in the length of the input regardless of the number of syntax errors encountered: both parsing and error recovery have linear performance.

See the details on the derivation of the squirrel parsing algorithm in [the paper](../paper/squirrel_parser.pdf).

## Usage

The Squirrel Parser uses a **Concrete Syntax Tree (CST)** approach with custom factory functions. This allows you to build exactly the data structure you need from the parse tree.

### Key Concept: Transparent Rules

In the Squirrel Parser grammar, rules prefixed with `~` are **transparent** and don't create CST nodes:

```typescript
const grammar = `
  ~_ <- [ \t\n\r]*;  // Transparent: won't create a CST node
  ~Whitespace <- ' '+;      // Transparent: won't create a CST node
  Number <- [0-9]+;         // Non-transparent: will create a CST node
  Expr <- Number ('+' Number)*;  // Non-transparent: will create a CST node
`;
```

**Important**: You only need to create factories for **non-transparent** grammar rules. Transparent rules are automatically excluded from factory requirements. If you accidentally create a factory for a transparent rule, an exception will be thrown.

### Basic Example with CST

```typescript
import {
  squirrelParse,
  CSTNode,
  CSTNodeFactory,
  type SyntaxError,
} from 'squirrelparser';

// 1. Define your grammar using PEG metagrammar syntax
// Note: Operators are named rules (AddOp, MulOp) so we can capture which operator was used
const grammar = `
  Expr   <- Term (AddOp Term)*;
  Term   <- Factor (MulOp Factor)*;
  Factor <- Number / '(' Expr ')';
  Number <- [0-9]+;
  AddOp  <- '+' / '-';
  MulOp  <- '*' / '/';
  ~_ <- [ \t\n\r]*;
`;

// 2. Define custom CST node classes for each concrete syntax element type
// (we'll just create a generic one here for simplicity)
class CalcNode extends CSTNode {
  children: CalcNode[];
  value?: number;

  constructor(
    name: string,
    children: CalcNode[] = [],
    value?: number
  ) {
    super(name);
    this.children = children;
    this.value = value;
  }

  override toString(): string {
    return this.value !== undefined ? this.value.toString() : this.name;
  }
}

// 3. Create factories for each NON-TRANSPARENT grammar rule
// Note: factories should be in the same order as the grammar rules are defined
const factories = [
  new CSTNodeFactory<CalcNode>(
    'Expr',
    (ruleName, children) => {
      return new CalcNode(ruleName, children as CalcNode[]);
    }
  ),
  new CSTNodeFactory<CalcNode>(
    'Term',
    (ruleName, children) => {
      return new CalcNode(ruleName, children as CalcNode[]);
    }
  ),
  new CSTNodeFactory<CalcNode>(
    'Factor',
    (ruleName, children) => {
      return new CalcNode(ruleName, children as CalcNode[]);
    }
  ),
  new CSTNodeFactory<CalcNode>(
    'Number',
    (ruleName, children) => {
      const value = children.length > 0 ? parseInt(children[0].toString()) : 0;
      return new CalcNode(ruleName, [], value);
    }
  ),
  new CSTNodeFactory<CalcNode>(
    'AddOp',
    (ruleName, children) => {
      // Capture the operator symbol
      return new CalcNode(ruleName, children as CalcNode[]);
    }
  ),
  new CSTNodeFactory<CalcNode>(
    'MulOp',
    (ruleName, children) => {
      // Capture the operator symbol
      return new CalcNode(ruleName, children as CalcNode[]);
    }
  ),
];

// 4. Parse input and get the CST
const [cst, errors] = squirrelParse(grammar, "Expr", factories, "2+3*4");

if (errors.length === 0) {
  console.log('Parse successful!');
  console.log(`CST root: ${cst.name}`);
} else {
  console.log('Syntax errors:');
  for (const error of errors) {
    console.log(`  ${error.toString()}`);
  }
}
```

### Understanding CST Factories

Each **non-transparent** grammar rule needs a corresponding factory. The factory function receives:

- **ruleName**: The name of the grammar rule
- **children**: The actual CST child nodes built from the parse tree

The expected children are automatically derived from the grammar:

```typescript
new CSTNodeFactory<MyNode>(
  'RuleName',
  (ruleName, children) => {
    // Build and return your custom node
    return new MyNode(ruleName, children);
  }
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

Transparent rules (prefixed with `~`) don't create CST nodes and are excluded from factory requirements.

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

```typescript
import {
  squirrelParse,
  CSTNode,
  CSTNodeFactory,
} from 'squirrelparser';

// Custom CST node for JSON
class JsonNode extends CSTNode {
  value: unknown;
  children: JsonNode[];

  constructor(name: string, children: JsonNode[] = [], value: unknown = null) {
    super(name);
    this.children = children;
    this.value = value;
  }
}

const jsonGrammar = `
JSON <- _ Value _ ;
Value <- Object / Array / String / Number / Boolean / Null ;

Object <- '{' _ (Pair (',' _ Pair)*)? _ '}' ;
Pair <- String _ ':' _ Value ;

Array <- '[' _ (Value (',' _ Value)*)? _ ']' ;

String <- '"' StringChar* '"' ;
~StringChar <- [^"\\\\] / '\\\\' . ;

Number <- '-'? [0-9]+ ('.' [0-9]+)? ;

Boolean <- "true" / "false" ;
Null <- "null" ;

~_ <- [ \t\n\r]* ;
`;

// CST factories
const factories = [
  new CSTNodeFactory<JsonNode>(
    'JSON',
    (ruleName, children) => {
      return new JsonNode(
        ruleName,
        children as JsonNode[],
        children.length > 0 ? (children[0] as JsonNode).value : null
      );
    }
  ),
  new CSTNodeFactory<JsonNode>(
    'Value',
    (ruleName, children) => {
      return new JsonNode(
        ruleName,
        children as JsonNode[],
        children.length > 0 ? (children[0] as JsonNode).value : null
      );
    }
  ),
  // ... factories for other rules ...
];

// Parse JSON
const jsonInput = "{\"name\": \"Alice\", \"age\": 30}";
const [cst, errors] = squirrelParse(jsonGrammar, "JSON", factories, jsonInput);

if (errors.length === 0) {
  console.log('JSON parsed successfully');
} else {
  for (const error of errors) {
    console.log(`Error: ${error.toString()}`);
  }
}
```

## Error Handling

### Factory Validation Errors

```typescript
import {
  squirrelParse,
  CSTFactoryValidationException,
  DuplicateRuleNameException,
  CSTConstructionException,
} from 'squirrelparser';

// grammar, input, and factories are defined in the basic example above

try {
  const [cst, errors] = squirrelParse(grammar, "Rule", factories, input);
} catch (e) {
  if (e instanceof CSTFactoryValidationException) {
    console.log('Missing factories:', e.missing);
    console.log('Extra factories:', e.extra);
  } else if (e instanceof DuplicateRuleNameException) {
    console.log(`Duplicate rule name: ${e.ruleName} (appears ${e.count} times)`);
  } else if (e instanceof CSTConstructionException) {
    console.log(`CST construction failed: ${e.message}`);
  }
}
```

### Syntax Errors

The parser returns syntax errors separately from the CST:

```typescript
// grammar, input, and factories are defined in the basic example above

const [cst, syntaxErrors] = squirrelParse(grammar, "Rule", factories, input);

if (syntaxErrors.length > 0) {
  console.log('Syntax errors found:');
  for (const error of syntaxErrors) {
    console.log(`  ${error.toString()}`);
  }
}
```

### CST Node Composition and Error Handling

The CST (Concrete Syntax Tree) returned by `squirrelParse()` is **guaranteed to be non-null** and will consist of:

1. **CSTNode instances** - Created from your factory function invocations for successfully parsed grammar rules
2. **CSTSyntaxErrorNode instances** - Created for syntax errors encountered and recovered during parsing

#### Understanding CSTSyntaxErrorNode

Syntax error nodes appear in the CST in two cases:

- **Rule Deletions**: When the parser skips a grammar rule to recover from an error (e.g., skipping a sequence subclause)
- **Input Insertions**: When the parser skips extra input characters that don't match the expected grammar (e.g., spurious input between grammar elements)

#### Important: Variable Child Arity

**In sequences (Seq clauses), the number of child nodes may exceed the number of grammar subclauses** when insertions occur. For example, if you have a grammar rule `Rule <- "a" "b" "c"` (3 subclauses), the parse tree might contain 4 children if extra input was skipped and recovered:

```
children[0] = Match for "a"
children[1] = SyntaxErrorNode for inserted input
children[2] = Match for "b"
children[3] = Match for "c"
```

#### Recommendations for Factory Functions

Your factory functions should be prepared to handle:

1. **Variable child count** - Don't assume `children.length` equals the number of grammar subclauses
2. **Mixed node types** - Children may be regular CSTNode instances OR CSTSyntaxErrorNode instances
3. **Defensive checks** - Inspect both the type and arity of children:

```typescript
new CSTNodeFactory<MyNode>(
  "MyRule",
  (ruleName, children) => {
    // Check both count and types
    let validChildren = 0;
    for (const child of children) {
      // Check if it's a syntax error node
      if (child instanceof CSTSyntaxErrorNode) {
        // Handle error node
        console.log(`Error at: ${(child as CSTSyntaxErrorNode).pos}`);
      } else {
        // Count regular nodes
        validChildren++;
      }
    }
    // Use validChildren or handle the error nodes appropriately
    return new MyNode(ruleName, children as MyNode[]);
  }
)
```

The CST structure faithfully represents both the successful matches and the error recovery points, giving you complete visibility into what the parser encountered.

### Defining Custom Node Classes

Your CST node classes should capture the semantic information you need:

```typescript
class MyNode extends CSTNode {
  children: MyNode[];
  value?: string;

  constructor(name: string, children: MyNode[] = [], value?: string) {
    super(name);
    this.children = children;
    this.value = value;
  }
}
```

### Using Transparent Rules for Whitespace

Use transparent rules to handle whitespace and other structural elements:

```typescript
const grammar = `
  ~_ <- [ \t\n\r]* ;
  Expression <- Term (_ ('+' / '-') _ Term)* ;
  Term <- Factor (_ ('*' / '/') _ Factor)* ;
  Factor <- Number / '(' _ Expression _ ')' ;
  Number <- [0-9]+ ;
`;

// You only need factories for Expression, Term, Factor, and Number
// NOT for _ (which is transparent)
```

### Factory Functions Can Validate Input

You can perform validation within your factory functions:

```typescript
new CSTNodeFactory<MyNode>(
  'MyRule',
  (ruleName, children) => {
    if (children.length === 0) {
      throw new CSTConstructionException(`${ruleName} requires children`);
    }
    return new MyNode(ruleName, children);
  }
)
```

### Handling Terminal Nodes

Terminal rules (which match literal text or character classes) use `'<Terminal>'` in the `childRuleNames`:

```typescript
// Terminals use '<Terminal>' to indicate a terminal child
new CSTNodeFactory<MyNode>(
  'Number',
  (ruleName, children) => {
    // Extract raw text from terminal
    const value = children.length > 0 ? children[0].toString() : null;
    return new MyNode(ruleName, [], value);
  }
)
```

## Building

```bash
npm install       # Install dependencies
npm test          # Run tests
npm run build     # Build library
npm run lint      # Run linting
```

## Testing

The implementation includes comprehensive CST tests demonstrating all features.
