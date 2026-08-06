import 'final_table.dart' show elegNotes;
void main() {
  final n = elegNotes['m72']!;
  print('score=${n.$1} chars=${n.$2.length}');
  print(n.$2.substring(0, 90));
  print('...');
  print(n.$2.substring(n.$2.length - 90));
}
