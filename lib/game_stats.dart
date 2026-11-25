class GameStats {
  const GameStats({
    this.played = 0,
    this.won = 0,
    this.streak = 0,
    this.bestStreak = 0,
    this.guesses = const {},
  });

  final int played;
  final int won;
  final int streak;
  final int bestStreak;
  final Map<int, int> guesses;

  factory GameStats.fromJson(Map<String, dynamic> json) {
    final rawGuesses = json['guesses'];
    final guessCounts = <int, int>{};
    if (rawGuesses is Map) {
      for (final entry in rawGuesses.entries) {
        final key = int.tryParse(entry.key.toString());
        final value = entry.value;
        if (key != null && value is int) guessCounts[key] = value;
      }
    }

    return GameStats(
      played: json['played'] as int? ?? 0,
      won: json['won'] as int? ?? 0,
      streak: json['streak'] as int? ?? 0,
      bestStreak: json['bestStreak'] as int? ?? 0,
      guesses: guessCounts,
    );
  }

  GameStats record({required bool didWin, int? guessCount}) {
    final updatedGuesses = Map<int, int>.of(guesses);
    if (didWin && guessCount != null) {
      updatedGuesses.update(guessCount, (count) => count + 1, ifAbsent: () => 1);
    }
    final updatedStreak = didWin ? streak + 1 : 0;

    return GameStats(
      played: played + 1,
      won: won + (didWin ? 1 : 0),
      streak: updatedStreak,
      bestStreak: updatedStreak > bestStreak ? updatedStreak : bestStreak,
      guesses: updatedGuesses,
    );
  }

  Map<String, Object> toJson() => {
        'played': played,
        'won': won,
        'streak': streak,
        'bestStreak': bestStreak,
        'guesses': guesses.map((key, value) => MapEntry(key.toString(), value)),
      };
}
