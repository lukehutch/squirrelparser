package squirrelparser.utils;

import java.util.ArrayList;
import java.util.List;

/** String utilities. */
public class StringUtils {
	private static final char NON_ASCII_CHAR = '■';

	/** Replace non-ASCII/non-printable char with a block. */
	public static char replaceNonASCII(char c) {
		return c < 32 || c > 126 ? NON_ASCII_CHAR : c;
	}

	/** Replace all non-ASCII/non-printable characters with a block. */
	public static void replaceNonASCII(String str, StringBuilder buf) {
		for (int i = 0; i < str.length(); i++) {
			char c = str.charAt(i);
			buf.append(replaceNonASCII(c));
		}
	}

	/** Replace all non-ASCII/non-printable characters with a block. */
	public static String replaceNonASCII(String str) {
		StringBuilder buf = new StringBuilder();
		replaceNonASCII(str, buf);
		return buf.toString();
	}

	/** Convert a hex digit to an integer. */
	public static int hexDigitToInt(char c) {
		if (c >= '0' && c <= '9') {
			return c - '0';
		} else if (c >= 'a' && c <= 'f') {
			return c - 'a' + 10;
		} else if (c >= 'A' && c <= 'F') {
			return c - 'A' + 10;
		}
		throw new IllegalArgumentException("Illegal hex digit: " + c);
	}

	/** Unescape a single character. */
	public static char unescapeChar(String escapedChar) {
		if (escapedChar.length() == 0) {
			throw new IllegalArgumentException("Empty char string");
		} else if (escapedChar.length() == 1) {
			return escapedChar.charAt(0);
		}
		switch (escapedChar) {
		case "\\t":
			return '\t';
		case "\\b":
			return '\b';
		case "\\n":
			return '\n';
		case "\\r":
			return '\r';
		case "\\f":
			return '\f';
		case "\\'":
			return '\'';
		case "\\\"":
			return '"';
		case "\\\\":
			return '\\';
		default:
			if (escapedChar.startsWith("\\u") && escapedChar.length() == 6) {
				int c0 = hexDigitToInt(escapedChar.charAt(2));
				int c1 = hexDigitToInt(escapedChar.charAt(3));
				int c2 = hexDigitToInt(escapedChar.charAt(4));
				int c3 = hexDigitToInt(escapedChar.charAt(5));
				return (char) ((c0 << 24) | (c1 << 16) | (c2 << 8) | c3);
			} else {
				throw new IllegalArgumentException("Invalid character: " + escapedChar);
			}
		}
	}

	/** Get the sequence of (possibly escaped) characters in a char range string. */
	public static List<String> getCharRangeChars(String str) {
		var charRangeChars = new ArrayList<String>();
		for (int i = 0; i < str.length(); i++) {
			char c = str.charAt(i);
			if (c == '\\') {
				if (i == str.length() - 1) {
					// Should not happen
					throw new IllegalArgumentException("Got backslash at end of quoted string");
				}
				if (str.charAt(i + 1) == 'u') {
					if (i > str.length() - 6) {
						// Should not happen
						throw new IllegalArgumentException("Truncated Unicode character sequence");
					}
					charRangeChars.add(Character.toString(unescapeChar(str.substring(i, i + 6))));
					i += 5; // Consume escaped characters
				} else {
					var escapeSeq = str.substring(i, i + 2);
					if (escapeSeq.equals("\\-") || escapeSeq.equals("\\^") || escapeSeq.equals("\\]")
							|| escapeSeq.equals("\\\\")) {
						// Preserve range-specific escaping for char ranges
						charRangeChars.add(escapeSeq);
					} else {
						charRangeChars.add(Character.toString(unescapeChar(escapeSeq)));
					}
					i++; // Consume escaped character
				}
			} else {
				charRangeChars.add(Character.toString(c));
			}
		}
		return charRangeChars;
	}

	/** Unescape a string. */
	public static String unescapeString(String str) {
		StringBuilder buf = new StringBuilder();
		for (int i = 0; i < str.length(); i++) {
			char c = str.charAt(i);
			if (c == '\\') {
				if (i == str.length() - 1) {
					// Should not happen
					throw new IllegalArgumentException("Got backslash at end of quoted string");
				}
				if (str.charAt(i + 1) == 'u') {
					if (i > str.length() - 6) {
						// Should not happen
						throw new IllegalArgumentException("Truncated Unicode character sequence");
					}
					buf.append(unescapeChar(str.substring(i, i + 6)));
					i += 5; // Consume escaped characters
				} else {
					var escapeSeq = str.substring(i, i + 2);
					buf.append(unescapeChar(escapeSeq));
					i++; // Consume escaped character
				}
			} else {
				buf.append(c);
			}
		}
		return buf.toString();
	}

	/** Escape a character. */
	public static String escapeChar(char c) {
		switch (c) {
		case '\'':
			return "\\'";
		case '\n':
			return "\\n";
		case '\r':
			return "\\r";
		case '\t':
			return "\\t";
		case '\b':
			return "\\b";
		case '\f':
			return "\\f";
		default:
			if (c < 32 || c > 126) {
				return "\\u" + String.format("%04x", (int) c);
			} else {
				return Character.toString(c);
			}
		}
	}

	/** Escape a single-quoted character. */
	public static String escapeQuotedChar(char c) {
		if (c == '\'') {
			return "\\'";
		} else if (c == '\\') {
			return "\\\\";
		} else {
			return escapeChar(c);
		}
	}

	/** Escape a character. */
	public static String escapeQuotedStringChar(char c) {
		if (c == '"') {
			return "\\\"";
		} else if (c == '\\') {
			return "\\\\";
		} else {
			return escapeChar(c);
		}
	}

	/** Escape a character for inclusion in a character range pattern. */
	public static String escapeCharRangeChar(char c) {
		if (c == ']') {
			return "\\]";
		} else if (c == '^') {
			return "\\^";
		} else if (c == '-') {
			return "\\-";
		} else if (c == '\\') {
			return "\\\\";
		} else {
			return escapeChar(c);
		}
	}

	/** Escape a string. */
	public static String escapeString(CharSequence str) {
		var buf = new StringBuilder();
		for (int i = 0; i < str.length(); i++) {
			char c = str.charAt(i);
			buf.append(c == '"' ? "\\\"" : escapeQuotedStringChar(c));
		}
		return buf.toString();
	}
}