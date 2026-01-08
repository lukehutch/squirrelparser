# The Squirrel Parser 🐿️ -- TypeScript Implementation

This is the Typescript implementation of the squirrel parser: a fast linear-time PEG packrat parser capable of handling all forms of left recursion, with optimal error recovery.

The squirrel parser handles all forms of left recursion, including cases of multiple interwoven direct or indirect left recursive cycles, and preserves perfect linear performance in the length of the input regardless of the number of syntax errors encountered: both parsing and error recovery have linear performance.

See the details on the derivation of the squirrel parsing algorithm in [the paper](paper/squirrel_parser.pdf).

## Usage

### With Metagrammar (PEG Syntax) - Recommended

```typescript
import { MetaGrammar, squirrelParse } from 'squirrelparser';

// Define grammar using PEG syntax
const grammarStr = `
  number <- [0-9]+
  expr <- expr '+' number / number
`;

// Parse input with error handling
const [ast, errors] = squirrelParse(grammarStr, '1+2+3', 'expr');

console.log('AST:');
console.log(ast.toPrettyString());
if (errors.length > 0) {
  console.log('Syntax errors found:');
  for (const error of errors) {
    console.log(`  ${error.toString()}`);
  }
}
```

### Without Metagrammar (Direct API)

```typescript
import { squirrelParseWithRuleMap, Str, CharRange, Ref, Seq, First, OneOrMore } from 'squirrelparser';

// Define grammar rules directly
const rules = {
  number: new OneOrMore(new CharRange('0', '9')),
  expr: new First([
    new Seq([new Ref('expr'), new Str('+'), new Ref('number')],
    new Ref('number')
  ])
};

// Parse input
const [ast, errors] = squirrelParseWithRuleMap(rules, 'expr', '1+2+3');

if (ast) {
  console.log('AST:');
  console.log(ast.toPrettyString());
}
if (errors.length > 0) {
  console.log('Syntax errors found:');
  for (const error of errors) {
    console.log(`  ${error.toString()}`);
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

```typescript
import { squirrelParse } from 'squirrelparser';

const jsonGrammar = `
# JSON Grammar
JSON <- _ Value _ ;
Value <- Object / Array / String / Number / Boolean / Null ;

Object <- '{' _ (Pair (',' _ Pair)*)? _ '}' ;
Pair <- String _ ':' _ Value ;

Array <- '[' _ (Value (',' _ Value)*)? _ ']' ;

String <- '"' StringChar* '"' ;
~StringChar <- [^"\\] / '\\\' EscapeChar ;
~EscapeChar <- ["\\/bfnrt] ;

Number <- '-'? [0-9]+ ('.' [0-9]+)? ;

Boolean <- "true" / "false" ;
Null <- "null" ;

~_ <- [ \t\n\r]* ;
`;

// Test with JSON input
const jsonInput = '{"name": "Alice", "age": 30, "active": true}';
const [ast, errors] = squirrelParse(jsonGrammar, jsonInput, 'JSON');

if (ast) {
  console.log("AST:");
  console.log(ast.toPrettyString());
}
if (errors.length > 0) {
  console.log('Syntax errors found:');
  for (const error of errors) {
    console.log(`  ${error.toString()}`);
  }
}
```

## Example: Calculator with Actions

```typescript
import { squirrelParse, ASTNode } from 'squirrelparser';

// Define grammar
const calcGrammar = `
Expr <- Term (('+' / '-') Term)* ;
Term <- Factor (('*' / '/') Factor)* ;
Factor <- Number / '(' Expr ')' ;
Number <- [0-9]+ ;
`;

// Parse input and get AST
const [ast, errors] = squirrelParse(calcGrammar, "2+3*4", 'Expr');

// Define evaluation function
function evalAST(node: ASTNode): number {
  if (node.label === 'Number') {
    return parseFloat(node.text);
  } else if (node.label === 'Factor') {
    if (node.children.length === 1) {
      return evalAST(node.children[0]);
    } else { // Parenthesized expression
      return evalAST(node.children[1]);
    }
  } else if (node.label === 'Term') {
    let result = evalAST(node.children[0]);
    let i = 1;
    while (i < node.children.length) {
      const op = node.children[i].text;
      const operand = evalAST(node.children[i + 1]);
      if (op === '*') {
        result *= operand;
      } else if (op === '/') {
        result /= operand;
      }
      i += 2;
    }
    return result;
  } else if (node.label === 'Expr') {
    let result = evalAST(node.children[0]);
    let i = 1;
    while (i < node.children.length) {
      const op = node.children[i].text;
      const operand = evalAST(node.children[i + 1]);
      if (op === '+') {
        result += operand;
      } else if (op === '-') {
        result -= operand;
      }
      i += 2;
    }
    return result;
  } else {
    // Recursively evaluate children
    if (node.children.length > 0) {
      return evalAST(node.children[0]);
    }
    return 0;
  }
}

if (ast) {
  const result = evalAST(ast);
  console.log(`Result: ${result}`); // Output: Result: 14
}
if (errors.length > 0) {
  console.log('Syntax errors found:');
  for (const error of errors) {
    console.log(`  ${error.toString()}`);
  }
}
```

## Error Handling

```typescript
import { MetaGrammar } from 'squirrelparser';

try {
  const rules = MetaGrammar.parseGrammar(grammarText);
} catch (e) {
  console.log("Grammar parse error:", e);
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

```typescript
const [ast, _] = parser.parseToAST('Expression');
if (ast) {
  console.log(ast.toPrettyString());
}
```

This will show the hierarchical structure of your parsed input.

## Building

```bash
npm install       # Install dependencies
npm test          # Run tests
npm run build     # Build library
```