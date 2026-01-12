"""
Squirrel Parser - A packrat parser with left recursion and error recovery.
"""

from .clause import Clause
from .match_result import MatchResult, Match, SyntaxError, mismatch, lr_pending
from .cst_node import Node, ASTNode, CSTNode, CSTNodeFactory, build_ast, build_cst
from .terminals import Terminal, Str, Char, CharSet, AnyChar, Nothing
from .combinators import (
    HasOneSubClause, HasMultipleSubClauses, Seq, First,
    Repetition, OneOrMore, ZeroOrMore, Optional, Ref,
    NotFollowedBy, FollowedBy
)
from .parser import Parser, ParseResult
from .meta_grammar import MetaGrammar
from .squirrel_parse import squirrel_parse_cst, squirrel_parse_ast, squirrel_parse_pt

__all__ = [
    # Clause base
    'Clause',
    # Match results
    'MatchResult', 'Match', 'SyntaxError', 'mismatch', 'lr_pending',
    # Tree nodes
    'Node', 'ASTNode', 'CSTNode', 'CSTNodeFactory', 'build_ast', 'build_cst',
    # Terminals
    'Terminal', 'Str', 'Char', 'CharSet', 'AnyChar', 'Nothing',
    # Combinators
    'HasOneSubClause', 'HasMultipleSubClauses', 'Seq', 'First',
    'Repetition', 'OneOrMore', 'ZeroOrMore', 'Optional', 'Ref',
    'NotFollowedBy', 'FollowedBy',
    # Parser
    'Parser', 'ParseResult',
    # MetaGrammar
    'MetaGrammar',
    # Squirrel Parse API
    'squirrel_parse_cst', 'squirrel_parse_ast', 'squirrel_parse_pt',
]
