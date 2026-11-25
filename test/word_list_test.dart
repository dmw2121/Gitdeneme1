import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo/game_logic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundles 1,000 valid Turkish words for each supported length', () async {
    final json = jsonDecode(
      await rootBundle.loadString('assets/words_tr.json'),
    ) as Map<String, dynamic>;

    expect(json.keys.toSet(), {'4', '5', '6', '7'});
    for (final entry in json.entries) {
      final length = int.parse(entry.key);
      final words = (entry.value as List<dynamic>).cast<String>();

      expect(words, hasLength(1000));
      expect(words.toSet(), hasLength(1000));
      expect(words.every((word) => isTurkishWord(word, length: length)), isTrue);
    }
  });
}
