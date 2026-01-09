import '../squirrel_parser.dart';

/// MetaGrammar - A grammar for defining PEG grammars.
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
      Ref('_'),
      OneOrMore(Ref('Rule')),
      Ref('_'),
    ]),
    'Rule': Seq([
      Optional(Str('~')),
      Ref('Identifier'),
      Ref('_'),
      Str('<-'),
      Ref('_'),
      Ref('Expression'),
      Ref('_'),
      Str(';'),
      Ref('_'),
    ]),
    'Expression': Ref('Choice'),
    'Choice': Seq([
      Ref('Sequence'),
      ZeroOrMore(Seq([
        Ref('_'),
        Str('/'),
        Ref('_'),
        Ref('Sequence'),
      ])),
    ]),
    'Sequence': Seq([
      Ref('Prefix'),
      ZeroOrMore(Seq([
        Ref('_'),
        Ref('Prefix'),
      ])),
    ]),
    'Prefix': First([
      Seq([Str('&'), Ref('_'), Ref('Prefix')]),
      Seq([Str('!'), Ref('_'), Ref('Prefix')]),
      Seq([Str('~'), Ref('_'), Ref('Prefix')]),
      Ref('Suffix'),
    ]),
    'Suffix': First([
      Seq([Ref('Suffix'), Ref('_'), Str('*')]),
      Seq([Ref('Suffix'), Ref('_'), Str('+')]),
      Seq([Ref('Suffix'), Ref('_'), Str('?')]),
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
      Ref('_'),
      Optional(Ref('Expression')),
      Ref('_'),
      Str(')'),
    ]),
    'Identifier': Seq([
      First([
        CharRange('a', 'z'),
        CharRange('A', 'Z'),
        Char('_'),
      ]),
      ZeroOrMore(First([
        CharRange('a', 'z'),
        CharRange('A', 'Z'),
        CharRange('0', '9'),
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
    '_': ZeroOrMore(First([
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

  /// Parse a grammar specification and return the rules.
  static Map<String, Clause> parseGrammar(String grammarText) {
    final parser = Parser(rules: rules, input: grammarText);
    final (ast, _) = parser.parseToAST('Grammar');

    // Get syntax errors from the parse (single additional parse for error reporting)
    final (matchResult, _) = parser.parse('Grammar');
    final syntaxErrors = getSyntaxErrors(matchResult);

    if (syntaxErrors.isNotEmpty) {
      throw FormatException(
          'Failed to parse grammar. Syntax errors:\n${syntaxErrors.map((e) => e.toString()).join('\n')}');
    }

    return _buildGrammarRules(ast, grammarText);
  }

  /// Build grammar rules from the AST.
  static Map<String, Clause> _buildGrammarRules(ASTNode ast, String input) {
    final result = <String, Clause>{};
    final transparentRules = <String>{};

    for (final ruleNode in ast.children.where((n) => n.label == 'Rule')) {
      // Get rule name (first Identifier child)
      final ruleNameNode =
          ruleNode.children.where((c) => c.label == 'Identifier').first;
      final ruleName = ruleNameNode.text;

      // Get rule body (first Expression child)
      final ruleBody =
          ruleNode.children.where((c) => c.label == 'Expression').first;

      // Check for transparent marker (first child is Str with text '~')
      final hasTransparentMarker =
          ruleNode.children.any((c) => c.label == 'Str' && c.text == '~');

      if (hasTransparentMarker) {
        transparentRules.add(ruleName);
      }

      result[ruleName] = _buildClause(ruleBody, input,
          transparent: hasTransparentMarker,
          transparentRules: transparentRules);
    }

    return result;
  }

  /// Build a Clause from an AST node.
  static Clause _buildClause(ASTNode node, String input,
      {bool transparent = false, Set<String> transparentRules = const {}}) {
    // Skip whitespace and other non-semantic nodes
    if (_shouldSkipNode(node.label)) {
      // If this node has children, try to build from them
      if (node.children.isNotEmpty) {
        final semanticChildren =
            node.children.where((c) => !_shouldSkipNode(c.label)).toList();
        if (semanticChildren.length == 1) {
          return _buildClause(semanticChildren[0], input,
              transparent: transparent, transparentRules: transparentRules);
        }
      }
      throw FormatException('Cannot build clause from: ${node.label}');
    }

    // For nodes that are wrappers/intermediate nodes, recurse into their children
    if (_isWrapperNode(node.label)) {
      // For wrapper nodes, filter out whitespace and other non-semantic nodes
      final semanticChildren =
          node.children.where((c) => !_shouldSkipNode(c.label)).toList();
      if (semanticChildren.isEmpty) {
        throw FormatException(
            'Wrapper node ${node.label} has no semantic children');
      }
      if (semanticChildren.length == 1) {
        return _buildClause(semanticChildren[0], input,
            transparent: transparent, transparentRules: transparentRules);
      }
      // Multiple children - treat as sequence
      return Seq(
          semanticChildren
              .map((c) =>
                  _buildClause(c, input, transparentRules: transparentRules))
              .toList(),
          transparent: transparent);
    }

    switch (node.label) {
      case 'Choice':
        final semanticChildren =
            node.children.where((c) => !_shouldSkipNode(c.label)).toList();
        final sequences = semanticChildren
            .map((child) => _buildClause(child, input,
                transparent: transparent, transparentRules: transparentRules))
            .toList();
        return sequences.length == 1
            ? sequences[0]
            : First(sequences, transparent: transparent);

      case 'Sequence':
        final semanticChildren =
            node.children.where((c) => !_shouldSkipNode(c.label)).toList();
        final items = semanticChildren
            .map((child) => _buildClause(child, input,
                transparent: transparent, transparentRules: transparentRules))
            .toList();
        return items.length == 1
            ? items[0]
            : Seq(items, transparent: transparent);

      case 'Prefix':
        // Check if there's a prefix operator (&, !, ~)
        final operatorNode =
            node.children.where((c) => c.label == 'Str').firstOrNull;
        // Prefix can contain either another Prefix (for stacking) or a Suffix
        final childNode = node.children
            .where((c) => c.label == 'Prefix' || c.label == 'Suffix')
            .firstOrNull;

        if (childNode == null) {
          throw FormatException('Prefix node has no Prefix/Suffix child');
        }

        final childClause = _buildClause(childNode, input,
            transparent: transparent, transparentRules: transparentRules);

        if (operatorNode == null) {
          // No prefix operator, just return the child
          return childClause;
        }

        switch (operatorNode.text) {
          case '&':
            return FollowedBy(childClause);
          case '!':
            return NotFollowedBy(childClause);
          case '~':
            // Transparent marker - return child with transparent flag
            return _buildClause(childNode, input,
                transparent: true, transparentRules: transparentRules);
          default:
            throw FormatException(
                'Unknown prefix operator: ${operatorNode.text}');
        }

      case 'Suffix':
        // Check if there's a suffix operator (*, +, ?)
        final operatorNode =
            node.children.where((c) => c.label == 'Str').firstOrNull;
        // Suffix can contain either another Suffix (for stacking) or a Primary
        final childNode = node.children
            .where((c) => c.label == 'Suffix' || c.label == 'Primary')
            .firstOrNull;

        if (childNode == null) {
          throw FormatException('Suffix node has no Suffix/Primary child');
        }

        final childClause = _buildClause(childNode, input,
            transparent: transparent, transparentRules: transparentRules);

        if (operatorNode == null) {
          // No suffix operator, just return the child
          return childClause;
        }

        switch (operatorNode.text) {
          case '*':
            return ZeroOrMore(childClause, transparent: transparent);
          case '+':
            return OneOrMore(childClause, transparent: transparent);
          case '?':
            return Optional(childClause, transparent: transparent);
          default:
            throw FormatException(
                'Unknown suffix operator: ${operatorNode.text}');
        }

      case 'Parens':
        // Parens can contain: Str('('), _, Optional(Expression), _, Str(')')
        // Find the Expression child (if it exists after parsing)
        final expressionChild =
            node.children.where((c) => c.label == 'Expression').firstOrNull;
        if (expressionChild != null) {
          // Parens with content - return the expression
          return _buildClause(expressionChild, input,
              transparent: transparent, transparentRules: transparentRules);
        } else {
          // Empty parens - return Nothing
          return Nothing(transparent: transparent);
        }

      case 'Identifier':
        // This is a rule reference - check if the referenced rule is transparent
        final isRefTransparent =
            transparent || transparentRules.contains(node.text);
        return Ref(node.text, transparent: isRefTransparent);

      case 'StringLiteral':
        return Str(
            _unescapeString(node.text.substring(1, node.text.length - 1)));

      case 'CharLiteral':
        return Char(
            _unescapeChar(node.text.substring(1, node.text.length - 1)));

      case 'CharClass':
        return _buildCharClass(node, input);

      case 'AnyChar':
        return AnyChar();

      case 'And':
        return FollowedBy(_buildClause(node.children[0], input,
            transparentRules: transparentRules));

      case 'Not':
        return NotFollowedBy(_buildClause(node.children[0], input,
            transparentRules: transparentRules));

      case 'Transparent':
        // Mark the child clause as transparent
        return _buildClause(node.children[0], input,
            transparent: true, transparentRules: transparentRules);

      case 'ZeroOrMore':
        return ZeroOrMore(
            _buildClause(node.children[0], input,
                transparentRules: transparentRules),
            transparent: transparent);

      case 'OneOrMore':
        return OneOrMore(
            _buildClause(node.children[0], input,
                transparentRules: transparentRules),
            transparent: transparent);

      case 'Optional':
        return Optional(
            _buildClause(node.children[0], input,
                transparentRules: transparentRules),
            transparent: transparent);

      case 'Group':
        return _buildClause(node.children[0], input,
            transparent: transparent, transparentRules: transparentRules);

      default:
        // For unlabeled nodes, recursively build their children
        if (node.children.isEmpty) {
          throw FormatException('Cannot build clause from: ${node.label}');
        }
        if (node.children.length == 1) {
          return _buildClause(node.children[0], input,
              transparent: transparent, transparentRules: transparentRules);
        }
        return Seq(node.children
            .map((child) =>
                _buildClause(child, input, transparentRules: transparentRules))
            .toList());
    }
  }

  /// Build a character class clause.
  static Clause _buildCharClass(ASTNode node, String input) {
    // Check if there's a "^" character indicating negation
    final negated = node.children.any((c) => c.label == 'Str' && c.text == '^');
    final items = <Clause>[];

    for (final child in node.children) {
      if (child.label == 'CharRange') {
        // CharRange has two CharClassChar children (and a Str: "-" in between)
        final charClassChars =
            child.children.where((c) => c.label == 'CharClassChar').toList();
        if (charClassChars.length != 2) {
          throw FormatException(
              'CharRange must have exactly 2 CharClassChar children');
        }
        final lo = _unescapeChar(charClassChars[0].text);
        final hi = _unescapeChar(charClassChars[1].text);
        items.add(CharRange(lo, hi));
      } else if (child.label == 'CharClassChar') {
        final ch = _unescapeChar(child.text);
        items.add(Char(ch));
      }
    }

    final clause = items.length == 1 ? items[0] : First(items);
    // Negated character class: ![class] . (not in class, then consume any char)
    return negated ? Seq([NotFollowedBy(clause), AnyChar()]) : clause;
  }

  /// Unescape a string literal.
  static String _unescapeString(String str) {
    return str
        .replaceAll('\\n', '\n')
        .replaceAll('\\r', '\r')
        .replaceAll('\\t', '\t')
        .replaceAll('\\\\', '\\')
        .replaceAll('\\"', '"')
        .replaceAll("\\'", "'");
  }

  /// Unescape a character literal.
  static String _unescapeChar(String str) {
    if (str.length == 1) return str;
    if (str.startsWith('\\')) {
      switch (str[1]) {
        case 'n':
          return '\n';
        case 'r':
          return '\r';
        case 't':
          return '\t';
        case '\\':
          return '\\';
        case '"':
          return '"';
        case "'":
          return "'";
        default:
          return str[1];
      }
    }
    return str;
  }

  /// Check if a node should be skipped when building clauses.
  static bool _shouldSkipNode(String label) {
    return label == '_' || // Whitespace
        label == 'Whitespace' || // Whitespace alternative name
        label == 'Comment' || // Comments
        label == 'Str' || // Terminal string match
        label == 'Char' || // Terminal char match
        label == 'CharRange'; // Terminal char range match
  }

  /// Check if a node is a wrapper/intermediate grammatical node.
  static bool _isWrapperNode(String label) {
    return label == 'Expression' ||
        label == 'RuleBody' ||
        label == 'Primary' ||
        label == 'Group';
  }
}
