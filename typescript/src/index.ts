/**
 * Squirrel Parser - A packrat parser with left recursion and error recovery.
 */

// Clause base
export { Clause } from './clause.js';

// Match results
export { MatchResult, Match, SyntaxError, mismatch, lrPending } from './matchResult.js';

// Tree nodes
export { Node, ASTNode, CSTNode, CSTNodeFactoryFn, buildAST, buildCST } from './cstNode.js';

// Terminals
export { Terminal, Str, Char, CharSet, AnyChar, Nothing } from './terminals.js';

// Combinators
export {
  HasOneSubClause,
  HasMultipleSubClauses,
  Seq,
  First,
  Repetition,
  OneOrMore,
  ZeroOrMore,
  Optional,
  Ref,
  NotFollowedBy,
  FollowedBy,
} from './combinators.js';

// Parser
export { Parser, ParseResult } from './parser.js';

// MetaGrammar
export { MetaGrammar } from './metaGrammar.js';

// Squirrel Parse API
export { squirrelParseCST, squirrelParseAST, squirrelParsePT } from './squirrelParse.js';

// Parser Stats
export { ParserStats, parserStats, enableParserStats, disableParserStats, debugLogging, setDebugLogging } from './parserStats.js';

// Utils
export { escapeString, unescapeString, unescapeChar } from './utils.js';
