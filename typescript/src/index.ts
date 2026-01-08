/**
 * Squirrel Parser - A packrat parser with left recursion and error recovery.
 */

export { Match, Mismatch, SyntaxError, MISMATCH, LR_PENDING } from './matchResult';
export type { MatchResult } from './matchResult';
export type { Clause } from './clause';
export { Str, Char, CharRange, AnyChar } from './terminals';
export {
  Seq,
  First,
  OneOrMore,
  ZeroOrMore,
  Optional,
  NotFollowedBy,
  FollowedBy,
  Ref,
  getSyntaxErrors,
} from './combinators';
export { Parser } from './parser';
export { ASTNode, buildAST } from './ast';
export { MetaGrammar } from './metaGrammar';
export { squirrelParse } from './squirrelParse';
