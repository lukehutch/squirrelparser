package com.squirrelparser;

/**
 * Terminal clause implementations (match literal strings and characters).
 */
public final class Terminals {

    private Terminals() {} // Prevent instantiation

    public interface Terminal extends Clause {
    }

    /** Matches a literal string. */
    public record Str(String text, boolean transparent) implements Terminal {
        public Str(String text) {
            this(text, false);
        }

        @Override
        public MatchResult match(Parser parser, int pos, Clause bound) {
            if (pos + text.length() > parser.input().length()) {
                return Mismatch.INSTANCE;
            }
            for (int i = 0; i < text.length(); i++) {
                if (parser.input().charAt(pos + i) != text.charAt(i)) {
                    return Mismatch.INSTANCE;
                }
            }
            return new Match(this, pos, text.length());
        }

        @Override
        public String toString() {
            return "\"" + text + "\"";
        }
    }

    /** Matches a single character. */
    public record Char(String ch, boolean transparent) implements Terminal {
        public Char {
            if (ch.length() != 1) {
                throw new IllegalArgumentException("Char must be exactly one character");
            }
        }

        public Char(String ch) {
            this(ch, false);
        }

        @Override
        public MatchResult match(Parser parser, int pos, Clause bound) {
            if (pos >= parser.input().length()) {
                return Mismatch.INSTANCE;
            }
            if (parser.input().charAt(pos) == ch.charAt(0)) {
                return new Match(this, pos, 1);
            }
            return Mismatch.INSTANCE;
        }

        @Override
        public String toString() {
            return "'" + ch + "'";
        }
    }

    /** Matches a single character in a range [lo-hi]. */
    public record CharRange(String lo, String hi, boolean transparent) implements Terminal {
        public CharRange {
            if (lo.length() != 1 || hi.length() != 1) {
                throw new IllegalArgumentException("CharRange bounds must be single characters");
            }
        }

        public CharRange(String lo, String hi) {
            this(lo, hi, false);
        }

        @Override
        public MatchResult match(Parser parser, int pos, Clause bound) {
            if (pos >= parser.input().length()) {
                return Mismatch.INSTANCE;
            }
            char c = parser.input().charAt(pos);
            if (c >= lo.charAt(0) && c <= hi.charAt(0)) {
                return new Match(this, pos, 1);
            }
            return Mismatch.INSTANCE;
        }

        @Override
        public String toString() {
            return "[" + lo + "-" + hi + "]";
        }
    }

    /** Matches any single character. */
    public record AnyChar(boolean transparent) implements Terminal {
        public AnyChar() {
            this(false);
        }

        @Override
        public MatchResult match(Parser parser, int pos, Clause bound) {
            if (pos >= parser.input().length()) {
                return Mismatch.INSTANCE;
            }
            return new Match(this, pos, 1);
        }

        @Override
        public String toString() {
            return ".";
        }
    }

    /** Matches nothing - always succeeds without consuming any input. */
    public record Nothing(boolean transparent) implements Terminal {
        public Nothing() {
            this(false);
        }

        @Override
        public MatchResult match(Parser parser, int pos, Clause bound) {
            return new Match(this, pos, 0);
        }

        @Override
        public String toString() {
            return "∅";
        }
    }
}
