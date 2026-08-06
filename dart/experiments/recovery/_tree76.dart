import 'package:squirrel_parser/squirrel_parser.dart';
import 'final_table.dart' show buildSetup, treeShape;
import 'm76.dart' as e;

class Audit {
  bool tiles = true, total = true;
  int unsupported = 0, errors = 0;
}

Audit audit(MatchResult root, String input, Parser oracle) {
  final a = Audit(), leaves = <(int, int)>[];
  void walk(MatchResult m, int lo, int hi) {
    if (m.pos < lo || m.len < 0 || m.pos + m.len > hi) a.tiles = false;
    if (m is SyntaxError) a.errors++;
    if (m.subClauseMatches.isEmpty) {
      if (m.len > 0) leaves.add((m.pos, m.pos + m.len));
      if (m.clause != null && m is! SyntaxError) {
        final q = m.clause!.match(oracle, m.pos);
        if (q.isMismatch || q.len != m.len) a.unsupported++;
      }
      return;
    }
    var cursor = m.pos;
    for (final child in m.subClauseMatches) {
      if (child.pos < cursor) a.tiles = false;
      walk(child, m.pos, m.pos + m.len);
      cursor = child.pos + child.len;
    }
  }
  walk(root, 0, input.length);
  leaves.sort((x, y) => x.$1 - y.$1);
  var at = 0;
  for (final x in leaves) {
    if (x.$1 > at) a.total = false;
    at = max(at, x.$2);
  }
  if (at < input.length) a.total = false;
  return a;
}

int max(int a, int b) => a > b ? a : b;

void main() {
  final setup = buildSetup();
  final engine = e.SuperDot3(rules: setup.$1, topRuleName: 'JSON');
  var tiles = 0, total = 0, unsupported = 0, flagged = 0, shape = 0;
  for (final input in setup.$2) {
    final r = engine.recover(input);
    final oracle = Parser(rules: setup.$1, topRuleName: 'JSON', input: input)
      ..parse();
    final a = audit(r.root, input, oracle);
    if (a.tiles) tiles++;
    if (a.total) total++;
    unsupported += a.unsupported;
    if (a.errors > 0) flagged++;
    if (treeShape(r.root) == setup.$3) shape++;
  }
  print('tree checked=${setup.$2.length} tiles=$tiles total=$total '
      'unsupported=$unsupported flagged=$flagged shape=$shape');
}
