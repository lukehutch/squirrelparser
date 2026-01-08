# The Squirrel Parser 🐿️ -- Java Implementation

This is the Java implementation of the squirrel parser: a fast linear-time PEG packrat parser capable of handling all forms of left recursion, with optimal error recovery.

The squirrel parser handles all forms of left recursion, including cases of multiple interwoven direct or indirect left recursive cycles, and preserves perfect linear performance in the length of the input regardless of the number of syntax errors encountered: both parsing and error recovery have linear performance.

See the details on the derivation of the squirrel parsing algorithm in [the paper](paper/squirrel_parser.pdf).

## Usage

### With Metagrammar (PEG Syntax) - Recommended

```java
import com.squirrelparser.*;
import java.util.List;

// Define grammar using PEG syntax
String grammarStr = """
    number <- [0-9]+
    expr <- expr '+' number / number
    """;

// Parse input with error handling
var result = SquirrelParse.parse(grammarStr, "1+2+3", "expr");
ASTNode ast = result.ast();
List<SyntaxError> errors = result.errors();

System.out.println("AST:");
System.out.println(ast.toPrettyString());
if (!errors.isEmpty()) {
    System.out.println("Syntax errors found:");
    for (var error : errors) {
        System.out.println("  " + error);
    }
}
```

### Without Metagrammar (Direct API)

```java
import com.squirrelparser.*;
import static com.squirrelparser.Terminals.*;
import static com.squirrelparser.Combinators.*;
import java.util.Map;
import java.util.List;

// Define grammar rules directly
Map<String, Clause> rules = Map.of(
    "number", new OneOrMore(new CharRange("0", "9")),
    "expr", new First(List.of(
        new Seq(List.of(new Ref("expr"), new Str("+"), new Ref("number"))),
        new Ref("number")
    ))
);

// Parse input
Parser parser = new Parser(rules, "1+2+3");
MatchResult result = parser.parse("expr");

if (!result.isMismatch()) {
    System.out.println("Matched: " + parser.input().substring(result.pos(), result.pos() + result.len()));
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

```java
# This is a comment
Rule <- "a" ; # Comments can appear anywhere
```

## Complete Example: JSON Grammar

```java
import com.squirrelparser.*;
import java.util.Map;

String jsonGrammar = """
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
""";

// Parse the grammar
Map<String, Clause> rules = MetaGrammar.parseGrammar(jsonGrammar);

// Test with JSON input
String jsonInput = "{\"name\": \"Alice\", \"age\": 30, \"active\": true}";
Parser parser = new Parser(rules, jsonInput);
ASTNode ast = parser.parseToAST("JSON");

if (ast != null) {
    System.out.println("JSON parsed successfully!");
    System.out.println(ast.toPrettyString());
} else {
    System.out.println("Failed to parse JSON");
}
```

## Example: Calculator with Actions

```java
import com.squirrelparser.*;
import java.util.Map;

public class Calculator {
    public static void main(String[] args) {
        // Define grammar
        String calcGrammar = """
        Expr <- Term (('+' / '-') Term)* ;
        Term <- Factor (('*' / '/') Factor)* ;
        Factor <- Number / '(' Expr ')' ;
        Number <- [0-9]+ ;
        """;

        // Parse grammar
        Map<String, Clause> rules = MetaGrammar.parseGrammar(calcGrammar);

        // Parse input and get AST
        Parser parser = new Parser(rules, "2 + 3 * 4");
        ASTNode ast = parser.parseToAST("Expr");

        if (ast != null) {
            double result = evalAST(ast);
            System.out.println("Result: " + result); // Output: Result: 14.0
        }
    }

    // Define evaluation function
    public static double evalAST(ASTNode node) {
        if (node.label.equals("Number")) {
            return Double.parseDouble(node.text());
        } else if (node.label.equals("Factor")) {
            if (node.children.size() == 1) {
                return evalAST(node.children.get(0));
            } else { // Parenthesized expression
                return evalAST(node.children.get(1));
            }
        } else if (node.label.equals("Term")) {
            double result = evalAST(node.children.get(0));
            int i = 1;
            while (i < node.children.size()) {
                String op = node.children.get(i).text();
                double operand = evalAST(node.children.get(i + 1));
                if (op.equals("*")) {
                    result *= operand;
                } else if (op.equals("/")) {
                    result /= operand;
                }
                i += 2;
            }
            return result;
        } else if (node.label.equals("Expr")) {
            double result = evalAST(node.children.get(0));
            int i = 1;
            while (i < node.children.size()) {
                String op = node.children.get(i).text();
                double operand = evalAST(node.children.get(i + 1));
                if (op.equals("+")) {
                    result += operand;
                } else if (op.equals("-")) {
                    result -= operand;
                }
                i += 2;
            }
            return result;
        } else {
            // Recursively evaluate children
            if (!node.children.isEmpty()) {
                return evalAST(node.children.get(0));
            }
            return 0.0;
        }
    }
}
```

## Error Handling

```java
import com.squirrelparser.*;

try {
    Map<String, Clause> rules = MetaGrammar.parseGrammar(grammarText);
} catch (Exception e) {
    System.out.println("Grammar parse error: " + e.getMessage());
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

```java
ASTNode ast = parser.parseToAST("Expression");
if (ast != null) {
    System.out.println(ast.toPrettyString());
}
```

This will show the hierarchical structure of your parsed input.

## Building

```bash
mvn clean test    # Run tests
mvn package       # Build JAR
```
