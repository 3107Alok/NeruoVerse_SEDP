import 'package:flutter_test/flutter_test.dart';
import 'package:neuroverse_app/core/localization/app_translations.dart';

void main() {
  group('New Indian Languages Support Tests', () {
    test('Language code normalization for kn, te, mr', () {
      expect(AppTranslations.normalizeLangCode('kn'), equals('kn'));
      expect(AppTranslations.normalizeLangCode('Kannada'), equals('kn'));
      expect(AppTranslations.normalizeLangCode('ಕನ್ನಡ'), equals('kn'));

      expect(AppTranslations.normalizeLangCode('te'), equals('te'));
      expect(AppTranslations.normalizeLangCode('Telugu'), equals('te'));
      expect(AppTranslations.normalizeLangCode('తెలుగు'), equals('te'));

      expect(AppTranslations.normalizeLangCode('mr'), equals('mr'));
      expect(AppTranslations.normalizeLangCode('Marathi'), equals('mr'));
      expect(AppTranslations.normalizeLangCode('मराठी'), equals('mr'));
    });

    test('Kannada translation key lookup and placeholder interpolation', () {
      final home = AppTranslations.get('kn', 'nav_home');
      expect(home, isNotEmpty);
      expect(home, isNot(equals('Home'))); // Must be Kannada

      final greeting = AppTranslations.get('kn', 'greeting_morning');
      expect(greeting, isNotEmpty);

      final exercisesFmt = AppTranslations.get(
        'kn',
        'exercises_completed_fmt',
        params: {'completed': '3', 'total': '5'},
      );
      expect(exercisesFmt, contains('3'));
      expect(exercisesFmt, contains('5'));
    });

    test('Telugu translation key lookup and placeholder interpolation', () {
      final home = AppTranslations.get('te', 'nav_home');
      expect(home, isNotEmpty);
      expect(home, isNot(equals('Home'))); // Must be Telugu

      final greeting = AppTranslations.get('te', 'greeting_morning');
      expect(greeting, isNotEmpty);

      final exercisesFmt = AppTranslations.get(
        'te',
        'exercises_completed_fmt',
        params: {'completed': '4', 'total': '6'},
      );
      expect(exercisesFmt, contains('4'));
      expect(exercisesFmt, contains('6'));
    });

    test('Marathi translation key lookup and placeholder interpolation', () {
      final home = AppTranslations.get('mr', 'nav_home');
      expect(home, isNotEmpty);
      expect(home, isNot(equals('Home'))); // Must be Marathi

      final greeting = AppTranslations.get('mr', 'greeting_morning');
      expect(greeting, isNotEmpty);

      final exercisesFmt = AppTranslations.get(
        'mr',
        'exercises_completed_fmt',
        params: {'completed': '1', 'total': '3'},
      );
      expect(exercisesFmt, contains('1'));
      expect(exercisesFmt, contains('3'));
    });

    test('Date formatting in new languages', () {
      final testDate = DateTime(2026, 10, 29); // Thursday
      final knDate = AppTranslations.formatDate(testDate, language: 'kn');
      final teDate = AppTranslations.formatDate(testDate, language: 'te');
      final mrDate = AppTranslations.formatDate(testDate, language: 'mr');

      expect(knDate, contains('29'));
      expect(teDate, contains('29'));
      expect(mrDate, contains('29'));
    });
  });
}
