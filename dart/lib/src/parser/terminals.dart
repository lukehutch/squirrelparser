import 'package:squirrel_parser/src/parser/utils.dart';

import 'clause.dart';
import 'match_result.dart';
import 'parser.dart';

// -----------------------------------------------------------------------------------------------------------------

abstract class Terminal extends Clause {
  const Terminal();

  @override
  void checkRuleRefs(Map<String, Clause> grammarMap) {
    // Terminals have no references to check.
  }

  /// The AST/CST node label for terminals.
  static const String nodeLabel = '<Terminal>';
}

// -----------------------------------------------------------------------------------------------------------------

/// Matches a literal string.
class Str extends Terminal {
  final String text;
  const Str(this.text);

  @override
  MatchResult match(Parser parser, int pos, {Clause? bound}) {
    if (pos + text.length > parser.input.length) return mismatch;
    for (int i = 0; i < text.length; i++) {
      if (parser.input.codeUnitAt(pos + i) != text.codeUnitAt(i)) {
        return mismatch;
      }
    }
    return Match(this, pos, text.length);
  }

  @override
  String toString() => '"${escapeString(text)}"';
}

// -----------------------------------------------------------------------------------------------------------------

/// Matches a single character.
class Char extends Terminal {
  final String char;
  const Char(this.char) : assert(char.length == 1);

  @override
  MatchResult match(Parser parser, int pos, {Clause? bound}) {
    if (pos + char.length > parser.input.length) return mismatch;
    for (int i = 0; i < char.length; i++) {
      if (parser.input.codeUnitAt(pos + i) != char.codeUnitAt(i)) {
        return mismatch;
      }
    }
    return Match(this, pos, char.length);
  }

  @override
  String toString() => "'${escapeString(char)}'";
}

// -----------------------------------------------------------------------------------------------------------------

/// Matches a single character in a set of character ranges.
///
/// Supports multiple ranges and an optional inversion flag for negated character
/// classes like `[^a-zA-Z0-9]`.
class CharSet extends Terminal {
  /// List of character ranges as (lo, hi) code unit pairs (inclusive).
  final List<(int, int)> ranges;

  /// If true, matches any character NOT in the set.
  final bool inverted;

  /// Create a CharSet from a list of code unit ranges.
  const CharSet(this.ranges, {this.inverted = false});

  /// Convenience constructor for a single character range.
  CharSet.range(String lo, String hi)
      : ranges = [(lo.codeUnitAt(0), hi.codeUnitAt(0))],
        inverted = false;

  /// Convenience constructor for a single character.
  CharSet.char(String c)
      : ranges = [(c.codeUnitAt(0), c.codeUnitAt(0))],
        inverted = false;

  /// Convenience constructor for a negated single character range.
  CharSet.notRange(String lo, String hi)
      : ranges = [(lo.codeUnitAt(0), hi.codeUnitAt(0))],
        inverted = true;

  @override
  MatchResult match(Parser parser, int pos, {Clause? bound}) {
    if (pos >= parser.input.length) return mismatch;
    final c = parser.input.codeUnitAt(pos);

    bool inSet = false;
    for (final (lo, hi) in ranges) {
      if (c >= lo && c <= hi) {
        inSet = true;
        break;
      }
    }

    if (inverted ? !inSet : inSet) {
      return Match(this, pos, 1);
    }
    return mismatch;
  }

  @override
  String toString() {
    final buf = StringBuffer('[');
    if (inverted) buf.write('^');
    for (final (lo, hi) in ranges) {
      if (lo == hi) {
        buf.write(escapeString(String.fromCharCode(lo)));
      } else {
        buf.write(escapeString(String.fromCharCode(lo)));
        buf.write('-');
        buf.write(escapeString(String.fromCharCode(hi)));
      }
    }
    buf.write(']');
    return buf.toString();
  }
}

// -----------------------------------------------------------------------------------------------------------------

/// Matches any single character.
class AnyChar extends Terminal {
  const AnyChar();

  @override
  MatchResult match(Parser parser, int pos, {Clause? bound}) {
    if (pos >= parser.input.length) return mismatch;
    return Match(this, pos, 1);
  }

  @override
  String toString() => '.';
}

// -----------------------------------------------------------------------------------------------------------------

/// Matches nothing - always succeeds without consuming any input.
class Nothing extends Terminal {
  const Nothing();

  @override
  MatchResult match(Parser parser, int pos, {Clause? bound}) {
    return Match(this, pos, 0);
  }

  @override
  String toString() => '()';
}
