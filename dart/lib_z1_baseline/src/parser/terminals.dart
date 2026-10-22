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
  MatchResult match(Parser parser, int pos) {
    // HOW MUCH OF THE LITERAL THE INPUT DID SUPPLY is frontier information the
    // old tombstone threw away: `fun` of `function` puts the error three
    // characters in, not at the keyword's start. Running off the end of the
    // input is the same question with a shorter answer, so both are counted
    // by one loop.
    final room = parser.input.length - pos;
    final limit = text.length < room ? text.length : room;
    var i = 0;
    while (i < limit && parser.input.codeUnitAt(pos + i) == text.codeUnitAt(i)) {
      i++;
    }
    if (i == text.length) return Match(this, pos, text.length);
    return Mismatch(this, pos, i);
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
  MatchResult match(Parser parser, int pos) {
    if (pos + char.length > parser.input.length) return Mismatch(this, pos, 0);
    for (int i = 0; i < char.length; i++) {
      if (parser.input.codeUnitAt(pos + i) != char.codeUnitAt(i)) {
        return Mismatch(this, pos, 0);
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
  MatchResult match(Parser parser, int pos) {
    if (pos >= parser.input.length) return Mismatch(this, pos, 0);
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
    return Mismatch(this, pos, 0);
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
  MatchResult match(Parser parser, int pos) {
    if (pos >= parser.input.length) return Mismatch(this, pos, 0);
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
  MatchResult match(Parser parser, int pos) {
    return Match(this, pos, 0);
  }

  @override
  String toString() => '()';
}
