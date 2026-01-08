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
export { MetaGrammar } from './metaGrammar';
export {
  CSTNode,
  CSTSyntaxErrorNode,
  CSTNodeFactory,
  CSTFactoryValidationException,
  CSTConstructionException,
  DuplicateRuleNameException,
} from './cstNode';
export {
  squirrelParse,
  parseToMatchResultForTesting,
  parseWithRuleMapForTesting,
} from './squirrelParse';
