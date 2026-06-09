import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';

void main() {
  test('全空时 isEmpty 为真', () {
    expect(const UserProfile().isEmpty, isTrue);
  });

  test('任一字段有值时 isEmpty 为假', () {
    expect(const UserProfile(name: '李四').isEmpty, isFalse);
    expect(const UserProfile(researchInterests: ['AI']).isEmpty, isFalse);
    expect(const UserProfile(highlights: 'GPA 3.9').isEmpty, isFalse);
  });
}
