import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/parser/utils.dart';

/// MetaGrammar: A grammar for defining PEG grammars.
///
/// Syntax:
/// - Rule: IDENT <- EXPR ;
/// - Sequence: EXPR EXPR
/// - Choice: EXPR / EXPR
/// - ZeroOrMore: EXPR*
/// - OneOrMore: EXPR+
/// - Optional: EXPR?
/// - Positive lookahead: &EXPR
/// - Negative lookahead: !EXPR
/// - String literal: "text" or 'char'
/// - Character class: [a-z] or [^a-z]
/// - Any character: .
/// - Grouping: (EXPR)
class MetaGrammar {
  /// The meta-grammar rules for parsing PEG grammars.
  static final Map<String, Clause> rules = {
    'Grammar': Seq([
      Ref('WS'),
      OneOrMore(Seq([
        Ref('Rule'),
        Ref('WS'),
      ])),
    ]),
    'Rule': Seq([
      Optional(Str('~')),
      Ref('Identifier'),
      Ref('WS'),
      Str('<-'),
      Ref('WS'),
      Ref('Expression'),
      Ref('WS'),
      Str(';'),
      Ref('WS'),
    ]),
    'Expression': Ref('Choice'),
    'Choice': Seq([
      Ref('Sequence'),
      ZeroOrMore(Seq([
        Ref('WS'),
        Str('/'),
        Ref('WS'),
        Ref('Sequence'),
      ])),
    ]),
    'Sequence': Seq([
      Ref('Prefix'),
      ZeroOrMore(Seq([
        Ref('WS'),
        Ref('Prefix'),
      ])),
    ]),
    'Prefix': First([
      Seq([Str('&'), Ref('WS'), Ref('Prefix')]),
      Seq([Str('!'), Ref('WS'), Ref('Prefix')]),
      Seq([Str('~'), Ref('WS'), Ref('Prefix')]),
      Ref('Suffix'),
    ]),
    'Suffix': First([
      Seq([Ref('Suffix'), Ref('WS'), Str('*')]),
      Seq([Ref('Suffix'), Ref('WS'), Str('+')]),
      Seq([Ref('Suffix'), Ref('WS'), Str('?')]),
      Ref('Primary'),
    ]),
    'Primary': First([
      Ref('Identifier'),
      Ref('StringLiteral'),
      Ref('CharLiteral'),
      Ref('CharClass'),
      Ref('AnyChar'),
      Ref('Parens'),
    ]),
    'Parens': Seq([
      Str('('),
      Ref('WS'),
      Optional(Ref('Expression')),
      Ref('WS'),
      Str(')'),
    ]),
    'Identifier': Seq([
      First([
        CharSet.range('a', 'z'),
        CharSet.range('A', 'Z'),
        Char('_'),
      ]),
      ZeroOrMore(First([
        CharSet.range('a', 'z'),
        CharSet.range('A', 'Z'),
        CharSet.range('0', '9'),
        Char('_'),
      ])),
    ]),
    'StringLiteral': Seq([
      Str('"'),
      ZeroOrMore(First([
        Ref('EscapeSequence'),
        Seq([
          NotFollowedBy(First([Str('"'), Str('\\')])),
          AnyChar(),
        ]),
      ])),
      Str('"'),
    ]),
    'CharLiteral': Seq([
      Str("'"),
      First([
        Ref('EscapeSequence'),
        Seq([
          NotFollowedBy(First([Str("'"), Str('\\')])),
          AnyChar(),
        ]),
      ]),
      Str("'"),
    ]),
    'EscapeSequence': Seq([
      Str('\\'),
      First([
        Char('n'),
        Char('r'),
        Char('t'),
        Char('\\'),
        Char('"'),
        Char("'"),
        Char('['),
        Char(']'),
        Char('-'),
      ]),
    ]),
    'CharClass': Seq([
      Str('['),
      Optional(Str('^')),
      OneOrMore(First([
        Ref('CharRange'),
        Ref('CharClassChar'),
      ])),
      Str(']'),
    ]),
    'CharRange': Seq([
      Ref('CharClassChar'),
      Str('-'),
      Ref('CharClassChar'),
    ]),
    'CharClassChar': First([
      Ref('EscapeSequence'),
      Seq([
        NotFollowedBy(First([Str(']'), Str('\\'), Str('-')])),
        AnyChar(),
      ]),
    ]),
    'AnyChar': Str('.'),
    '~WS': ZeroOrMore(First([
      Char(' '),
      Char('\t'),
      Char('\n'),
      Char('\r'),
      Ref('Comment'),
    ])),
    'Comment': Seq([
      Str('#'),
      ZeroOrMore(Seq([
        NotFollowedBy(Char('\n')),
        AnyChar(),
      ])),
      Optional(Char('\n')),
    ]),
  };

  /// The label used for terminal nodes in the AST.
  static const String _terminalLabel = '<Terminal>';

  /// Parse a grammar specification and return the rules.
  static Map<String, Clause> parseGrammar(String grammarSpec) {
    // Parse the grammar spec using the meta-grammar
    final parseResult = Parser(rules: rules, topRuleName: 'Grammar', input: grammarSpec).parse();
    if (parseResult.hasSyntaxErrors) {
      throw FormatException('Failed to parse grammar. Syntax errors:\n'
          '${parseResult.getSyntaxErrors().map((e) => e.toString()).join('\n')}');
    }

    // Convert parse tree to AST
    final ast = buildAST(parseResult: parseResult);

    final grammarMap = <String, Clause>{};

    // AST root is 'Grammar', children are 'Rule' nodes
    for (final ruleNode in ast.children) {
      if (ruleNode.label != 'Rule') {
        continue; // Skip non-Rule nodes (syntax errors, etc.)
      }

      // Find the Identifier child to get rule name
      final identifierNode = ruleNode.children.firstWhere(
        (c) => c.label == 'Identifier',
        orElse: () => throw FormatException('Rule has no Identifier child'),
      );
      final ruleName = identifierNode.getInputSpan(grammarSpec);

      // Find the Expression child for the rule body
      final expressionNode = ruleNode.children.firstWhere(
        (c) => c.label == 'Expression',
        orElse: () => throw FormatException('Rule has no Expression child'),
      );

      // Check for transparent marker ('~' terminal before identifier)
      bool isTransparent = false;
      for (final child in ruleNode.children) {
        if (child.label == _terminalLabel && child.getInputSpan(grammarSpec) == '~') {
          isTransparent = true;
          break;
        }
        if (child.label == 'Identifier') {
          // Stop looking once we reach the identifier
          break;
        }
      }

      // Build the clause from the expression
      final clause = _buildClause(expressionNode, grammarSpec);

      // Store with transparent prefix if specified
      if (isTransparent) {
        grammarMap['~$ruleName'] = clause;
      } else {
        grammarMap[ruleName] = clause;
      }
    }

    // Check that there isn't a rule with the same name as a transparent rule (e.g. 'WS' and '~WS')
    for (final ruleName in grammarMap.keys) {
      if (ruleName.startsWith('~') && grammarMap.containsKey(ruleName.substring(1)) ||
          !ruleName.startsWith('~') && grammarMap.containsKey('~$ruleName')) {
        throw FormatException('Rule "$ruleName" cannot be both transparent and non-transparent');
      }
    }
    // Check that rules can be found for all references in the grammar
    for (final clause in grammarMap.values) {
      clause.checkRuleRefs(grammarMap);
    }
    return grammarMap;
  }

  /// Build a Clause from an AST node.
  static Clause _buildClause(ASTNode node, String input) {
    switch (node.label) {
      case 'Expression':
        // Expression wraps Choice; delegate to the single child
        if (node.children.length == 1) {
          return _buildClause(node.children[0], input);
        }
        throw FormatException('Expression should have exactly one child, got ${node.children.length}');

      case 'Choice':
        // Choice contains Sequence nodes (and possibly '/' terminals)
        final sequences =
            node.children.where((c) => c.label == 'Sequence').map((c) => _buildClause(c, input)).toList();
        if (sequences.isEmpty) {
          throw FormatException('Choice has no Sequence children');
        }
        return sequences.length == 1 ? sequences[0] : First(sequences);

      case 'Sequence':
        // Sequence contains Prefix nodes
        final prefixes =
            node.children.where((c) => c.label == 'Prefix').map((c) => _buildClause(c, input)).toList();
        if (prefixes.isEmpty) {
          throw FormatException('Sequence has no Prefix children');
        }
        return prefixes.length == 1 ? prefixes[0] : Seq(prefixes);

      case 'Prefix':
        // Check for prefix operators (&, !, ~)
        String? prefixOp;
        for (final child in node.children) {
          if (child.label == _terminalLabel) {
            final text = child.getInputSpan(input);
            if (text == '&' || text == '!' || text == '~') {
              prefixOp = text;
              break;
            }
          }
        }

        // Find the operand (either another Prefix or a Suffix)
        final operand = node.children.firstWhere(
          (c) => c.label == 'Prefix' || c.label == 'Suffix',
          orElse: () => throw FormatException('Prefix has no Prefix/Suffix child'),
        );
        final operandClause = _buildClause(operand, input);

        switch (prefixOp) {
          case '&':
            return FollowedBy(operandClause);
          case '!':
            return NotFollowedBy(operandClause);
          case '~':
            // Transparent marker at expression level; does not affect clause structure
            return operandClause;
          default:
            return operandClause;
        }

      case 'Suffix':
        // Check for suffix operators (*, +, ?)
        String? suffixOp;
        for (final child in node.children) {
          if (child.label == _terminalLabel) {
            final text = child.getInputSpan(input);
            if (text == '*' || text == '+' || text == '?') {
              suffixOp = text;
              break;
            }
          }
        }

        // Find the operand (either another Suffix or a Primary)
        final operand = node.children.firstWhere(
          (c) => c.label == 'Suffix' || c.label == 'Primary',
          orElse: () => throw FormatException('Suffix has no Suffix/Primary child'),
        );
        final operandClause = _buildClause(operand, input);

        switch (suffixOp) {
          case '*':
            return ZeroOrMore(operandClause);
          case '+':
            return OneOrMore(operandClause);
          case '?':
            return Optional(operandClause);
          default:
            return operandClause;
        }

      case 'Primary':
        // Primary wraps one of: Identifier, StringLiteral, CharLiteral, CharClass, AnyChar, Parens
        for (final child in node.children) {
          if (child.label != _terminalLabel) {
            return _buildClause(child, input);
          }
        }
        throw FormatException('Primary has no semantic child');

      case 'Parens':
        // Find Expression child, or return Nothing for empty parens
        for (final child in node.children) {
          if (child.label == 'Expression') {
            return _buildClause(child, input);
          }
        }
        return Nothing();

      case 'Identifier':
        return Ref(node.getInputSpan(input));

      case 'StringLiteral':
        // Strip quotes and unescape
        final text = node.getInputSpan(input);
        return Str(unescapeString(text.substring(1, text.length - 1)));

      case 'CharLiteral':
        // Strip quotes and unescape
        final text = node.getInputSpan(input);
        return Char(unescapeChar(text.substring(1, text.length - 1)));

      case 'CharClass':
        return _buildCharClass(node, input);

      case 'AnyChar':
        return AnyChar();

      case _terminalLabel:
        throw FormatException('Unexpected bare terminal in clause building: "${node.getInputSpan(input)}"');

      default:
        throw FormatException('Unknown AST node label: ${node.label}');
    }
  }

  /// Build a character class clause from a CharClass AST node.
  static Clause _buildCharClass(ASTNode node, String input) {
    // Check for negation ('^' terminal)
    bool negated = false;
    for (final child in node.children) {
      if (child.label == _terminalLabel && child.getInputSpan(input) == '^') {
        negated = true;
        break;
      }
    }

    final ranges = <(int, int)>[];

    for (final child in node.children) {
      if (child.label == 'CharRange') {
        // CharRange contains two CharClassChar children (with '-' terminal between)
        final charClassChars = child.children.where((c) => c.label == 'CharClassChar').toList();
        if (charClassChars.length != 2) {
          throw FormatException('CharRange must have exactly 2 CharClassChar children');
        }
        final lo = _extractCharClassCharValue(charClassChars[0], input);
        final hi = _extractCharClassCharValue(charClassChars[1], input);
        ranges.add((lo.codeUnitAt(0), hi.codeUnitAt(0)));
      } else if (child.label == 'CharClassChar') {
        final ch = _extractCharClassCharValue(child, input);
        ranges.add((ch.codeUnitAt(0), ch.codeUnitAt(0)));
      }
    }

    if (ranges.isEmpty) {
      throw FormatException('CharClass has no character items');
    }

    return CharSet(ranges, inverted: negated);
  }

  /// Extract the character value from a CharClassChar AST node.
  ///
  /// CharClassChar can be either:
  /// - An EscapeSequence (e.g., \n, \t, \\)
  /// - A plain character (terminals from AnyChar)
  static String _extractCharClassCharValue(ASTNode node, String input) {
    // Check if this CharClassChar contains an EscapeSequence
    for (final child in node.children) {
      if (child.label == 'EscapeSequence') {
        return unescapeChar(child.getInputSpan(input));
      }
    }
    // Otherwise, it is a plain character (possibly from AnyChar terminal)
    // The whole node span is the character
    return unescapeChar(node.getInputSpan(input));
  }
}

void main(List<String> args) {
  final parsedRules = MetaGrammar.parseGrammar('''
    ~WS <- [ \\t\\n\\r]*;
    ~Comment <- "#" [^\\n]* "\\n"?;
    Identifier <- [a-zA-Z_][a-zA-Z0-9_]*;
    StringLiteral <- '"' (EscapeSequence / [^"\\\\])* '"';
    CharLiteral <- "'" (EscapeSequence / [^'\\\\]) "'";
    EscapeSequence <- '\\\\' [nrt\\\\"'\\[\\]\\-];
  ''');

  print('Parsed ${parsedRules.length} rules:');
  for (final entry in parsedRules.entries) {
    print('  ${entry.key}: ${entry.value}');
  }
}
