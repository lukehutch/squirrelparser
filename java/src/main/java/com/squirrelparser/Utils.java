package com.squirrelparser;

/**
 * Utility functions for string escaping and unescaping.
 */
public final class Utils {
    private Utils() {}

    /**
     * Escape a string for display.
     */
    public static String escapeString(String s) {
        var buffer = new StringBuilder();
        for (int i = 0; i < s.length(); i++) {
            int codePoint = s.codePointAt(i);
            if (Character.isSupplementaryCodePoint(codePoint)) {
                i++; // Skip the next char (low surrogate)
            }
            String escaped = switch (codePoint) {
                case '\\' -> "\\\\";
                case '"' -> "\\\"";
                case '\'' -> "\\'";
                case '\n' -> "\\n";
                case '\r' -> "\\r";
                case '\t' -> "\\t";
                case '\b' -> "\\b";
                default -> {
                    if (codePoint <= 0x1f || (codePoint >= 0x7f && codePoint <= 0xffff)) {
                        yield String.format("\\u%04x", codePoint);
                    } else if (codePoint > 0xffff) {
                        yield String.format("\\u{%x}", codePoint);
                    } else {
                        yield Character.toString(codePoint);
                    }
                }
            };
            buffer.append(escaped);
        }
        return buffer.toString();
    }

    /**
     * Unescape a string literal (content between quotes).
     */
    public static String unescapeString(String str) {
        var buffer = new StringBuilder();
        int i = 0;
        while (i < str.length()) {
            if (str.charAt(i) == '\\' && i + 1 < str.length()) {
                char next = str.charAt(i + 1);
                String unescaped = switch (next) {
                    case 'n' -> "\n";
                    case 'r' -> "\r";
                    case 't' -> "\t";
                    case '\\' -> "\\";
                    case '"' -> "\"";
                    case '\'' -> "'";
                    case '[' -> "[";
                    case ']' -> "]";
                    case '-' -> "-";
                    default -> String.valueOf(next);
                };
                buffer.append(unescaped);
                i += 2;
            } else {
                buffer.append(str.charAt(i));
                i++;
            }
        }
        return buffer.toString();
    }

    /**
     * Unescape a single character (possibly an escape sequence).
     */
    public static String unescapeChar(String str) {
        if (str.length() == 1) {
            return str;
        }
        if (str.length() == 2 && str.charAt(0) == '\\') {
            return switch (str.charAt(1)) {
                case 'n' -> "\n";
                case 'r' -> "\r";
                case 't' -> "\t";
                case '\\' -> "\\";
                case '"' -> "\"";
                case '\'' -> "'";
                case '[' -> "[";
                case ']' -> "]";
                case '-' -> "-";
                default -> String.valueOf(str.charAt(1));
            };
        }
        return str;
    }
}
