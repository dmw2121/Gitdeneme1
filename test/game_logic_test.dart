import 'package:flutter_test/flutter_test.dart';
import 'package:lingo/game_logic.dart';

void main() {
  group('Turkish word handling', () {
    test('normalizes Turkish dotted and dotless I correctly', () {
      expect(normalizeTurkish('İSTANBUL'), 'istanbul');
      expect(normalizeTurkish('IĞDIR'), 'ığdır');
      expect(normalizeTurkish('I\u0307'), 'i');
    });

    test('checks Turkish letters and Unicode letter counts', () {
      expect(isTurkishWord('ÇAĞRI', length: 5), isTrue);
      expect(isTurkishWord('qwert', length: 5), isFalse);
      expect(isTurkishWord('İYİ', length: 3), isTrue);
    });
  });

  group('duplicate-letter scoring', () {
    test('does not award more yellow tiles than the answer contains', () {
      expect(
        scoreGuess('elll', 'kale'),
        [
          TileMark.present,
          TileMark.correct,
          TileMark.absent,
          TileMark.absent,
        ],
      );
    });

    test('reserves exact matches before marking misplaced duplicates', () {
      expect(
        scoreGuess('allee', 'apple'),
        [
          TileMark.correct,
          TileMark.present,
          TileMark.absent,
          TileMark.absent,
          TileMark.correct,
        ],
      );
    });

    test('rejects guesses with a different number of letters', () {
      expect(() => scoreGuess('abc', 'abcd'), throwsArgumentError);
    });
  });
}
