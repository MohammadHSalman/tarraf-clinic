import 'package:flutter_test/flutter_test.dart';
import 'package:tarraf_clinic/presentation/common.dart';

void main() {
  test('friendlyError strips Dart exception prefixes', () {
    expect(friendlyError(StateError('تغير الملف')), 'تغير الملف');
    expect(friendlyError(ArgumentError('اسم المريض مطلوب')), 'اسم المريض مطلوب');
    expect(friendlyError(const FormatException('4–6')), '4–6');
    expect(friendlyError(Exception('plain')), 'plain');
  });

  test('initialOf is safe for empty, spaced and non-BMP names', () {
    expect(initialOf(''), '?');
    expect(initialOf('  أحمد'), 'أ');
    expect(initialOf('😀 test'), '😀');
  });
}
