import 'package:flutter_test/flutter_test.dart';
import 'package:mapae/core/utils/validators.dart';

void main() {
  group('Validators', () {
    test('isValidEmail accepts valid emails', () {
      expect(Validators.isValidEmail('test@example.com'), true);
      expect(Validators.isValidEmail('user.name@domain.co.kr'), true);
    });

    test('isValidEmail rejects invalid emails', () {
      expect(Validators.isValidEmail(''), false);
      expect(Validators.isValidEmail('notanemail'), false);
      expect(Validators.isValidEmail('@domain.com'), false);
    });

    test('isValidPhone accepts valid phones', () {
      expect(Validators.isValidPhone('010-1234-5678'), true);
      expect(Validators.isValidPhone('+82 10 1234 5678'), true);
      expect(Validators.isValidPhone('0212345678'), true);
    });

    test('isValidPhone rejects invalid phones', () {
      expect(Validators.isValidPhone(''), false);
      expect(Validators.isValidPhone('abc'), false);
      expect(Validators.isValidPhone('12'), false);
    });

    test('passwordStrength returns correct levels', () {
      expect(Validators.passwordStrength('12345'), 0); // too short
      expect(Validators.passwordStrength('abcdef'), 1); // weak
      expect(Validators.passwordStrength('Abcdef12'), 3); // strong
    });

    test('stripHtmlTags removes HTML', () {
      expect(Validators.stripHtmlTags('<b>bold</b>'), 'bold');
      expect(Validators.stripHtmlTags('<script>alert(1)</script>'), 'alert(1)');
      expect(Validators.stripHtmlTags('no tags'), 'no tags');
    });

    test('sanitize trims and limits length', () {
      expect(Validators.sanitize('  hello  '), 'hello');
      expect(Validators.sanitize('hello world', maxLength: 5), 'hello');
    });
  });
}