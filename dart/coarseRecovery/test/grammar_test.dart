import 'package:test/test.dart';
import 'package:squirrel_parser/squirrel_parser.dart';

void main() {
  test('parses simple grammar', () {
    const String simpleGrammar = '''
      Test <- "hello";
    ''';

    expect(
      () => MetaGrammar.parseGrammar(simpleGrammar),
      returnsNormally,
    );
  });

  test('parses multiline grammar', () {
    const String multilineGrammar = '''
      JSON <- Value;
      Value <- "test";
    ''';

    expect(
      () => MetaGrammar.parseGrammar(multilineGrammar),
      returnsNormally,
    );
  });
}
