package com.squirrelparser;

import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.*;
import static com.squirrelparser.SquirrelParser.*;

// ============================================================================
// JSON CST Node Classes
// ============================================================================

abstract class JsonValue extends CSTNodeBase {
    JsonValue(ASTNode astNode, List<CSTNodeBase> children) {
        super(astNode, children);
    }
}

class JsonObject extends JsonValue {
    private final List<JsonMember> members;

    JsonObject(ASTNode astNode, List<CSTNodeBase> children, List<JsonMember> members) {
        super(astNode, children);
        this.members = members;
    }

    public List<JsonMember> members() {
        return members;
    }
}

class JsonArray extends JsonValue {
    private final List<JsonValue> elements;

    JsonArray(ASTNode astNode, List<CSTNodeBase> children, List<JsonValue> elements) {
        super(astNode, children);
        this.elements = elements;
    }

    public List<JsonValue> elements() {
        return elements;
    }
}

class JsonString extends JsonValue {
    private final String value;

    JsonString(ASTNode astNode, List<CSTNodeBase> children, String value) {
        super(astNode, children);
        this.value = value;
    }

    public String value() {
        return value;
    }
}

class JsonNumber extends JsonValue {
    private final double value;

    JsonNumber(ASTNode astNode, List<CSTNodeBase> children, double value) {
        super(astNode, children);
        this.value = value;
    }

    public double value() {
        return value;
    }
}

class JsonBoolean extends JsonValue {
    private final boolean value;

    JsonBoolean(ASTNode astNode, List<CSTNodeBase> children, boolean value) {
        super(astNode, children);
        this.value = value;
    }

    public boolean value() {
        return value;
    }
}

class JsonNull extends JsonValue {
    JsonNull(ASTNode astNode, List<CSTNodeBase> children) {
        super(astNode, children);
    }
}

class JsonMember extends CSTNodeBase {
    private final String key;
    private final JsonValue value;

    JsonMember(ASTNode astNode, List<CSTNodeBase> children, String key, JsonValue value) {
        super(astNode, children);
        this.key = key;
        this.value = value;
    }

    public String key() {
        return key;
    }

    public JsonValue value() {
        return value;
    }
}

class JsonTerminal extends CSTNodeBase {
    JsonTerminal(ASTNode astNode) {
        super(astNode, List.of());
    }
}

// ============================================================================
// Full JSON Grammar according to json.org specification
// ============================================================================

class JsonParsingTest {

    static final String JSON_GRAMMAR = """
        JSON <- WS Value WS;
        Value <- Object / Array / String / Number / Boolean / Null;
        Object <- '{' WS (Member (WS ',' WS Member)*)? WS '}';
        Member <- String WS ':' WS Value;
        Array <- '[' WS (Value (WS ',' WS Value)*)? WS ']';
        String <- '"' Character* '"';
        Character <- [^\\"\\\\] / ('\\\\' Escape);
        Escape <- '"' / '\\\\' / '/' / 'b' / 'f' / 'n' / 'r' / 't' / ('u' [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F]);
        Number <- Integer Fraction? Exponent?;
        Integer <- '-'? (([1-9] [0-9]+) / [0-9]);
        Fraction <- '.' [0-9]+;
        Exponent <- ("e" / "E") ("+" / "-")? [0-9]+;
        Boolean <- "true" / "false";
        Null <- "null";
        ~WS <- [ \\t\\n\\r]*;
        """;

    // ============================================================================
    // Helper Functions
    // ============================================================================

    static String extractStringValue(String quotedString) {
        if (quotedString.length() < 2) return "";
        String content = quotedString.substring(1, quotedString.length() - 1);

        content = content.replace("\\\"", "\"");
        content = content.replace("\\\\", "\\");
        content = content.replace("\\/", "/");
        content = content.replace("\\b", "\b");
        content = content.replace("\\f", "\f");
        content = content.replace("\\n", "\n");
        content = content.replace("\\r", "\r");
        content = content.replace("\\t", "\t");

        Pattern unicodePattern = Pattern.compile("\\\\u([0-9a-fA-F]{4})");
        Matcher matcher = unicodePattern.matcher(content);
        StringBuilder sb = new StringBuilder();
        while (matcher.find()) {
            String hex = matcher.group(1);
            int codeUnit = Integer.parseInt(hex, 16);
            matcher.appendReplacement(sb, String.valueOf((char) codeUnit));
        }
        matcher.appendTail(sb);

        return sb.toString();
    }

    static double parseNumber(String numStr) {
        try {
            return Double.parseDouble(numStr);
        } catch (NumberFormatException e) {
            // If parsing fails, return 0 as a fallback
            // This can happen with invalid numbers due to error recovery
            return 0;
        }
    }

    // ============================================================================
    // Parse Function
    // ============================================================================

    record ParseJsonResult(CSTNodeBase cst, List<String> errors) {}

    static ParseJsonResult parseJson(String input, boolean allowErrors) {
        // Parse and get syntax errors using high-level API
        ParseResult parseResult = squirrelParsePT(JSON_GRAMMAR, "JSON", input);

        List<SyntaxError> syntaxErrors = parseResult.getSyntaxErrors();
        List<String> errorStrings = syntaxErrors.stream()
            .map(e -> input.substring(e.pos(), e.pos() + e.len()))
            .toList();

        List<CSTNodeFactory> factories = List.of(
            new CSTNodeFactory("JSON", (astNode, children) -> {
                List<JsonValue> values = children.stream()
                    .filter(c -> c instanceof JsonValue)
                    .map(c -> (JsonValue) c)
                    .toList();
                if (values.isEmpty()) return new JsonNull(astNode, children);
                return values.get(0);
            }),
            new CSTNodeFactory("Value", (astNode, children) -> {
                List<JsonValue> values = children.stream()
                    .filter(c -> c instanceof JsonValue)
                    .map(c -> (JsonValue) c)
                    .toList();
                if (values.isEmpty()) return new JsonNull(astNode, children);
                return values.get(0);
            }),
            new CSTNodeFactory("Object", (astNode, children) -> {
                List<JsonMember> members = children.stream()
                    .filter(c -> c instanceof JsonMember)
                    .map(c -> (JsonMember) c)
                    .toList();
                return new JsonObject(astNode, children, members);
            }),
            new CSTNodeFactory("Member", (astNode, children) -> {
                JsonString keyNode = null;
                JsonValue valueNode = null;

                for (var child : children) {
                    if (child instanceof JsonString && keyNode == null) {
                        keyNode = (JsonString) child;
                    }
                    if (child instanceof JsonValue && !(child instanceof JsonString) && valueNode == null) {
                        valueNode = (JsonValue) child;
                    }
                }

                String keyStr = keyNode != null ? keyNode.value() : "";
                return new JsonMember(
                    astNode,
                    children,
                    keyStr,
                    valueNode != null ? valueNode : new JsonNull(astNode, List.of())
                );
            }),
            new CSTNodeFactory("Array", (astNode, children) -> {
                List<JsonValue> elements = children.stream()
                    .filter(c -> c instanceof JsonValue)
                    .map(c -> (JsonValue) c)
                    .toList();
                return new JsonArray(astNode, children, elements);
            }),
            new CSTNodeFactory("String", (astNode, children) -> {
                String quoted = astNode.getInputSpan(input);
                String value = extractStringValue(quoted);
                return new JsonString(astNode, children, value);
            }),
            new CSTNodeFactory("Character", (astNode, children) ->
                new JsonString(astNode, children, astNode.getInputSpan(input))
            ),
            new CSTNodeFactory("Escape", (astNode, children) ->
                new JsonString(astNode, children, "")
            ),
            new CSTNodeFactory("Number", (astNode, children) -> {
                String numStr = astNode.getInputSpan(input);
                return new JsonNumber(astNode, children, parseNumber(numStr));
            }),
            new CSTNodeFactory("Integer", (astNode, children) ->
                new JsonNull(astNode, children)
            ),
            new CSTNodeFactory("Fraction", (astNode, children) ->
                new JsonNull(astNode, children)
            ),
            new CSTNodeFactory("Exponent", (astNode, children) ->
                new JsonNull(astNode, children)
            ),
            new CSTNodeFactory("Boolean", (astNode, children) -> {
                String boolStr = astNode.getInputSpan(input);
                return new JsonBoolean(astNode, children, boolStr.equals("true"));
            }),
            new CSTNodeFactory("Null", (astNode, children) ->
                new JsonNull(astNode, children)
            ),
            new CSTNodeFactory("<Terminal>", (astNode, children) ->
                new JsonTerminal(astNode)
            ),
            new CSTNodeFactory("<SyntaxError>", (astNode, children) ->
                new JsonNull(astNode, children)
            )
        );

        try {
            CSTNodeBase cst = squirrelParseCST(
                JSON_GRAMMAR,
                "JSON",
                factories,
                input,
                true  // Always allow syntax errors during parsing for recovery
            );
            return new ParseJsonResult(cst, errorStrings);
        } catch (IllegalArgumentException e) {
            return new ParseJsonResult(
                new JsonNull(ASTNode.of("Error", 0, 0, List.of()), List.of()),
                List.of(e.toString())
            );
        }
    }

    static ParseJsonResult parseJson(String input) {
        return parseJson(input, false);
    }

    // ============================================================================
    // Tests
    // ============================================================================

    @Nested
    class BasicValues {

        @Test
        void parsesJsonNull() {
            var result = parseJson("null");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonNull.class, result.cst());
        }

        @Test
        void parsesJsonBooleanTrue() {
            var result = parseJson("true");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonBoolean.class, result.cst());
            JsonBoolean boolNode = (JsonBoolean) result.cst();
            assertTrue(boolNode.value());
        }

        @Test
        void parsesJsonBooleanFalse() {
            var result = parseJson("false");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonBoolean.class, result.cst());
            JsonBoolean boolNode = (JsonBoolean) result.cst();
            assertFalse(boolNode.value());
        }

        @Test
        void parsesJsonInteger() {
            var result = parseJson("42");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonNumber.class, result.cst());
            JsonNumber numNode = (JsonNumber) result.cst();
            assertEquals(42, numNode.value());
        }

        @Test
        void parsesJsonNegativeNumber() {
            var result = parseJson("-123");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonNumber.class, result.cst());
            JsonNumber numNode = (JsonNumber) result.cst();
            assertEquals(-123, numNode.value());
        }

        @Test
        void parsesJsonDecimalNumber() {
            var result = parseJson("3.14");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonNumber.class, result.cst());
            JsonNumber numNode = (JsonNumber) result.cst();
            assertEquals(3.14, numNode.value());
        }

        @Test
        void parsesJsonNumberWithExponent() {
            var result = parseJson("1e3");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonNumber.class, result.cst());
        }

        @Test
        void parsesEmptyJsonString() {
            var result = parseJson("\"\"");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonString.class, result.cst());
            JsonString strNode = (JsonString) result.cst();
            assertTrue(strNode.value().isEmpty());
        }

        @Test
        void parsesJsonStringWithContent() {
            var result = parseJson("\"hello\"");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonString.class, result.cst());
        }

        @Test
        void parsesEmptyJsonArray() {
            var result = parseJson("[]");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonArray.class, result.cst());
            JsonArray arrNode = (JsonArray) result.cst();
            assertTrue(arrNode.elements().isEmpty());
        }

        @Test
        void parsesJsonArrayWithSingleElement() {
            var result = parseJson("[42]");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonArray.class, result.cst());
            JsonArray arrNode = (JsonArray) result.cst();
            assertEquals(1, arrNode.elements().size());
        }

        @Test
        void parsesJsonArrayWithMultipleElements() {
            var result = parseJson("[1, 2, 3]");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonArray.class, result.cst());
            JsonArray arrNode = (JsonArray) result.cst();
            assertEquals(3, arrNode.elements().size());
        }

        @Test
        void parsesEmptyJsonObject() {
            var result = parseJson("{}");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonObject.class, result.cst());
            JsonObject objNode = (JsonObject) result.cst();
            assertTrue(objNode.members().isEmpty());
        }

        @Test
        void parsesJsonObjectWithSingleProperty() {
            var result = parseJson("{\"key\": 42}");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonObject.class, result.cst());
            JsonObject objNode = (JsonObject) result.cst();
            assertEquals(1, objNode.members().size());
        }

        @Test
        void parsesJsonObjectWithMultipleProperties() {
            var result = parseJson("{\"a\": 1, \"b\": 2, \"c\": 3}");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonObject.class, result.cst());
            JsonObject objNode = (JsonObject) result.cst();
            assertEquals(3, objNode.members().size());
        }
    }

    @Nested
    class NestedStructures {

        @Test
        void parsesNestedArrayOfArrays() {
            var result = parseJson("[[1, 2], [3, 4]]");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonArray.class, result.cst());
            JsonArray arrNode = (JsonArray) result.cst();
            assertEquals(2, arrNode.elements().size());
        }

        @Test
        void parsesNestedObjectInArray() {
            var result = parseJson("[{\"key\": \"value\"}]");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonArray.class, result.cst());
            JsonArray arrNode = (JsonArray) result.cst();
            assertEquals(1, arrNode.elements().size());
        }

        @Test
        void parsesNestedArrayInObject() {
            var result = parseJson("{\"array\": [1, 2, 3]}");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonObject.class, result.cst());
            JsonObject objNode = (JsonObject) result.cst();
            assertEquals(1, objNode.members().size());
        }

        @Test
        void parsesComplexNestedStructure() {
            var result = parseJson("""
                {
                  "users": [
                    {"name": "Alice", "age": 30},
                    {"name": "Bob", "age": 25}
                  ],
                  "active": true
                }
                """);
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonObject.class, result.cst());
        }
    }

    @Nested
    class WhitespaceHandling {

        @Test
        void parsesWithLeadingWhitespace() {
            var result = parseJson("  null");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonNull.class, result.cst());
        }

        @Test
        void parsesWithTrailingWhitespace() {
            var result = parseJson("null  ");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonNull.class, result.cst());
        }

        @Test
        void parsesWithWhitespaceAroundStructure() {
            var result = parseJson("  {  \"key\"  :  42  }  ");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonObject.class, result.cst());
        }

        @Test
        void parsesWithNewlinesAndTabs() {
            var result = parseJson("{\n\t\"key\": 42\n}");
            assertTrue(result.errors().isEmpty());
            assertInstanceOf(JsonObject.class, result.cst());
        }
    }

    @Nested
    class ErrorCases {

        @Test
        void detectsIncompleteArray() {
            var result = parseJson("[1, 2");
            assertFalse(result.errors().isEmpty());
        }

        @Test
        void detectsIncompleteObject() {
            var result = parseJson("{\"key\": \"value\"");
            assertFalse(result.errors().isEmpty());
        }

        @Test
        void detectsInvalidNumber() {
            var result = parseJson("[1, 2.3.4, 5]");
            assertFalse(result.errors().isEmpty());
        }

        @Test
        void detectsMissingValue() {
            var result = parseJson("[1, , 3]");
            assertFalse(result.errors().isEmpty());
        }

        @Test
        void detectsTrailingCommaInArray() {
            var result = parseJson("[1, 2, 3,]");
            assertFalse(result.errors().isEmpty());
        }

        @Test
        void detectsMissingColonInObject() {
            var result = parseJson("{\"key\" 42}");
            assertFalse(result.errors().isEmpty());
        }

        @Test
        void detectsTrailingCommaInObject() {
            var result = parseJson("{\"key\": 42,}");
            assertFalse(result.errors().isEmpty());
        }

        @Test
        void detectsUnquotedKey() {
            var result = parseJson("{key: 42}");
            assertFalse(result.errors().isEmpty());
        }
    }
}
