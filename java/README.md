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

- Java 21+
- Maven 3.8+

## Building

```bash
mvn compile
```

## Testing

```bash
mvn test
```

## Usage

The parser provides three levels of API:

1. **`squirrelParsePT()`** - Returns raw `ParseResult` with full parse tree
2. **`squirrelParseAST()`** - Returns `ASTNode` tree (transparent rules elided)
3. **`squirrelParseCST()`** - Builds custom `CSTNode` tree from AST using factories

```java
import com.squirrelparser.*;

var grammar = "Number <- [0-9]+ ;";
var input = "42";

// Option 1: Get raw parse result
var pt = SquirrelParser.squirrelParsePT(grammar, "Number", input);

// Option 2: Get abstract syntax tree
var ast = SquirrelParser.squirrelParseAST(grammar, "Number", input);

// Option 3: Build concrete syntax tree with custom nodes
var cst = SquirrelParser.squirrelParseCST(grammar, "Number", factories, input,
                                          /* allowSyntaxErrors: */ false);
```

## CST Example: Parsing Variable Assignments

This example parses `x=32;y=0x20;` and converts numeric literals to actual integers:

```java
import com.squirrelparser.*;
import com.squirrelparser.tree.*;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class VariableAssignmentParser {

    // Grammar for variable assignments with decimal and hex numbers
    static final String GRAMMAR = """
        Assignments <- Assignment+ ;
        Assignment <- Name '=' Number ';' ;
        Name <- [a-zA-Z_][a-zA-Z0-9_]* ;
        Number <- HexNumber / DecNumber ;
        HexNumber <- "0x" [0-9a-fA-F]+ ;
        DecNumber <- [0-9]+ ;
        """;

    // Custom CST node classes
    static class AssignmentsNode extends CSTNode {
        final List<AssignmentNode> assignments;
        AssignmentsNode(ASTNode astNode, List<CSTNode> children) {
            super(astNode, children);
            this.assignments = children.stream()
                .filter(c -> c instanceof AssignmentNode)
                .map(c -> (AssignmentNode) c)
                .toList();
        }
    }

    static class AssignmentNode extends CSTNode {
        final String name;
        final int value;
        AssignmentNode(ASTNode astNode, List<CSTNode> children, String name, int value) {
            super(astNode, children);
            this.name = name;
            this.value = value;
        }
    }

    static class NumberNode extends CSTNode {
        final int value;
        NumberNode(ASTNode astNode, int value) {
            super(astNode, List.of());
            this.value = value;
        }
    }

    static class TerminalNode extends CSTNode {
        TerminalNode(ASTNode astNode) {
            super(astNode, List.of());
        }
    }

    // Factory map that creates CST nodes (input captured by closure)
    static Map<String, CSTNodeFactoryFn> createFactories(String input) {
        return new HashMap<>() {{
            put("Assignments", (astNode, children) -> new AssignmentsNode(astNode, children));
            put("Assignment", (astNode, children) -> {
                var nameNode = children.get(0);
                var valueNode = (NumberNode) children.get(1);
                var name = input.substring(nameNode.pos(), nameNode.pos() + nameNode.len());
                return new AssignmentNode(astNode, children, name, valueNode.value);
            });
            put("Name", (astNode, children) -> new TerminalNode(astNode));
            put("Number", (astNode, children) -> (NumberNode) children.get(0));
            put("HexNumber", (astNode, children) -> {
                var text = input.substring(astNode.pos(), astNode.pos() + astNode.len());
                return new NumberNode(astNode, Integer.parseInt(text.substring(2), 16));
            });
            put("DecNumber", (astNode, children) -> {
                var text = input.substring(astNode.pos(), astNode.pos() + astNode.len());
                return new NumberNode(astNode, Integer.parseInt(text));
            });
            put("<Terminal>", (astNode, children) -> new TerminalNode(astNode));
        }};
    }

    public static void main(String[] args) {
        var input = "x=32;y=0x20;z=255;";

        var cst = (AssignmentsNode) SquirrelParser.squirrelParseCST(
            GRAMMAR, "Assignments", createFactories(input), input, false);

        for (var assignment : cst.assignments) {
            System.out.println(assignment.name + " = " + assignment.value);
        }
        // Output:
        //   x = 32
        //   y = 32   (0x20 parsed as hex)
        //   z = 255
    }
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

## License

MIT License - see LICENSE file for details.
