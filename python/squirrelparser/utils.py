"""Utility functions for string escaping and unescaping."""

from __future__ import annotations


def escape_string(s: str) -> str:
    """Escape a string for display."""
    buffer: list[str] = []
    for char in s:
        rune = ord(char)
        match char:
            case '\\':
                escaped = '\\\\'
            case '"':
                escaped = '\\"'
            case "'":
                escaped = "\\'"
            case '\n':
                escaped = '\\n'
            case '\r':
                escaped = '\\r'
            case '\t':
                escaped = '\\t'
            case '\b':
                escaped = '\\b'
            case _:
                if rune <= 0x1f or (0x7f <= rune <= 0xffff):
                    escaped = f'\\u{rune:04x}'
                elif rune > 0xffff:
                    escaped = f'\\u{{{rune:x}}}'
                else:
                    escaped = char
        buffer.append(escaped)
    return ''.join(buffer)


# ------------------------------------------------------------------------------------------------------------------


def unescape_string(s: str) -> str:
    """Unescape a string literal (content between quotes)."""
    buffer: list[str] = []
    i = 0
    while i < len(s):
        if s[i] == '\\' and i + 1 < len(s):
            next_char = s[i + 1]
            match next_char:
                case 'n':
                    unescaped = '\n'
                case 'r':
                    unescaped = '\r'
                case 't':
                    unescaped = '\t'
                case '\\':
                    unescaped = '\\'
                case '"':
                    unescaped = '"'
                case "'":
                    unescaped = "'"
                case '[':
                    unescaped = '['
                case ']':
                    unescaped = ']'
                case '-':
                    unescaped = '-'
                case _:
                    unescaped = next_char
            buffer.append(unescaped)
            i += 2
        else:
            buffer.append(s[i])
            i += 1
    return ''.join(buffer)


# ------------------------------------------------------------------------------------------------------------------


def unescape_char(s: str) -> str:
    """Unescape a single character (possibly an escape sequence)."""
    if len(s) == 1:
        return s
    if len(s) == 2 and s[0] == '\\':
        match s[1]:
            case 'n':
                return '\n'
            case 'r':
                return '\r'
            case 't':
                return '\t'
            case '\\':
                return '\\'
            case '"':
                return '"'
            case "'":
                return "'"
            case '[':
                return '['
            case ']':
                return ']'
            case '-':
                return '-'
            case _:
                return s[1]
    return s
