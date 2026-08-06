import 'final_table.dart' show buildSetup;
import '_lat72.dart' show latCases;
void main() {
  final (_, _, _, _, a, _, _, _) = buildSetup();
  final b = latCases();
  print('buildSetup n=${a.length}  latCases n=${b.length}');
  var same = a.length == b.length;
  for (var i = 0; same && i < a.length; i++) {
    if (a[i] != b[i]) { same = false; print('DIFFER at $i'); }
  }
  print(same ? 'IDENTICAL corpora' : 'CORPORA DIFFER');
  print('lengths: ${a.map((s) => s.length).toList()}');
}
