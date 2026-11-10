String escapeString(String s) {
  final buffer = StringBuffer();
  for (final rune in s.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(switch (char) {
      '\\' => r'\\',
      '"' => r'\"',
      "'" => r"\'",
      '\n' => r'\n',
      '\r' => r'\r',
      '\t' => r'\t',
      '\b' => r'\b',
      _ => (rune <= 0x1f || (rune >= 0x7f && rune <= 0xffff))
          ? '\\u${rune.toRadixString(16).padLeft(4, '0')}'
          : (rune > 0xffff)
              ? '\\u{${rune.toRadixString(16)}}'
              : char,
    });
  }
  return buffer.toString();
}

// -----------------------------------------------------------------------------------------------------------------

/// Unescape a string literal (content between quotes).
String unescapeString(String str) {
  final buffer = StringBuffer();
  int i = 0;
  while (i < str.length) {
    if (str[i] == '\\' && i + 1 < str.length) {
      final next = str[i + 1];
      buffer.write(switch (next) {
        'n' => '\n',
        'r' => '\r',
        't' => '\t',
        '\\' => '\\',
        '"' => '"',
        "'" => "'",
        '[' => '[',
        ']' => ']',
        '-' => '-',
        _ => next,
      });
      i += 2;
    } else {
      buffer.write(str[i]);
      i++;
    }
  }
  return buffer.toString();
}

// -----------------------------------------------------------------------------------------------------------------

/// Unescape a single character (possibly an escape sequence).
String unescapeChar(String str) => str.length == 1
    ? str
    : str.length == 2 && str[0] == '\\'
        ? switch (str[1]) {
            'n' => '\n',
            'r' => '\r',
            't' => '\t',
            '\\' => '\\',
            '"' => '"',
            "'" => "'",
            '[' => '[',
            ']' => ']',
            '-' => '-',
            _ => str[1],
          }
        : str;
