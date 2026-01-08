# The Squirrel Parser 🐿️ -- Python Implementation

This is the Python implementation of the squirrel parser: a fast linear-time PEG packrat parser capable of handling all forms of left recursion, with optimal error recovery.

The squirrel parser handles all forms of left recursion, including cases of multiple interwoven direct or indirect left recursive cycles, and preserves perfect linear performance in the length of the input regardless of the number of syntax errors encountered: both parsing and error recovery have linear performance.

See the details on the derivation of the squirrel parsing algorithm in [the paper](paper/squirrel_parser.pdf).

## Usage

### With Metagrammar (PEG Syntax) - Recommended

```python
from squirrelparser import squirrel_parse

# Define grammar using PEG syntax
grammar_str = """
number <- [0-9]+
expr <- expr '+' number / number
"""

# Parse input with error handling
ast, errors = squirrel_parse(grammar_str, '1+2+3', 'expr')

print('AST:')
print(ast.to_pretty_string())
if errors:
    print('Syntax errors found:')
    for error in errors:
        print(f'  {error}')
```

### Without Metagrammar (Direct API)

```python
from squirrelparser import *

# Define grammar rules directly
rules = {
    'number': OneOrMore(CharRange('0', '9')),
    'expr': First([
        Seq([Ref('expr'), Str('+'), Ref('number')]),
        Ref('number')
    ])
}

# Parse input
ast, errors = squirrel_parse_with_rule_map(rules, 'expr', '1+2+3')

if ast:
    print("AST:")
    print(ast.to_pretty_string())
if errors:
    print('Syntax errors found:')
    for error in errors:
        print(f'  {error}')
```

## Grammar Syntax Reference

### Rules

```
RuleName <- Expression ;
```

Rules are defined with a name, followed by `<-`, then an expression, ending with `;

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

```python
from squirrelparser import squirrel_parse

json_grammar = """
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

# Test with JSON input
json_input = '{"name": "Alice", "age": 30, "active": true}'
ast, errors = squirrel_parse(json_grammar, json_input, 'JSON')

if ast:
    print("AST:")
    print(ast.to_pretty_string())
if errors:
    print('Syntax errors found:')
    for error in errors:
        print(f'  {error}')
```

## Example: Calculator with Actions

```python
from squirrelparser import squirrel_parse, ASTNode

# Define grammar
calc_grammar = """
Expr <- Term (('+' / '-') Term)* ;
Term <- Factor (('*' / '/') Factor)* ;
Factor <- Number / '(' Expr ')' ;
Number <- [0-9]+ ;
"""

# Parse input and get AST
ast, errors = squirrel_parse(calc_grammar, "2+3*4", 'Expr')

# Define evaluation function
def eval_ast(node: ASTNode) -> float:
    if node.label == 'Number':
        return float(node.text)
    elif node.label == 'Factor':
        if len(node.children) == 1:
            return eval_ast(node.children[0])
        else:  # Parenthesized expression
            return eval_ast(node.children[1])
    elif node.label == 'Term':
        result = eval_ast(node.children[0])
        i = 1
        while i < len(node.children):
            op = node.children[i].text
            operand = eval_ast(node.children[i + 1])
            if op == '*':
                result *= operand
            elif op == '/':
                result /= operand
            i += 2
        return result
    elif node.label == 'Expr':
        result = eval_ast(node.children[0])
        i = 1
        while i < len(node.children):
            op = node.children[i].text
            operand = eval_ast(node.children[i + 1])
            if op == '+':
                result += operand
            elif op == '-':
                result -= operand
            i += 2
        return result
    else:
        # Recursively evaluate children
        if node.children:
            return eval_ast(node.children[0])
        return 0

if ast:
    result = eval_ast(ast)
    print(f"Result: {result}")  # Output: Result: 14.0
if errors:
    print('Syntax errors found:')
    for error in errors:
        print(f'  {error}')
```

## Error Handling

```python
from squirrelparser import MetaGrammar

try:
    rules = MetaGrammar.parse_grammar(grammar_text)
except ValueError as e:
    print(f"Grammar parse error: {e}")
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

Use `to_pretty_string()` to visualize the AST:

```python
ast, _ = parser.parse_to_ast('Expression')
if ast:
    print(ast.to_pretty_string())
```

This will show the hierarchical structure of your parsed input.

## Installation

```bash
pip install -e .    # Install in development mode
pytest              # Run tests
```