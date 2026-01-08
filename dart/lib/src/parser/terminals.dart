import 'clause.dart';
import 'match_result.dart';
import 'parser.dart';

abstract class Terminal extends Clause {
  const Terminal({super.transparent});
}

/// Matches a literal string.
class Str extends Terminal {
  final String text;
  const Str(this.text, {super.transparent});

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
  String toString() => '"$text"';
}

/// Matches a single character.
class Char extends Terminal {
  final String char;
  const Char(this.char, {super.transparent}) : assert(char.length == 1);

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
  String toString() => '"$char"';
}

/// Matches a single character in a range [lo-hi].
class CharRange extends Terminal {
  final String lo, hi;
  const CharRange(this.lo, this.hi, {super.transparent});

  @override
  MatchResult match(Parser parser, int pos, {Clause? bound}) {
    if (pos >= parser.input.length) return mismatch;
    final c = parser.input.codeUnitAt(pos);
    if (c >= lo.codeUnitAt(0) && c <= hi.codeUnitAt(0)) {
      return Match(this, pos, 1);
    }
    return mismatch;
  }

  @override
  String toString() => '[$lo-$hi]';
}

/// Matches any single character.
class AnyChar extends Terminal {
  const AnyChar({super.transparent});

  @override
  MatchResult match(Parser parser, int pos, {Clause? bound}) {
    if (pos >= parser.input.length) return mismatch;
    return Match(this, pos, 1);
  }

  @override
  String toString() => '.';
}

/// Matches nothing - always succeeds without consuming any input.
class Nothing extends Terminal {
  const Nothing({super.transparent});

  @override
  MatchResult match(Parser parser, int pos, {Clause? bound}) {
    return Match(this, pos, 0);
  }

  @override
  String toString() => '()';
}
