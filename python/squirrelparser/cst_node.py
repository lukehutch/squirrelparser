"""
Concrete Syntax Tree (CST) node and related classes

CST nodes represent the structure of a parsed input with full syntactic detail,
including syntax error nodes for error recovery.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import TYPE_CHECKING, TypeVar, Generic, Callable

if TYPE_CHECKING:
    pass

T = TypeVar('T', bound='CSTNode')


class CSTNode(ABC):
    """
    Base class for all CST nodes.

    CST nodes represent the concrete syntax structure of the input, with each node
    corresponding to a grammar rule (non-transparent rules only) or a terminal.
    """

    def __init__(self, name: str) -> None:
        """
        Initialize a CST node.

        Args:
            name: The name of this node (rule name or `<Terminal>`)
        """
        self.name = name

    def __str__(self) -> str:
        return self.name

    def __repr__(self) -> str:
        return self.name


class CSTSyntaxErrorNode(CSTNode):
    """
    A CST node representing a syntax error during parsing.

    This node is used when the parser encounters an error and needs to represent
    the span of invalid input. It can be included in the CST to show where errors occurred.
    """

    def __init__(self, name: str, text: str, pos: int, length: int) -> None:
        """
        Initialize a syntax error node.

        Args:
            name: The name of this node
            text: The text that caused the error
            pos: The position in the input where the error starts
            length: The length of the error span
        """
        super().__init__(name)
        self.text = text
        self.pos = pos
        self.length = length

    def __str__(self) -> str:
        return f"<SyntaxError: {self.name} at {self.pos}:{self.length}>"

    def __repr__(self) -> str:
        return f"<SyntaxError: {self.name} at {self.pos}:{self.length}>"


class CSTNodeFactory(Generic[T]):
    """
    Metadata for creating a CST node from a parse tree node.

    Each grammar rule (non-transparent) must have a corresponding factory.
    The factory takes the rule name, expected child names, and actual child CST nodes,
    and returns a CSTNode instance of type T.
    """

    def __init__(
        self,
        rule_name: str,
        expected_children: list[str],
        factory: Callable[[str, list[str], list[CSTNode]], T],
    ) -> None:
        """
        Initialize a CST node factory.

        Args:
            rule_name: The grammar rule name this factory corresponds to
            expected_children: The expected child node names or `<Terminal>` for terminal children
            factory: Factory function that creates a CST node of type T from rule name,
                    expected child names, and actual child CST nodes
        """
        self.rule_name = rule_name
        self.expected_children = expected_children
        self.factory = factory


class CSTFactoryValidationException(Exception):
    """Exception thrown when CST factory validation fails"""

    def __init__(self, missing: set[str], extra: set[str]) -> None:
        """
        Initialize validation exception.

        Args:
            missing: Missing rule names (rules in grammar but not in factories)
            extra: Extra rule names (factories provided but not in grammar)
        """
        parts = []
        if missing:
            parts.append(f"Missing factories: {', '.join(sorted(missing))}")
        if extra:
            parts.append(f"Extra factories: {', '.join(sorted(extra))}")
        super().__init__(f"CSTFactoryValidationException: {'; '.join(parts)}")
        self.missing = missing
        self.extra = extra


class CSTConstructionException(Exception):
    """Exception thrown when CST construction fails"""

    def __init__(self, message: str) -> None:
        """
        Initialize construction exception.

        Args:
            message: Error message
        """
        super().__init__(f"CSTConstructionException: {message}")


class DuplicateRuleNameException(Exception):
    """Exception thrown when duplicate rule names are found in CST factories"""

    def __init__(self, rule_name: str, count: int) -> None:
        """
        Initialize duplicate rule name exception.

        Args:
            rule_name: The rule name that appeared more than once
            count: The count of how many times it appeared
        """
        super().__init__(f'DuplicateRuleNameException: Rule "{rule_name}" appears {count} times in factory list')
        self.rule_name = rule_name
        self.count = count
