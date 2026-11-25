const String turkishAlphabet = 'abcçdefgğhıijklmnoöprsştuüvyz';

enum TileMark { empty, correct, present, absent }

String normalizeTurkish(String input) {
  return input
      .replaceAll('I\u0307', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase()
      .replaceAll('\u0307', '');
}

String turkishUpperCase(String input) {
  return normalizeTurkish(input)
      .replaceAll('i', 'İ')
      .replaceAll('ı', 'I')
      .replaceAll('ç', 'Ç')
      .replaceAll('ğ', 'Ğ')
      .replaceAll('ö', 'Ö')
      .replaceAll('ş', 'Ş')
      .replaceAll('ü', 'Ü')
      .toUpperCase();
}

bool isTurkishWord(String word, {int? length}) {
  final normalized = normalizeTurkish(word);
  final letters = normalized.runes.map(String.fromCharCode).toList();
  return (length == null || letters.length == length) &&
      letters.isNotEmpty &&
      letters.every(turkishAlphabet.contains);
}

List<TileMark> scoreGuess(String guess, String answer) {
  final letters = normalizeTurkish(guess).runes.map(String.fromCharCode).toList();
  final answerLetters =
      normalizeTurkish(answer).runes.map(String.fromCharCode).toList();
  if (letters.length != answerLetters.length) {
    throw ArgumentError('Guess and answer must have the same number of letters.');
  }

  final marks = List<TileMark>.filled(letters.length, TileMark.absent);
  final remaining = <String, int>{};

  for (var index = 0; index < letters.length; index++) {
    if (letters[index] == answerLetters[index]) {
      marks[index] = TileMark.correct;
    } else {
      remaining.update(
        answerLetters[index],
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
  }

  for (var index = 0; index < letters.length; index++) {
    if (marks[index] == TileMark.correct) continue;

    final count = remaining[letters[index]] ?? 0;
    if (count > 0) {
      marks[index] = TileMark.present;
      remaining[letters[index]] = count - 1;
    }
  }

  return marks;
}

TileMark strongerMark(TileMark first, TileMark second) {
  int rank(TileMark mark) => switch (mark) {
        TileMark.empty => 0,
        TileMark.absent => 1,
        TileMark.present => 2,
        TileMark.correct => 3,
      };

  return rank(second) > rank(first) ? second : first;
}
