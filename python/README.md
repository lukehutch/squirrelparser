# The Squirrel Parser 🐿️

This is the **Python** implementation of the squirrel parser: a fast linear-time PEG packrat parser capable of handling all forms of left recursion, with optimal error recovery.

The squirrel parser handles all forms of left recursion, including cases of multiple interwoven direct or indirect left recursive cycles, and preserves perfect linear performance in the length of the input regardless of the number of syntax errors encountered: both parsing and error recovery have linear performance.

See the details on the derivation of the squirrel parsing algorithm in [the paper](../paper/squirrel_parser.pdf).

## Usage

The Squirrel Parser uses a **Concrete Syntax Tree (CST)** approach with custom factory functions. This allows you to build exactly the data structure you need from the parse tree.

### Key Concept: Transparent Rules

In the Squirrel Parser grammar, rules prefixed with `~` are **transparent** and don't create CST nodes:

```python
grammar = """
  ~_ <- [ \t\n\r]*;  # Transparent: won't create a CST node
  ~Whitespace <- ' '+;      # Transparent: won't create a CST node
  Number <- [0-9]+;         # Non-transparent: will create a CST node
  Expr <- Number ('+' Number)*;  # Non-transparent: will create a CST node
"""
```

**Important**: You only need to create factories for **non-transparent** grammar rules. Transparent rules are automatically excluded from factory requirements. If you accidentally create a factory for a transparent rule, an exception will be thrown.

### Basic Example with CST

```python
from squirrelparser import squirrel_parse, CSTNode, CSTNodeFactory

# 1. Define your grammar using PEG metagrammar syntax
# Note: Operators are named rules (AddOp, MulOp) so we can capture which operator was used
grammar = """
  Expr   <- Term (AddOp Term)*;
  Term   <- Factor (MulOp Factor)*;
  Factor <- Number / '(' Expr ')';
  Number <- [0-9]+;
  AddOp  <- '+' / '-';
  MulOp  <- '*' / '/';
  ~_ <- [ \t\n\r]*;
"""

# 2. Define custom CST node classes for each concrete syntax element type
# (we'll just create a generic one here for simplicity)
class CalcNode(CSTNode):
    def __init__(self, name: str, children=None, value=None):
        super().__init__(name)
        self.children = children or []
        self.value = value

    def __str__(self):
        return str(self.value) if self.value is not None else self.name


# 3. Create factories for each NON-TRANSPARENT grammar rule
# Note: factories should be in the same order as the grammar rules are defined
factories = [
    CSTNodeFactory(
        'Expr',
        ['Term', 'AddOp'],
        lambda ruleName, children: CalcNode(ruleName, children),
    ),
    CSTNodeFactory(
        'Term',
        ['Factor', 'MulOp'],
        lambda ruleName, children: CalcNode(ruleName, children),
    ),
    CSTNodeFactory(
        'Factor',
        ['Number', 'Expr'],
        lambda ruleName, children: CalcNode(ruleName, children),
    ),
    CSTNodeFactory(
        'Number',
        ['<Terminal>'],
        lambda ruleName, children: CalcNode(
            ruleName, [], int(children[0].toString()) if children else 0
        ),
    ),
    CSTNodeFactory(
        'AddOp',
        ['<Terminal>'],
        lambda ruleName, children: CalcNode(ruleName, children),
    ),
    CSTNodeFactory(
        'MulOp',
        ['<Terminal>'],
        lambda ruleName, children: CalcNode(ruleName, children),
    ),
]

# 4. Parse input and get the CST
cst, errors = squirrel_parse(grammar, top_rule='Expr', factories=factories, input_str="2+3*4")

if not errors:
    print('Parse successful!')
    print(f'CST root: {cst.name}')
else:
    print('Syntax errors:')
    for error in errors:
        print(f'  {error}')
```

### Understanding CST Factories

Each **non-transparent** grammar rule needs a corresponding factory. The factory function receives:

- **ruleName**: The name of the grammar rule
- **children**: The actual CST child nodes built from the parse tree

Use `'<Terminal>'` in the child rule names list when you expect a terminal (literal string or character class match) as a child, or a rule name when expecting output from another rule.

```python
CSTNodeFactory(
    'RuleName',
    ['Child1', 'Child2'],  # Child rule names (use '<Terminal>' for terminals)
    lambda ruleName, children: MyNode(ruleName, children)
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

```python
from squirrelparser import squirrel_parse, CSTNode, CSTNodeFactory

# Custom CST node for JSON
class JsonNode(CSTNode):
    def __init__(self, name: str, children=None, value=None):
        super().__init__(name)
        self.children = children or []
        self.value = value


json_grammar = """
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
"""

# CST factories
factories = [
    CSTNodeFactory(
        'JSON',
        ['Value'],
        lambda ruleName, children: JsonNode(
            ruleName, children, children[0].value if children else None
        ),
    ),
    CSTNodeFactory(
        'Value',
        ['Object', 'Array', 'String', 'Number', 'Boolean', 'Null'],
        lambda ruleName, children: JsonNode(
            ruleName, children, children[0].value if children else None
        ),
    ),
    # ... factories for other rules ...
]

# Parse JSON
json_input = '{"name": "Alice", "age": 30}'
cst, errors = squirrel_parse(json_grammar, top_rule='JSON', factories=factories, input_str=json_input)

if not errors:
    print('JSON parsed successfully')
else:
    for error in errors:
        print(f'Error: {error}')
```

## Error Handling

### Factory Validation Errors

```python
from squirrelparser import (
    squirrel_parse,
    CSTFactoryValidationException,
    DuplicateRuleNameException,
    CSTConstructionException,
)

# grammar, input_str, and factories are defined in the basic example above

try:
    cst, errors = squirrel_parse(grammar, top_rule='Rule', factories=factories, input_str=input_str)
except CSTFactoryValidationException as e:
    print(f'Missing factories: {e.missing}')
    print(f'Extra factories: {e.extra}')
except DuplicateRuleNameException as e:
    print(f'Duplicate rule name: {e.rule_name} (appears {e.count} times)')
except CSTConstructionException as e:
    print(f'CST construction failed: {e.args[0]}')
```

### Syntax Errors

The parser returns syntax errors separately from the CST:

```python
# grammar, input_str, and factories are defined in the basic example above

cst, syntax_errors = squirrel_parse(grammar, top_rule='Rule', factories=factories, input_str=input_str)

if syntax_errors:
    print('Syntax errors found:')
    for error in syntax_errors:
        print(f'  {error}')
```

### Defining Custom Node Classes

Your CST node classes should capture the semantic information you need:

```python
class MyNode(CSTNode):
    def __init__(self, name: str, children=None, value=None):
        super().__init__(name)
        self.children = children or []
        self.value = value
```

### Using Transparent Rules for Whitespace

Use transparent rules to handle whitespace and other structural elements:

```python
grammar = """
  ~_ <- [ \t\n\r]* ;
  Expression <- Term (_ ('+' / '-') _ Term)* ;
  Term <- Factor (_ ('*' / '/') _ Factor)* ;
  Factor <- Number / '(' _ Expression _ ')' ;
  Number <- [0-9]+ ;
"""

# You only need factories for Expression, Term, Factor, and Number
# NOT for _ (which is transparent)
```

### Factory Functions Can Validate Input

You can perform validation within your factory functions:

```python
CSTNodeFactory(
    'MyRule',
    ['Child1', 'Child2'],
    lambda ruleName, children: (
        MyNode(ruleName, children)
        if children
        else (_ for _ in ()).throw(
            CSTConstructionException(f'{ruleName} requires children')
        )
    )
)
```

### Handling Terminal Nodes

Terminal rules (which match literal text or character classes) use `'<Terminal>'` in the child rule names:

```python
# Terminals use '<Terminal>' to indicate a terminal child
CSTNodeFactory(
    'Number',
    ['<Terminal>'],
    lambda ruleName, children: MyNode(
        ruleName, [], str(children[0]) if children else None
    ),
)
```

## Building

```bash
pip install -e .    # Install in development mode
pytest              # Run tests
mypy                # Run type checking
```

## Testing

The implementation includes comprehensive CST tests demonstrating all features.
