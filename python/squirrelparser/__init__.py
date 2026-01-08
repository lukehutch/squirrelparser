"""
Squirrel Parser - A packrat parser with left recursion and error recovery.
"""

from .match_result import Match, Mismatch, SyntaxError, MISMATCH, LR_PENDING
from .clause import Clause
from .terminals import Str, Char, CharRange, AnyChar
from .combinators import Seq, First, OneOrMore, ZeroOrMore, Optional, NotFollowedBy, FollowedBy, Ref
from .parser import Parser
from .ast_node import ASTNode, build_ast
from .meta_grammar import MetaGrammar
from .squirrel_parse import squirrel_parse

__all__ = [
    'Match', 'Mismatch', 'SyntaxError', 'MISMATCH', 'LR_PENDING',
    'Clause',
    'Str', 'Char', 'CharRange', 'AnyChar',
    'Seq', 'First', 'OneOrMore', 'ZeroOrMore', 'Optional', 'NotFollowedBy', 'FollowedBy', 'Ref',
    'Parser',
    'ASTNode', 'build_ast',
    'MetaGrammar',
    'squirrel_parse',
]

__version__ = '1.0.0'
