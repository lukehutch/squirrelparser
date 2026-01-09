# The Squirrel Parser 🐿️

This is the **Java** implementation of the squirrel parser: a fast linear-time PEG packrat parser capable of handling all forms of left recursion, with optimal error recovery.

The squirrel parser handles all forms of left recursion, including cases of multiple interwoven direct or indirect left recursive cycles, and preserves perfect linear performance in the length of the input regardless of the number of syntax errors encountered: both parsing and error recovery have linear performance.

See the details on the derivation of the squirrel parsing algorithm in [the paper](../paper/squirrel_parser.pdf).

## Usage

The Squirrel Parser uses a **Concrete Syntax Tree (CST)** approach with custom factory functions. This allows you to build exactly the data structure you need from the parse tree.

### Key Concept: Transparent Rules

In the Squirrel Parser grammar, rules prefixed with `~` are **transparent** and don't create CST nodes:

```java
String grammar = """
  ~_ <- [ \\t\\n\\r]*;  // Transparent: won't create a CST node
  ~Whitespace <- ' '+;      // Transparent: won't create a CST node
  Number <- [0-9]+;         // Non-transparent: will create a CST node
  Expr <- Number ('+' Number)*;  // Non-transparent: will create a CST node
""";
```

**Important**: You only need to create factories for **non-transparent** grammar rules. Transparent rules are automatically excluded from factory requirements. If you accidentally create a factory for a transparent rule, an exception will be thrown.

### Basic Example with CST

```java
import com.squirrelparser.*;
import java.util.List;

// 1. Define your grammar using PEG metagrammar syntax
String grammarText = """
  Expr   <- Term (AddOp Term)*;
  Term   <- Factor (MulOp Factor)*;
  Factor <- Number / '(' Expr ')';
  Number <- [0-9]+;
  AddOp  <- '+' / '-';
  MulOp  <- '*' / '/';
  ~_ <- [ \\t\\n\\r]*;
""";

// 2. Define custom CST node classes for each concrete syntax element
class CalcNode extends CSTNode {
    private final List<CalcNode> children;
    private final Integer value;

    public CalcNode(String name, List<CalcNode> children, Integer value) {
        super(name);
        this.children = children != null ? children : List.of();
        this.value = value;
    }

    public CalcNode(String name, List<CalcNode> children) {
        this(name, children, null);
    }

    public CalcNode(String name, Integer value) {
        this(name, null, value);
    }

    @Override
    public String toString() {
        return value != null ? value.toString() : this.name;
    }
}

// 3. Create factories for each NON-TRANSPARENT grammar rule
// Note: factories should be in the same order as the grammar rules are defined
List<CSTNodeFactory<CSTNode>> factories = List.of(
    new CSTNodeFactory<>(
        "Expr",
        List.of("Term", "AddOp"),
        (ruleName, expectedChildren, children) ->
            new CalcNode(ruleName, (List<CalcNode>) (List<?>) children)
    ),
    new CSTNodeFactory<>(
        "Term",
        List.of("Factor", "MulOp"),
        (ruleName, expectedChildren, children) ->
            new CalcNode(ruleName, (List<CalcNode>) (List<?>) children)
    ),
    new CSTNodeFactory<>(
        "Factor",
        List.of("Number", "Expr"),
        (ruleName, expectedChildren, children) ->
            new CalcNode(ruleName, (List<CalcNode>) (List<?>) children)
    ),
    new CSTNodeFactory<>(
        "Number",
        List.of("<Terminal>"),
        (ruleName, expectedChildren, children) -> {
            int value = children.isEmpty() ? 0 :
                Integer.parseInt(children.get(0).toString());
            return new CalcNode(ruleName, value);
        }
    ),
    new CSTNodeFactory<>(
        "AddOp",
        List.of("<Terminal>"),
        (ruleName, expectedChildren, children) ->
            new CalcNode(ruleName)
    ),
    new CSTNodeFactory<>(
        "MulOp",
        List.of("<Terminal>"),
        (ruleName, expectedChildren, children) ->
            new CalcNode(ruleName)
    )
);

// 4. Parse input and get the CST
String input = "2+3*4";
CSTNode cst = SquirrelParser.parse(grammarText, input, "Expr", factories);
System.out.println("Parse successful: " + cst.getName());
```

### Understanding CST Factories

Each **non-transparent** grammar rule needs a corresponding factory. The factory function receives:

- **ruleName**: The name of the grammar rule
- **expectedChildren**: The expected child rule names (useful for validation)
- **children**: The actual CST child nodes built from the parse tree

```java
new CSTNodeFactory<MyNode>(
    "RuleName",
    List.of("Child1", "Child2"),  // Expected children
    (ruleName, expectedChildren, children) -> {
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

```java
import com.squirrelparser.*;
import java.util.List;

// Custom CST node for JSON
class JsonNode extends CSTNode {
    private final Object value;
    private final List<JsonNode> children;

    public JsonNode(String name, List<JsonNode> children, Object value) {
        super(name);
        this.children = children != null ? children : List.of();
        this.value = value;
    }
}

String jsonGrammar = """
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

~_ <- [ \\t\\n\\r]* ;
""";

// CST factories - note: only for non-transparent rules
List<CSTNodeFactory<CSTNode>> factories = List.of(
    new CSTNodeFactory<>(
        "JSON",
        List.of("Value"),
        (ruleName, expectedChildren, children) ->
            new JsonNode(
                ruleName,
                (List<JsonNode>) (List<?>) children,
                !children.isEmpty() ? ((JsonNode) children.get(0)).value : null
            )
    ),
    new CSTNodeFactory<>(
        "Value",
        List.of("Object", "Array", "String", "Number", "Boolean", "Null"),
        (ruleName, expectedChildren, children) ->
            new JsonNode(
                ruleName,
                (List<JsonNode>) (List<?>) children,
                !children.isEmpty() ? ((JsonNode) children.get(0)).value : null
            )
    )
    // ... factories for other non-transparent rules ...
);

// Parse JSON
String jsonInput = "{\"name\": \"Alice\", \"age\": 30}";
CSTNode cst = SquirrelParser.parse(jsonGrammar, jsonInput, "JSON", factories);
System.out.println("JSON parsed successfully: " + cst.getName());
```

## Error Handling

### Factory Validation Errors

```java
import com.squirrelparser.*;

try {
    CSTNode cst = SquirrelParser.parse(grammar, input, "RuleName", factories);
} catch (CSTFactoryValidationException e) {
    System.out.println("Missing factories: " + e.getMissing());
    System.out.println("Extra factories: " + e.getExtra());
} catch (DuplicateRuleNameException e) {
    System.out.println("Duplicate rule: " + e.getRuleName() +
                       " (appears " + e.getCount() + " times)");
} catch (CSTConstructionException e) {
    System.out.println("CST construction failed: " + e.getMessage());
}
```

### Syntax Errors

The parser returns syntax errors separately from the CST:

```java
List<SyntaxError> syntaxErrors = SquirrelParser.parseErrors(grammar, input, "RuleName", factories);

if (!syntaxErrors.isEmpty()) {
    System.out.println("Syntax errors found:");
    for (SyntaxError error : syntaxErrors) {
        System.out.println("  " + error.toString());
    }
}
```

### Defining Custom Node Classes

Your CST node classes should capture the semantic information you need:

```java
class MyNode extends CSTNode {
    private final List<MyNode> children;
    private final String value;

    public MyNode(String name, List<MyNode> children, String value) {
        super(name);
        this.children = children;
        this.value = value;
    }
}
```

### Using Transparent Rules for Whitespace

Use transparent rules to handle whitespace and other structural elements:

```
~_ <- [ \t\n\r]* ;
Expression <- Term (_ ('+' / '-') _ Term)* ;
Term <- Factor (_ ('*' / '/') _ Factor)* ;
Factor <- Number / '(' _ Expression _ ')' ;
Number <- [0-9]+ ;
```

You only need factories for Expression, Term, Factor, and Number. NOT for `_` (which is transparent).

### Factory Functions Can Validate Input

You can perform validation within your factory functions:

```java
new CSTNodeFactory<MyNode>(
    "MyRule",
    List.of("Child1", "Child2"),
    (ruleName, expectedChildren, children) -> {
        if (children.isEmpty()) {
            throw new CSTConstructionException(ruleName + " requires children");
        }
        return new MyNode(ruleName, children, null);
    }
)
```

### Handling Terminal Nodes

Terminal rules (which match literal text or character classes) have `expectedChildren: List.of("<Terminal>")`:

```java
// Terminals have expectedChildren: List.of("<Terminal>")
new CSTNodeFactory<MyNode>(
    "Number",
    List.of("<Terminal>"),
    (ruleName, _expectedChildren, children) -> {
        String value = children.isEmpty() ? null : children.get(0).toString();
        return new MyNode(ruleName, null, value);
    }
)
```

## Building

```bash
mvn clean test    # Run tests
mvn package       # Build JAR
mvn clean compile # Compile
```

## Testing

The implementation includes comprehensive CST tests demonstrating all features:

- Type-safe generic node creation
- Factory validation with duplicate detection
- Transparent rule handling
- Correct exception throwing

See the test files in `src/test/java/` for complete examples.
