# Squirrel Parser - Python

A fast linear-time PEG packrat parser with full left recursion support and optimal error recovery.

## Features

- Linear-time PEG parsing with memoization
- Full support for left-recursive grammars
- Optimal error recovery with syntax error reporting
- Meta-grammar for defining PEG grammars
- AST and CST construction

See [the paper](../paper/squirrel_parser.pdf) for details on the algorithm.

## Requirements

- Python 3.12+

## Installation

```bash
pip install -e .
```

## Testing

```bash
pip install -e ".[dev]"
pytest
```

## Usage

The parser provides three levels of API:

1. **`squirrel_parse_pt()`** - Returns raw `ParseResult` with full parse tree
2. **`squirrel_parse_ast()`** - Returns `ASTNode` tree (transparent rules elided)
3. **`squirrel_parse_cst()`** - Builds custom `CSTNode` tree from AST using factories

```python
from squirrelparser import squirrel_parse_pt, squirrel_parse_ast, squirrel_parse_cst

grammar = 'Number <- [0-9]+ ;'
input_str = '42'

# Option 1: Get raw parse result
pt = squirrel_parse_pt(grammar_spec=grammar, top_rule_name='Number', input=input_str)

# Option 2: Get abstract syntax tree
ast = squirrel_parse_ast(grammar_spec=grammar, top_rule_name='Number', input=input_str)

# Option 3: Build concrete syntax tree with custom nodes
cst = squirrel_parse_cst(grammar_spec=grammar, top_rule_name='Number',
                         factories=factories, input=input_str, allow_syntax_errors=false)
```

## CST Example: Parsing Variable Assignments

This example parses `x=32;y=0x20;` and converts numeric literals to actual integers:

```python
from squirrelparser import CSTNode, CSTNodeFactoryFn, ASTNode, squirrel_parse_cst

# Grammar for variable assignments with decimal and hex numbers
GRAMMAR = r'''
    Assignments <- Assignment+ ;
    Assignment <- Name '=' Number ';' ;
    Name <- [a-zA-Z_][a-zA-Z0-9_]* ;
    Number <- HexNumber / DecNumber ;
    HexNumber <- "0x" [0-9a-fA-F]+ ;
    DecNumber <- [0-9]+ ;
'''


# Custom CST node classes
class AssignmentsNode(CSTNode):
    def __init__(self, ast_node: ASTNode, children: list[CSTNode]) -> None:
        super().__init__(ast_node, children)
        self.assignments: list[AssignmentNode] = [
            c for c in children if isinstance(c, AssignmentNode)
        ]


class AssignmentNode(CSTNode):
    def __init__(self, ast_node: ASTNode, name: str, value: int) -> None:
        super().__init__(ast_node, [])
        self.name = name
        self.value = value


class NumberNode(CSTNode):
    def __init__(self, ast_node: ASTNode, value: int) -> None:
        super().__init__(ast_node, [])
        self.value = value


class TerminalNode(CSTNode):
    def __init__(self, ast_node: ASTNode) -> None:
        super().__init__(ast_node, [])


# Factory map that creates CST nodes (input_str captured by closure)
def create_factories(input_str: str) -> dict[str, CSTNodeFactoryFn]:
    return {
        'Assignments': lambda ast_node, children: AssignmentsNode(ast_node, children),
        'Assignment': lambda ast_node, children: AssignmentNode(
            ast_node,
            name=input_str[children[0].pos:children[0].pos + children[0].len],
            value=children[1].value,  # type: ignore
        ),
        'Name': lambda ast_node, children: TerminalNode(ast_node),
        'Number': lambda ast_node, children: children[0],  # type: ignore
        'HexNumber': lambda ast_node, children: NumberNode(
            ast_node, int(input_str[ast_node.pos:ast_node.pos + ast_node.len][2:], 16)
        ),
        'DecNumber': lambda ast_node, children: NumberNode(
            ast_node, int(input_str[ast_node.pos:ast_node.pos + ast_node.len])
        ),
        '<Terminal>': lambda ast_node, children: TerminalNode(ast_node),
    }


if __name__ == '__main__':
    input_str = 'x=32;y=0x20;z=255;'

    cst = squirrel_parse_cst(
        grammar_spec=GRAMMAR,
        top_rule_name='Assignments',
        factories=create_factories(input_str),
        input=input_str,
    )

    for assignment in cst.assignments:  # type: ignore
        print(f'{assignment.name} = {assignment.value}')
    # Output:
    #   x = 32
    #   y = 32   (0x20 parsed as hex)
    #   z = 255
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
