// ===========================================================================
// SECTION 10: UNICODE AND SPECIAL (10 tests)
// ===========================================================================

import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  test('U03-Arabic clean', () {
    final (ok, err, _) = testParse('S <- "م"+ ;', 'ممم');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('U05-tab', () {
    final (ok, err, _) = testParse(
      r'S <- "a" "\t" "b" ;',
      'a\tb',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('U10-mixed scripts', () {
    final (ok, err, _) = testParse(
      'S <- "α" "中" "!" ;',
      'α中!',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });
}
