import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/metagrammar.dart';

void main() {
  // Test the metagrammar parser directly without recovery

  final input = r'''
    SIGN <- [-] ;
  ''';

  print('Input: "$input"');
  print('Input length: ${input.length}');

  // Phase 1 only (no recovery)
  final parser = Parser(rules: MetaGrammar.rules, topRuleName: 'Grammar', input: input);
  final phase1Result = parser.matchRule('Grammar', 0);

  print('\nPhase 1 (no recovery):');
  print('  isMismatch: ${phase1Result.isMismatch}');
  print('  isComplete: ${phase1Result.isComplete}');
  print('  len: ${phase1Result.len}');
  print('  pos: ${phase1Result.pos}');

  if (!phase1Result.isMismatch) {
    print('  Matched: "${input.substring(phase1Result.pos, phase1Result.pos + phase1Result.len)}"');
  }

  // Try parsing the CharClass directly
  print('\nTrying to match CharClass at various positions:');
  final ccInput = '[-]';
  final ccParser = Parser(rules: MetaGrammar.rules, topRuleName: 'CharClass', input: ccInput);

  final ccResult = ccParser.matchRule('CharClass', 0);
  print('  CharClass on "[-]": isMismatch=${ccResult.isMismatch}, len=${ccResult.len}');

  // Try CharClassChar on -
  final cccInput = '-';
  final cccParser = Parser(rules: MetaGrammar.rules, topRuleName: 'CharClassChar', input: cccInput);
  final cccResult = cccParser.matchRule('CharClassChar', 0);
  print('  CharClassChar on "-": isMismatch=${cccResult.isMismatch}, len=${cccResult.len}');

  // Try CharRange on -]
  final crInput = '-';
  final crParser = Parser(rules: MetaGrammar.rules, topRuleName: 'CharRange', input: crInput);
  final crResult = crParser.matchRule('CharRange', 0);
  print('  CharRange on "-": isMismatch=${crResult.isMismatch}, len=${crResult.len}');

  // Check working case [+]
  print('\nTrying working case [+]:');
  final plusInput = '[+]';
  final plusParser = Parser(rules: MetaGrammar.rules, topRuleName: 'CharClass', input: plusInput);
  final plusResult = plusParser.matchRule('CharClass', 0);
  print('  CharClass on "[+]": isMismatch=${plusResult.isMismatch}, len=${plusResult.len}');
}
