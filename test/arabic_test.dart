import 'package:flutter_test/flutter_test.dart';
import 'package:kalimat/game/arabic.dart';

void main() {
  group('normalizeArabic', () {
    test('unifies hamza forms of alef', () {
      expect(normalizeArabic('أكل'), 'اكل');
      expect(normalizeArabic('إسلام'), 'اسلام');
      expect(normalizeArabic('آمن'), 'امن');
    });

    test('taa marbuta and alef maqsura', () {
      expect(normalizeArabic('مدرسة'), 'مدرسه');
      expect(normalizeArabic('مستشفى'), 'مستشفي');
    });

    test('strips tashkeel and tatweel', () {
      expect(normalizeArabic('كَتَبَ'), 'كتب');
      expect(normalizeArabic('كـتـاب'), 'كتاب');
    });

    test('same word with different hamza spelling matches', () {
      expect(normalizeArabic('أمل'), normalizeArabic('امل'));
      expect(normalizeArabic('شجرة'), normalizeArabic('شجره'));
    });
  });

  test('canFormWord respects letter counts', () {
    final pool = letterCounts(['ك', 'ت', 'ا', 'ب']);
    expect(canFormWord('كتب', pool), isTrue);
    expect(canFormWord('كتاب', pool), isTrue);
    expect(canFormWord('أكتب', pool), isTrue); // أ == ا
    expect(canFormWord('كتبت', pool), isFalse); // needs two ت
    expect(canFormWord('مكتب', pool), isFalse);
  });

  group('contextualLetter', () {
    test('joining letters get joiners on both sides in the middle', () {
      // كتب: ك initial, ت medial, ب final
      expect(contextualLetter('كتب', 0), 'ك$zwj');
      expect(contextualLetter('كتب', 1), '$zwjت$zwj');
      expect(contextualLetter('كتب', 2), '$zwjب');
    });

    test('non-joining letters break the chain', () {
      // دار: د isolated, ا isolated (د does not join forward), ر joined? no
      expect(contextualLetter('دار', 0), 'د');
      expect(contextualLetter('دار', 1), 'ا');
      expect(contextualLetter('دار', 2), 'ر');
      // باب: ب initial, ا final, ب isolated
      expect(contextualLetter('باب', 0), 'ب$zwj');
      expect(contextualLetter('باب', 1), '$zwjا');
      expect(contextualLetter('باب', 2), 'ب');
    });
  });
}
