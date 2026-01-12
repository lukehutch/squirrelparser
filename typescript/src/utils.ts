/**
 * Utility functions for string escaping and unescaping.
 */

// -----------------------------------------------------------------------------------------------------------------

/**
 * Escape a string for display.
 */
export function escapeString(s: string): string {
  const buffer: string[] = [];
  for (const char of s) {
    const rune = char.codePointAt(0)!;
    const escaped = (() => {
      switch (char) {
        case '\\': return '\\\\';
        case '"': return '\\"';
        case "'": return "\\'";
        case '\n': return '\\n';
        case '\r': return '\\r';
        case '\t': return '\\t';
        case '\b': return '\\b';
        default:
          if (rune <= 0x1f || (rune >= 0x7f && rune <= 0xffff)) {
            return `\\u${rune.toString(16).padStart(4, '0')}`;
          } else if (rune > 0xffff) {
            return `\\u{${rune.toString(16)}}`;
          } else {
            return char;
          }
      }
    })();
    buffer.push(escaped);
  }
  return buffer.join('');
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Unescape a string literal (content between quotes).
 */
export function unescapeString(str: string): string {
  const buffer: string[] = [];
  let i = 0;
  while (i < str.length) {
    if (str[i] === '\\' && i + 1 < str.length) {
      const next = str[i + 1];
      const unescaped = (() => {
        switch (next) {
          case 'n': return '\n';
          case 'r': return '\r';
          case 't': return '\t';
          case '\\': return '\\';
          case '"': return '"';
          case "'": return "'";
          case '[': return '[';
          case ']': return ']';
          case '-': return '-';
          default: return next;
        }
      })();
      buffer.push(unescaped);
      i += 2;
    } else {
      buffer.push(str[i]);
      i++;
    }
  }
  return buffer.join('');
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Unescape a single character (possibly an escape sequence).
 */
export function unescapeChar(str: string): string {
  if (str.length === 1) {
    return str;
  }
  if (str.length === 2 && str[0] === '\\') {
    switch (str[1]) {
      case 'n': return '\n';
      case 'r': return '\r';
      case 't': return '\t';
      case '\\': return '\\';
      case '"': return '"';
      case "'": return "'";
      case '[': return '[';
      case ']': return ']';
      case '-': return '-';
      default: return str[1];
    }
  }
  return str;
}
