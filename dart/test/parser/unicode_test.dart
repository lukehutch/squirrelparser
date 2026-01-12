// ===========================================================================
// SECTION 10: UNICODE AND SPECIAL (10 tests)
// ===========================================================================

import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  test('U01-Greek', () {
    final (ok, err, skip) = testParse('S <- "α"+ ;', 'αβα');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('β'), isTrue, reason: 'should skip β');
  });

  test('U02-Chinese', () {
    final (ok, err, skip) = testParse('S <- "中"+ ;', '中文中');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('文'), isTrue, reason: 'should skip 文');
  });

  test('U03-Arabic clean', () {
    final (ok, err, _) = testParse('S <- "م"+ ;', 'ممم');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('U04-newline', () {
    final (ok, err, skip) = testParse('S <- "x"+ ;', 'x\nx');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('\n'), isTrue, reason: 'should skip newline');
  });

  test('U05-tab', () {
    final (ok, err, _) = testParse(
      r'S <- "a" "\t" "b" ;',
      'a\tb',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('U06-space', () {
    final (ok, err, skip) = testParse('S <- "x"+ ;', 'x x');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains(' '), isTrue, reason: 'should skip space');
  });

  test('U07-multi space', () {
    final (ok, err, skip) = testParse('S <- "x"+ ;', 'x   x');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('   '), isTrue, reason: 'should skip spaces');
  });

  test('U08-Japanese', () {
    final (ok, err, skip) = testParse('S <- "日"+ ;', '日本日');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('本'), isTrue, reason: 'should skip 本');
  });

  test('U09-Korean', () {
    final (ok, err, skip) = testParse('S <- "한"+ ;', '한글한');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('글'), isTrue, reason: 'should skip 글');
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
