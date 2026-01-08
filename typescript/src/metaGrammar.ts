/**
 * MetaGrammar - A grammar for defining PEG grammars.
 *
 * Syntax:
 * - Rule: IDENT <- EXPR ;
 * - Sequence: EXPR EXPR
 * - Choice: EXPR / EXPR
 * - ZeroOrMore: EXPR*
 * - OneOrMore: EXPR+
 * - Optional: EXPR?
 * - Positive lookahead: &EXPR
 * - Negative lookahead: !EXPR
 * - String literal: "text" or 'char'
 * - Character class: [a-z] or [^a-z]
 * - Any character: .
 * - Grouping: (EXPR)
 */

import type { Clause } from './clause';
import { Seq, First, OneOrMore, ZeroOrMore, Optional, NotFollowedBy, FollowedBy, Ref } from './combinators';
import { Str, Char, CharRange, AnyChar } from './terminals';
import { squirrelParse } from './squirrelParse';
import { ASTNode } from './ast';

export class MetaGrammar {
  /**
   * The meta-grammar rules for parsing PEG grammars.
   */
  static readonly rules: Record<string, Clause> = {
    Grammar: new Seq([
      new Ref('_'),
      new OneOrMore(new Ref('Rule')),
      new Ref('_'),
    ]),
    Rule: new Seq([
      new Optional(new Str('~')),
      new Ref('Identifier'),
      new Ref('_'),
      new Str('<-'),
      new Ref('_'),
      new Ref('Expression'),
      new Ref('_'),
      new Str(';'),
      new Ref('_'),
    ]),
    Expression: new Ref('Choice'),
    Choice: new Seq([
      new Ref('Sequence'),
      new ZeroOrMore(new Seq([
        new Ref('_'),
        new Str('/'),
        new Ref('_'),
        new Ref('Sequence'),
      ])),
    ]),
    Sequence: new Seq([
      new Ref('Prefix'),
      new ZeroOrMore(new Seq([
        new Ref('_'),
        new Ref('Prefix'),
      ])),
    ]),
    Prefix: new First([
      new Seq([new Str('&'), new Ref('_'), new Ref('Prefix')]),
      new Seq([new Str('!'), new Ref('_'), new Ref('Prefix')]),
      new Seq([new Str('~'), new Ref('_'), new Ref('Prefix')]),
      new Ref('Suffix'),
    ]),
    Suffix: new First([
      new Seq([new Ref('Suffix'), new Ref('_'), new Str('*')]),
      new Seq([new Ref('Suffix'), new Ref('_'), new Str('+')]),
      new Seq([new Ref('Suffix'), new Ref('_'), new Str('?')]),
      new Ref('Primary'),
    ]),
    Primary: new First([
      new Ref('Identifier'),
      new Ref('StringLiteral'),
      new Ref('CharLiteral'),
      new Ref('CharClass'),
      new Ref('AnyChar'),
      new Seq([new Str('('), new Ref('_'), new Ref('Expression'), new Ref('_'), new Str(')')]),
    ]),
    Identifier: new Seq([
      new First([
        new CharRange('a', 'z'),
        new CharRange('A', 'Z'),
        new Char('_'),
      ]),
      new ZeroOrMore(new First([
        new CharRange('a', 'z'),
        new CharRange('A', 'Z'),
        new CharRange('0', '9'),
        new Char('_'),
      ])),
    ]),
    StringLiteral: new Seq([
      new Str('"'),
      new ZeroOrMore(new First([
        new Ref('EscapeSequence'),
        new Seq([
          new NotFollowedBy(new First([new Str('"'), new Str('\\')])),
          new AnyChar(),
        ]),
      ])),
      new Str('"'),
    ]),
    CharLiteral: new Seq([
      new Str("'"),
      new First([
        new Ref('EscapeSequence'),
        new Seq([
          new NotFollowedBy(new First([new Str("'"), new Str('\\')])),
          new AnyChar(),
        ]),
      ]),
      new Str("'"),
    ]),
    EscapeSequence: new Seq([
      new Str('\\'),
      new First([
        new Char('n'),
        new Char('r'),
        new Char('t'),
        new Char('\\'),
        new Char('"'),
        new Char("'"),
      ]),
    ]),
    CharClass: new Seq([
      new Str('['),
      new Optional(new Str('^')),
      new OneOrMore(new First([
        new Ref('CharRange'),
        new Ref('CharClassChar'),
      ])),
      new Str(']'),
    ]),
    CharRange: new Seq([
      new Ref('CharClassChar'),
      new Str('-'),
      new Ref('CharClassChar'),
    ]),
    CharClassChar: new First([
      new Ref('EscapeSequence'),
      new Seq([
        new NotFollowedBy(new First([new Str(']'), new Str('\\'), new Str('-')])),
        new AnyChar(),
      ]),
    ]),
    AnyChar: new Str('.'),
    _: new ZeroOrMore(new First([
      new Char(' '),
      new Char('\t'),
      new Char('\n'),
      new Char('\r'),
      new Ref('Comment'),
    ])),
    Comment: new Seq([
      new Str('#'),
      new ZeroOrMore(new Seq([
        new NotFollowedBy(new Char('\n')),
        new AnyChar(),
      ])),
      new Optional(new Char('\n')),
    ]),
  };

  /**
   * Parse a grammar specification and return the rules.
   */
  static parseGrammar(grammarText: string): Record<string, Clause> {
    const [ast, syntaxErrors] = squirrelParse(MetaGrammar.rules, 'Grammar', grammarText);

    if (syntaxErrors.length > 0) {
      const errorMessages = syntaxErrors.map(e => e.toString()).join('\n');
      throw new Error(`Failed to parse grammar. Syntax errors:\n${errorMessages}`);
    }

    return MetaGrammar.buildGrammarRules(ast, grammarText);
  }

  /**
   * Build grammar rules from the AST.
   */
  private static buildGrammarRules(ast: ASTNode, input: string): Record<string, Clause> {
    const result: Record<string, Clause> = {};
    const transparentRules = new Set<string>();

    for (const ruleNode of ast.children.filter(n => n.label === 'Rule')) {
      // Get rule name (first Identifier child)
      const ruleNameNode = ruleNode.children.find(c => c.label === 'Identifier');
      if (!ruleNameNode) {
        throw new Error('Rule missing Identifier');
      }
      const ruleName = ruleNameNode.text;

      // Get rule body (first Expression child)
      const ruleBody = ruleNode.children.find(c => c.label === 'Expression');
      if (!ruleBody) {
        throw new Error('Rule missing Expression');
      }

      // Check for transparent marker (first child is Str with text '~')
      const hasTransparentMarker = ruleNode.children.some(c => c.label === 'Str' && c.text === '~');

      if (hasTransparentMarker) {
        transparentRules.add(ruleName);
      }

      result[ruleName] = MetaGrammar.buildClause(ruleBody, input, false, transparentRules);
    }

    return result;
  }

  /**
   * Build a Clause from an AST node.
   */
  private static buildClause(
    node: ASTNode,
    input: string,
    transparent: boolean = false,
    transparentRules: Set<string> = new Set()
  ): Clause {
    // Skip whitespace and other non-semantic nodes
    if (MetaGrammar.shouldSkipNode(node.label)) {
      // If this node has children, try to build from them
      if (node.children.length > 0) {
        const semanticChildren = node.children.filter(c => !MetaGrammar.shouldSkipNode(c.label));
        if (semanticChildren.length === 1) {
          return MetaGrammar.buildClause(semanticChildren[0], input, transparent, transparentRules);
        }
      }
      throw new Error(`Cannot build clause from: ${node.label}`);
    }

    // For nodes that are wrappers/intermediate nodes, recurse into their children
    if (MetaGrammar.isWrapperNode(node.label)) {
      // For wrapper nodes, filter out whitespace and other non-semantic nodes
      const semanticChildren = node.children.filter(c => !MetaGrammar.shouldSkipNode(c.label));
      if (semanticChildren.length === 0) {
        throw new Error(`Wrapper node ${node.label} has no semantic children`);
      }
      if (semanticChildren.length === 1) {
        return MetaGrammar.buildClause(semanticChildren[0], input, transparent, transparentRules);
      }
      // Multiple children - treat as sequence
      return new Seq(
        semanticChildren.map(c => MetaGrammar.buildClause(c, input, false, transparentRules)),
        transparent
      );
    }

    switch (node.label) {
      case 'Prefix': {
        // Check if there's a prefix operator (&, !, ~)
        const operatorNode = node.children.find(c => c.label === 'Str');
        // Prefix can contain either another Prefix (for stacking) or a Suffix
        const childNode = node.children.find(c => c.label === 'Prefix' || c.label === 'Suffix');

        if (!childNode) {
          throw new Error('Prefix node has no Prefix/Suffix child');
        }

        const childClause = MetaGrammar.buildClause(childNode, input, false, transparentRules);

        if (!operatorNode) {
          // No prefix operator, just return the child
          return childClause;
        }

        switch (operatorNode.text) {
          case '&':
            return new FollowedBy(childClause);
          case '!':
            return new NotFollowedBy(childClause);
          case '~':
            // Transparent marker - return child with transparent flag
            return MetaGrammar.buildClause(childNode, input, true, transparentRules);
          default:
            throw new Error(`Unknown prefix operator: ${operatorNode.text}`);
        }
      }

      case 'Suffix': {
        // Check if there's a suffix operator (*, +, ?)
        const operatorNode = node.children.find(c => c.label === 'Str');
        // Suffix can contain either another Suffix (for stacking) or a Primary
        const childNode = node.children.find(c => c.label === 'Suffix' || c.label === 'Primary');

        if (!childNode) {
          throw new Error('Suffix node has no Suffix/Primary child');
        }

        const childClause = MetaGrammar.buildClause(childNode, input, false, transparentRules);

        if (!operatorNode) {
          // No suffix operator, just return the child
          return childClause;
        }

        switch (operatorNode.text) {
          case '*':
            return new ZeroOrMore(childClause, transparent);
          case '+':
            return new OneOrMore(childClause, transparent);
          case '?':
            return new Optional(childClause, transparent);
          default:
            throw new Error(`Unknown suffix operator: ${operatorNode.text}`);
        }
      }

      case 'Choice': {
        const semanticChildren = node.children.filter(c => !MetaGrammar.shouldSkipNode(c.label));
        const sequences = semanticChildren.map(child =>
          MetaGrammar.buildClause(child, input, false, transparentRules)
        );
        return sequences.length === 1
          ? sequences[0]
          : new First(sequences, transparent);
      }

      case 'Sequence': {
        const semanticChildren = node.children.filter(c => !MetaGrammar.shouldSkipNode(c.label));
        const items = semanticChildren.map(child =>
          MetaGrammar.buildClause(child, input, false, transparentRules)
        );
        return items.length === 1
          ? items[0]
          : new Seq(items, transparent);
      }

      case 'And':
        return new FollowedBy(
          MetaGrammar.buildClause(node.children[0], input, false, transparentRules)
        );

      case 'Not':
        return new NotFollowedBy(
          MetaGrammar.buildClause(node.children[0], input, false, transparentRules)
        );

      case 'Transparent':
        // Mark the child clause as transparent
        return MetaGrammar.buildClause(node.children[0], input, true, transparentRules);

      case 'ZeroOrMore':
        return new ZeroOrMore(
          MetaGrammar.buildClause(node.children[0], input, false, transparentRules),
          transparent
        );

      case 'OneOrMore':
        return new OneOrMore(
          MetaGrammar.buildClause(node.children[0], input, false, transparentRules),
          transparent
        );

      case 'Optional':
        return new Optional(
          MetaGrammar.buildClause(node.children[0], input, false, transparentRules),
          transparent
        );

      case 'Identifier': {
        // This is a rule reference - check if the referenced rule is transparent
        const isRefTransparent = transparent || transparentRules.has(node.text);
        return new Ref(node.text, isRefTransparent);
      }

      case 'StringLiteral':
        return new Str(
          MetaGrammar.unescapeString(node.text.substring(1, node.text.length - 1))
        );

      case 'CharLiteral':
        return new Char(
          MetaGrammar.unescapeChar(node.text.substring(1, node.text.length - 1))
        );

      case 'CharClass':
        return MetaGrammar.buildCharClass(node, input);

      case 'AnyChar':
        return new AnyChar();

      case 'Group':
        return MetaGrammar.buildClause(node.children[0], input, transparent, transparentRules);

      default:
        // For unlabeled nodes, recursively build their children
        if (node.children.length === 0) {
          throw new Error(`Cannot build clause from: ${node.label}`);
        }
        if (node.children.length === 1) {
          return MetaGrammar.buildClause(node.children[0], input, transparent, transparentRules);
        }
        return new Seq(
          node.children.map(child =>
            MetaGrammar.buildClause(child, input, false, transparentRules)
          )
        );
    }
  }

  /**
   * Build a character class clause.
   */
  private static buildCharClass(node: ASTNode, _input: string): Clause {
    // Check if there's a "^" character indicating negation
    const negated = node.children.some(c => c.label === 'Str' && c.text === '^');
    const items: Clause[] = [];

    for (const child of node.children) {
      if (child.label === 'CharRange') {
        // CharRange has two CharClassChar children (and a Str: "-" in between)
        const charClassChars = child.children.filter(c => c.label === 'CharClassChar');
        if (charClassChars.length !== 2) {
          throw new Error('CharRange must have exactly 2 CharClassChar children');
        }
        const lo = MetaGrammar.unescapeChar(charClassChars[0].text);
        const hi = MetaGrammar.unescapeChar(charClassChars[1].text);
        items.push(new CharRange(lo, hi));
      } else if (child.label === 'CharClassChar') {
        const ch = MetaGrammar.unescapeChar(child.text);
        items.push(new Char(ch));
      }
    }

    const clause = items.length === 1 ? items[0] : new First(items);
    // Negated character class: ![class] . (not in class, then consume any char)
    return negated ? new Seq([new NotFollowedBy(clause), new AnyChar()]) : clause;
  }

  /**
   * Unescape a string literal.
   */
  private static unescapeString(str: string): string {
    return str
      .replace(/\\n/g, '\n')
      .replace(/\\r/g, '\r')
      .replace(/\\t/g, '\t')
      .replace(/\\\\/g, '\\')
      .replace(/\\"/g, '"')
      .replace(/\\'/g, "'");
  }

  /**
   * Unescape a character literal.
   */
  private static unescapeChar(str: string): string {
    if (str.length === 1) return str;
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

  /**
   * Check if a node should be skipped when building clauses.
   */
  private static shouldSkipNode(label: string): boolean {
    return (
      label === '_' || // Whitespace
      label === 'Whitespace' || // Whitespace alternative name
      label === 'Comment' || // Comments
      label === 'Str' || // Terminal string match
      label === 'Char' || // Terminal char match
      label === 'CharRange' // Terminal char range match
    );
  }

  /**
   * Check if a node is a wrapper/intermediate grammatical node.
   */
  private static isWrapperNode(label: string): boolean {
    return (
      label === 'Expression' ||
      label === 'RuleBody' ||
      label === 'Primary' ||
      label === 'Group'
    );
  }
}
