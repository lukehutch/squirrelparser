import type { Clause } from './clause.js';
import {
  First,
  FollowedBy,
  NotFollowedBy,
  OneOrMore,
  Optional,
  Ref,
  Seq,
  ZeroOrMore,
} from './combinators.js';
import { AnyChar, Char, CharSet, Nothing, Str } from './terminals.js';
import { Parser } from './parser.js';
import { ASTNode, buildAST } from './cstNode.js';
import { unescapeChar, unescapeString } from './utils.js';

// -----------------------------------------------------------------------------------------------------------------

const TERMINAL_LABEL = '<Terminal>';

/**
 * MetaGrammar: A grammar for defining PEG grammars.
 */
export class MetaGrammar {
  /** The meta-grammar rules for parsing PEG grammars. */
  static readonly rules: Map<string, Clause> = new Map<string, Clause>([
    [
      'Grammar',
      new Seq([new Ref('WS'), new OneOrMore(new Seq([new Ref('Rule'), new Ref('WS')]))]),
    ],
    [
      'Rule',
      new Seq([
        new Optional(new Str('~')),
        new Ref('Identifier'),
        new Ref('WS'),
        new Str('<-'),
        new Ref('WS'),
        new Ref('Expression'),
        new Ref('WS'),
        new Str(';'),
        new Ref('WS'),
      ]),
    ],
    ['Expression', new Ref('Choice')],
    [
      'Choice',
      new Seq([
        new Ref('Sequence'),
        new ZeroOrMore(new Seq([new Ref('WS'), new Str('/'), new Ref('WS'), new Ref('Sequence')])),
      ]),
    ],
    [
      'Sequence',
      new Seq([new Ref('Prefix'), new ZeroOrMore(new Seq([new Ref('WS'), new Ref('Prefix')]))]),
    ],
    [
      'Prefix',
      new First([
        new Seq([new Str('&'), new Ref('WS'), new Ref('Prefix')]),
        new Seq([new Str('!'), new Ref('WS'), new Ref('Prefix')]),
        new Seq([new Str('~'), new Ref('WS'), new Ref('Prefix')]),
        new Ref('Suffix'),
      ]),
    ],
    [
      'Suffix',
      new First([
        new Seq([new Ref('Suffix'), new Ref('WS'), new Str('*')]),
        new Seq([new Ref('Suffix'), new Ref('WS'), new Str('+')]),
        new Seq([new Ref('Suffix'), new Ref('WS'), new Str('?')]),
        new Ref('Primary'),
      ]),
    ],
    [
      'Primary',
      new First([
        new Ref('Identifier'),
        new Ref('StringLiteral'),
        new Ref('CharLiteral'),
        new Ref('CharClass'),
        new Ref('AnyChar'),
        new Ref('Parens'),
      ]),
    ],
    [
      'Parens',
      new Seq([new Str('('), new Ref('WS'), new Optional(new Ref('Expression')), new Ref('WS'), new Str(')')]),
    ],
    [
      'Identifier',
      new Seq([
        new First([CharSet.range('a', 'z'), CharSet.range('A', 'Z'), new Char('_')]),
        new ZeroOrMore(
          new First([CharSet.range('a', 'z'), CharSet.range('A', 'Z'), CharSet.range('0', '9'), new Char('_')])
        ),
      ]),
    ],
    [
      'StringLiteral',
      new Seq([
        new Str('"'),
        new ZeroOrMore(
          new First([
            new Ref('EscapeSequence'),
            new Seq([new NotFollowedBy(new First([new Str('"'), new Str('\\')])), new AnyChar()]),
          ])
        ),
        new Str('"'),
      ]),
    ],
    [
      'CharLiteral',
      new Seq([
        new Str("'"),
        new First([
          new Ref('EscapeSequence'),
          new Seq([new NotFollowedBy(new First([new Str("'"), new Str('\\')])), new AnyChar()]),
        ]),
        new Str("'"),
      ]),
    ],
    [
      'EscapeSequence',
      new Seq([
        new Str('\\'),
        new First([
          new Char('n'),
          new Char('r'),
          new Char('t'),
          new Char('\\'),
          new Char('"'),
          new Char("'"),
          new Char('['),
          new Char(']'),
          new Char('-'),
        ]),
      ]),
    ],
    [
      'CharClass',
      new Seq([
        new Str('['),
        new Optional(new Str('^')),
        new OneOrMore(new First([new Ref('CharRange'), new Ref('CharClassChar')])),
        new Str(']'),
      ]),
    ],
    ['CharRange', new Seq([new Ref('CharClassChar'), new Str('-'), new Ref('CharClassChar')])],
    [
      'CharClassChar',
      new First([
        new Ref('EscapeSequence'),
        new Seq([new NotFollowedBy(new First([new Str(']'), new Str('\\'), new Str('-')])), new AnyChar()]),
      ]),
    ],
    ['AnyChar', new Str('.')],
    [
      '~WS',
      new ZeroOrMore(new First([new Char(' '), new Char('\t'), new Char('\n'), new Char('\r'), new Ref('Comment')])),
    ],
    [
      'Comment',
      new Seq([
        new Str('#'),
        new ZeroOrMore(new Seq([new NotFollowedBy(new Char('\n')), new AnyChar()])),
        new Optional(new Char('\n')),
      ]),
    ],
  ]);

  /**
   * Parse a grammar specification and return the rules.
   */
  static parseGrammar(grammarSpec: string): Map<string, Clause> {
    const parser = new Parser({ rules: MetaGrammar.rules, topRuleName: 'Grammar', input: grammarSpec });
    const parseResult = parser.parse();
    if (parseResult.hasSyntaxErrors) {
      const errors = parseResult.getSyntaxErrors().map((e) => e.toString());
      throw new Error(`Failed to parse grammar. Syntax errors:\n${errors.join('\n')}`);
    }

    const ast = buildAST(parseResult);
    const grammarMap = new Map<string, Clause>();

    for (const ruleNode of ast.children) {
      if (ruleNode.label !== 'Rule') {
        continue;
      }

      const identifierNode = ruleNode.children.find((c) => c.label === 'Identifier');
      if (!identifierNode) {
        throw new Error('Rule has no Identifier child');
      }
      const ruleName = identifierNode.getInputSpan(grammarSpec);

      const expressionNode = ruleNode.children.find((c) => c.label === 'Expression');
      if (!expressionNode) {
        throw new Error('Rule has no Expression child');
      }

      let isTransparent = false;
      for (const child of ruleNode.children) {
        if (child.label === TERMINAL_LABEL && child.getInputSpan(grammarSpec) === '~') {
          isTransparent = true;
          break;
        }
        if (child.label === 'Identifier') {
          break;
        }
      }

      const clause = buildClause(expressionNode, grammarSpec);

      if (isTransparent) {
        grammarMap.set(`~${ruleName}`, clause);
      } else {
        grammarMap.set(ruleName, clause);
      }
    }

    // Validate rules
    for (const key of grammarMap.keys()) {
      if (
        (key.startsWith('~') && grammarMap.has(key.substring(1))) ||
        (!key.startsWith('~') && grammarMap.has(`~${key}`))
      ) {
        throw new Error(`Rule "${key}" cannot be both transparent and non-transparent`);
      }
    }
    for (const clause of grammarMap.values()) {
      clause.checkRuleRefs(grammarMap);
    }

    return grammarMap;
  }
}

// -----------------------------------------------------------------------------------------------------------------

function buildClause(node: ASTNode, input: string): Clause {
  switch (node.label) {
    case 'Expression': {
      if (node.children.length === 1) {
        return buildClause(node.children[0], input);
      }
      throw new Error(`Expression should have exactly one child, got ${node.children.length}`);
    }
    case 'Choice': {
      const sequences = node.children.filter((c) => c.label === 'Sequence').map((c) => buildClause(c, input));
      if (sequences.length === 0) {
        throw new Error('Choice has no Sequence children');
      }
      return sequences.length === 1 ? sequences[0] : new First(sequences);
    }
    case 'Sequence': {
      const prefixes = node.children.filter((c) => c.label === 'Prefix').map((c) => buildClause(c, input));
      if (prefixes.length === 0) {
        throw new Error('Sequence has no Prefix children');
      }
      return prefixes.length === 1 ? prefixes[0] : new Seq(prefixes);
    }
    case 'Prefix': {
      let prefixOp: string | null = null;
      for (const child of node.children) {
        if (child.label === TERMINAL_LABEL) {
          const text = child.getInputSpan(input);
          if (text === '&' || text === '!' || text === '~') {
            prefixOp = text;
            break;
          }
        }
      }

      const operand = node.children.find((c) => c.label === 'Prefix' || c.label === 'Suffix');
      if (!operand) {
        throw new Error('Prefix has no Prefix/Suffix child');
      }
      const operandClause = buildClause(operand, input);

      switch (prefixOp) {
        case '&':
          return new FollowedBy(operandClause);
        case '!':
          return new NotFollowedBy(operandClause);
        case '~':
          return operandClause;
        default:
          return operandClause;
      }
    }
    case 'Suffix': {
      let suffixOp: string | null = null;
      for (const child of node.children) {
        if (child.label === TERMINAL_LABEL) {
          const text = child.getInputSpan(input);
          if (text === '*' || text === '+' || text === '?') {
            suffixOp = text;
            break;
          }
        }
      }

      const operand = node.children.find((c) => c.label === 'Suffix' || c.label === 'Primary');
      if (!operand) {
        throw new Error('Suffix has no Suffix/Primary child');
      }
      const operandClause = buildClause(operand, input);

      switch (suffixOp) {
        case '*':
          return new ZeroOrMore(operandClause);
        case '+':
          return new OneOrMore(operandClause);
        case '?':
          return new Optional(operandClause);
        default:
          return operandClause;
      }
    }
    case 'Primary': {
      for (const child of node.children) {
        if (child.label !== TERMINAL_LABEL) {
          return buildClause(child, input);
        }
      }
      throw new Error('Primary has no semantic child');
    }
    case 'Parens': {
      for (const child of node.children) {
        if (child.label === 'Expression') {
          return buildClause(child, input);
        }
      }
      return new Nothing();
    }
    case 'Identifier': {
      return new Ref(node.getInputSpan(input));
    }
    case 'StringLiteral': {
      const text = node.getInputSpan(input);
      return new Str(unescapeString(text.substring(1, text.length - 1)));
    }
    case 'CharLiteral': {
      const text = node.getInputSpan(input);
      return new Char(unescapeChar(text.substring(1, text.length - 1)));
    }
    case 'CharClass': {
      return buildCharClass(node, input);
    }
    case 'AnyChar': {
      return new AnyChar();
    }
    default:
      throw new Error(`Unknown AST node label: ${node.label}`);
  }
}

// -----------------------------------------------------------------------------------------------------------------

function buildCharClass(node: ASTNode, input: string): Clause {
  let negated = false;
  for (const child of node.children) {
    if (child.label === TERMINAL_LABEL && child.getInputSpan(input) === '^') {
      negated = true;
      break;
    }
  }

  const ranges: Array<readonly [number, number]> = [];
  for (const child of node.children) {
    if (child.label === 'CharRange') {
      const charClassChars = child.children.filter((c) => c.label === 'CharClassChar');
      if (charClassChars.length !== 2) {
        throw new Error('CharRange must have exactly 2 CharClassChar children');
      }
      const lo = extractCharClassCharValue(charClassChars[0], input);
      const hi = extractCharClassCharValue(charClassChars[1], input);
      ranges.push([lo.charCodeAt(0), hi.charCodeAt(0)]);
    } else if (child.label === 'CharClassChar') {
      const ch = extractCharClassCharValue(child, input);
      const cp = ch.charCodeAt(0);
      ranges.push([cp, cp]);
    }
  }

  if (ranges.length === 0) {
    throw new Error('CharClass has no character items');
  }

  return new CharSet(ranges, negated);
}

// -----------------------------------------------------------------------------------------------------------------

function extractCharClassCharValue(node: ASTNode, input: string): string {
  for (const child of node.children) {
    if (child.label === 'EscapeSequence') {
      return unescapeChar(child.getInputSpan(input));
    }
  }
  return unescapeChar(node.getInputSpan(input));
}
