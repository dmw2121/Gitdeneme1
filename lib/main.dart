import 'dart:convert';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_logic.dart';
import 'game_stats.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LingoApp());
}

class LingoApp extends StatefulWidget {
  const LingoApp({super.key});

  @override
  State<LingoApp> createState() => _LingoAppState();
}

class _LingoAppState extends State<LingoApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lingo',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: LingoGamePage(
        onThemeChanged: _setThemeMode,
        currentTheme: _themeMode,
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF278C73),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF121614) : const Color(0xFFF9FBF9),
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? const Color(0xFF121614) : const Color(0xFFF9FBF9),
        foregroundColor: isDark ? Colors.white : const Color(0xFF17201C),
        centerTitle: true,
      ),
    );
  }
}

class LingoGamePage extends StatefulWidget {
  const LingoGamePage({
    required this.onThemeChanged,
    required this.currentTheme,
    super.key,
  });

  final ValueChanged<ThemeMode> onThemeChanged;
  final ThemeMode currentTheme;

  @override
  State<LingoGamePage> createState() => _LingoGamePageState();
}

class _LingoGamePageState extends State<LingoGamePage> {
  static const _attemptLimit = 6;
  static const _keyboardRows = [
    ['e', 'r', 't', 'y', 'u', 'ı', 'o', 'p', 'ğ', 'ü'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'ş', 'i'],
    ['z', 'c', 'v', 'b', 'n', 'm', 'ö', 'ç'],
  ];

  final _random = Random();
  Map<int, List<String>> _words = {};
  Set<String> _wordSet = {};
  List<String> _guesses = [];
  GameStats _stats = const GameStats();
  SharedPreferencesAsync? _preferences;
  String _answer = '';
  String _currentGuess = '';
  String? _error;
  int _wordLength = 5;
  int? _hintIndex;
  bool _ready = false;
  bool _completed = false;
  bool _themeReady = false;
  bool _restoredThemeDark = false;

  int get _attemptsLeft => _attemptLimit - _guesses.length;
  bool get _isDark => widget.currentTheme == ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final wordsJson = jsonDecode(
        await rootBundle.loadString('assets/words_tr.json'),
      ) as Map<String, dynamic>;
      _words = {
        for (final entry in wordsJson.entries)
          int.parse(entry.key): (entry.value as List<dynamic>)
              .cast<String>()
              .map(normalizeTurkish)
              .toList(),
      };
      final preferences = SharedPreferencesAsync();
      _preferences = preferences;
      _wordLength = await preferences.getInt('mode') ?? 5;
      if (!_words.containsKey(_wordLength)) _wordLength = 5;
      _stats = GameStats.fromJson(
        jsonDecode(await preferences.getString('stats') ?? '{}')
            as Map<String, dynamic>,
      );
      _restoredThemeDark = await preferences.getBool('darkTheme') ?? false;
      _wordSet = _words[_wordLength]!.toSet();

      final savedLength = await preferences.getInt('activeLength');
      final savedAnswer =
          normalizeTurkish(await preferences.getString('activeAnswer') ?? '');
      final savedGuesses =
          jsonDecode(await preferences.getString('activeGuesses') ?? '[]')
              as List<dynamic>;
      final restoredGuesses = savedGuesses.cast<String>().map(normalizeTurkish);
      if (savedLength == _wordLength &&
          _wordSet.contains(savedAnswer) &&
          restoredGuesses.length <= _attemptLimit &&
          restoredGuesses.every(_wordSet.contains)) {
        _answer = savedAnswer;
        _guesses = restoredGuesses.toList();
        final savedHintIndex = await preferences.getInt('hintIndex');
        _hintIndex = savedHintIndex != null &&
                savedHintIndex >= 0 &&
                savedHintIndex < _wordLength
            ? savedHintIndex
            : null;
        _completed = _guesses.contains(_answer) ||
            _guesses.length == _attemptLimit;
      } else {
        await _startNewGame();
      }

      if (mounted) {
        widget.onThemeChanged(
          _restoredThemeDark ? ThemeMode.dark : ThemeMode.light,
        );
        setState(() {
          _themeReady = true;
          _ready = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Oyun verileri yüklenemedi: $error';
          _ready = true;
        });
      }
    }
  }

  Future<void> _startNewGame() async {
    final options = _words[_wordLength];
    if (options == null || options.isEmpty) {
      throw StateError('$_wordLength harfli kelime listesi boş.');
    }
    setState(() {
      _answer = options[_random.nextInt(options.length)];
      _guesses = [];
      _currentGuess = '';
      _hintIndex = null;
      _completed = false;
      _wordSet = options.toSet();
    });
    await _saveGame();
  }

  Future<void> _saveGame() async {
    final preferences = _preferences;
    if (preferences == null || _answer.isEmpty) return;
    await preferences.setInt('activeLength', _wordLength);
    await preferences.setString('activeAnswer', _answer);
    await preferences.setString('activeGuesses', jsonEncode(_guesses));
    if (_hintIndex case final hint?) {
      await preferences.setInt('hintIndex', hint);
    } else {
      await preferences.remove('hintIndex');
    }
  }

  Future<void> _chooseLength(int length) async {
    if (length == _wordLength) return;
    setState(() {
      _wordLength = length;
      _wordSet = _words[length]!.toSet();
      _currentGuess = '';
    });
    await _preferences?.setInt('mode', length);
    await _startNewGame();
  }

  void _addLetter(String letter) {
    if (_completed || _currentGuess.runes.length >= _wordLength) return;
    setState(() => _currentGuess += letter);
  }

  void _removeLetter() {
    if (_completed || _currentGuess.isEmpty) return;
    final letters = _currentGuess.runes.toList()..removeLast();
    setState(() => _currentGuess = String.fromCharCodes(letters));
  }

  Future<void> _submitGuess() async {
    if (_completed) return;
    if (_currentGuess.runes.length != _wordLength) {
      _showMessage('$_wordLength harfli bir kelime gir.');
      return;
    }
    final guess = normalizeTurkish(_currentGuess);
    if (!isTurkishWord(guess, length: _wordLength) ||
        !_wordSet.contains(guess)) {
      _showMessage('Bu kelime sözlükte bulunamadı.');
      return;
    }

    setState(() {
      _guesses = [..._guesses, guess];
      _currentGuess = '';
    });
    await _saveGame();
    if (!mounted) return;

    final didWin = guess == _answer;
    if (didWin || _guesses.length == _attemptLimit) {
      setState(() => _completed = true);
      await _recordResult(didWin);
      if (mounted) await _showResultDialog(didWin);
    }
  }

  Future<void> _recordResult(bool didWin) async {
    _stats = _stats.record(
      didWin: didWin,
      guessCount: didWin ? _guesses.length : null,
    );
    await _preferences?.setString('stats', jsonEncode(_stats.toJson()));
  }

  Future<void> _showResultDialog(bool didWin) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          didWin ? Icons.celebration_rounded : Icons.lightbulb_outline_rounded,
          color: const Color(0xFF278C73),
          size: 34,
        ),
        title: Text(didWin ? 'Tebrikler!' : 'Bir dahaki sefere'),
        content: Text(
          didWin
              ? 'Kelimeyi ${_guesses.length}. tahminde buldun: '
                  '${turkishUpperCase(_answer)}'
              : 'Doğru kelime ${turkishUpperCase(_answer)} idi.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _startNewGame();
            },
            child: const Text('Yeni oyun'),
          ),
        ],
      ),
    );
  }

  Future<void> _showHint() async {
    if (_completed) return;
    if (_hintIndex != null) {
      _showHintMessage(_hintIndex!);
      return;
    }

    final solvedPositions = <int>{};
    for (final guess in _guesses) {
      final marks = scoreGuess(guess, _answer);
      for (var index = 0; index < marks.length; index++) {
        if (marks[index] == TileMark.correct) solvedPositions.add(index);
      }
    }
    final candidates = List<int>.generate(_wordLength, (index) => index)
        .where((index) => !solvedPositions.contains(index))
        .toList();
    final index = candidates.isEmpty
        ? _random.nextInt(_wordLength)
        : candidates[_random.nextInt(candidates.length)];
    setState(() {
      _hintIndex = index;
    });
    await _saveGame();
    if (mounted) _showHintMessage(index);
  }

  void _showHintMessage(int index) {
    _showMessage(
      'İpucu: ${index + 1}. harf ${turkishUpperCase(_answer[index])}.',
    );
  }

  Future<void> _showStats() async {
    final winRate =
        _stats.played == 0 ? 0 : (_stats.won * 100 / _stats.played).round();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İstatistikler'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatValue(label: 'Oyun', value: '${_stats.played}'),
                _StatValue(label: 'Kazanma', value: '$winRate%'),
                _StatValue(label: 'Seri', value: '${_stats.streak}'),
                _StatValue(label: 'En iyi', value: '${_stats.bestStreak}'),
              ],
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tahmin dağılımı',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            for (var count = 1; count <= _attemptLimit; count++)
              _GuessDistributionRow(
                count: count,
                value: _stats.guesses[count] ?? 0,
                maxValue: _stats.guesses.values.fold<int>(
                  1,
                  (maximum, value) => value > maximum ? value : maximum,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareResult() async {
    if (_guesses.isEmpty) {
      _showMessage('Paylaşmak için önce bir tahmin yap.');
      return;
    }
    final rows = _guesses.map((guess) {
      final marks = scoreGuess(guess, _answer);
      return marks.map((mark) {
        return switch (mark) {
          TileMark.correct => '🟩',
          TileMark.present => '🟨',
          TileMark.absent || TileMark.empty => '⬛',
        };
      }).join();
    }).join('\n');
    final result = _completed && _guesses.last == _answer
        ? '${_guesses.length}/$_attemptLimit'
        : _completed
            ? 'X/$_attemptLimit'
            : '${_guesses.length}/$_attemptLimit';
    await SharePlus.instance.share(
      ShareParams(text: 'Lingo $result\n\n$rows'),
    );
  }

  Future<void> _toggleTheme() async {
    final newMode = _isDark ? ThemeMode.light : ThemeMode.dark;
    widget.onThemeChanged(newMode);
    await _preferences?.setBool('darkTheme', newMode == ThemeMode.dark);
  }

  Map<String, TileMark> _keyboardMarks() {
    final marks = <String, TileMark>{};
    for (final guess in _guesses) {
      final letters = guess.runes.map(String.fromCharCode).toList();
      final result = scoreGuess(guess, _answer);
      for (var index = 0; index < letters.length; index++) {
        marks[letters[index]] =
            strongerMark(marks[letters[index]] ?? TileMark.empty, result[index]);
      }
    }
    return marks;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  Color _markColor(TileMark mark, ColorScheme colors) => switch (mark) {
        TileMark.correct => const Color(0xFF278C73),
        TileMark.present => const Color(0xFFE6B84A),
        TileMark.absent => _isDark ? const Color(0xFF3B4440) : Colors.blueGrey,
        TileMark.empty => _isDark ? const Color(0xFF242B27) : Colors.white,
      };

  @override
  Widget build(BuildContext context) {
    if (_error case final error?) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (!_ready || !_themeReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final colors = Theme.of(context).colorScheme;
    final keyboardMarks = _keyboardMarks();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'İstatistikler',
          onPressed: _showStats,
          icon: const Icon(Icons.bar_chart_rounded),
        ),
        title: const Text(
          'LINGO',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sonucu paylaş',
            onPressed: _shareResult,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            tooltip: _isDark ? 'Açık tema' : 'Koyu tema',
            onPressed: _toggleTheme,
            icon: Icon(_isDark ? Icons.light_mode : Icons.dark_mode_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tileSize = min(
              58.0,
              (constraints.maxWidth - 36 - (_wordLength - 1) * 5) /
                  _wordLength,
            ).toDouble();
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LengthSelector(
                    selectedLength: _wordLength,
                    onSelected: _chooseLength,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _completed
                        ? 'Yeni oyun için düğmeye dokun'
                        : 'Kelimeyi 6 tahminde bul',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  for (var row = 0; row < _attemptLimit; row++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var column = 0;
                              column < _wordLength;
                              column++) ...[
                            if (column > 0) const SizedBox(width: 5),
                            _buildTile(row, column, tileSize, colors),
                          ],
                        ],
                      ),
                    ),
                  if (_hintIndex != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        'Açılan harf: ${_hintIndex! + 1}. '
                        'harf ${turkishUpperCase(_answer[_hintIndex!])}',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  for (var row = 0; row < _keyboardRows.length; row++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: _buildKeyboardRow(
                        row,
                        keyboardMarks,
                        colors,
                      ),
                    ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Kalan tahmin: $_attemptsLeft',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 14),
                      TextButton.icon(
                        onPressed: _completed ? _startNewGame : _showHint,
                        icon: Icon(
                          _completed ? Icons.refresh_rounded : Icons.lightbulb,
                          size: 18,
                        ),
                        label: Text(_completed ? 'Yeni oyun' : 'İpucu'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTile(
    int row,
    int column,
    double size,
    ColorScheme colors,
  ) {
    String letter = '';
    var mark = TileMark.empty;
    if (row < _guesses.length) {
      final guess = _guesses[row];
      final letters = guess.runes.map(String.fromCharCode).toList();
      letter = letters[column];
      mark = scoreGuess(guess, _answer)[column];
    } else if (row == _guesses.length) {
      final letters = _currentGuess.runes.map(String.fromCharCode).toList();
      if (column < letters.length) letter = letters[column];
    }

    final guessed = row < _guesses.length;
    final background = guessed
        ? _markColor(mark, colors)
        : _markColor(TileMark.empty, colors);
    final border = guessed
        ? background
        : letter.isNotEmpty
            ? colors.onSurfaceVariant
            : _isDark
                ? const Color(0xFF38413C)
                : const Color(0xFFD8DFDB);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border, width: letter.isNotEmpty ? 2 : 1.5),
        borderRadius: BorderRadius.circular(9),
        boxShadow: guessed
            ? [
                BoxShadow(
                  color: background.withValues(alpha: 0.18),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: AnimatedScale(
        scale: letter.isEmpty ? 1 : 1.03,
        duration: const Duration(milliseconds: 180),
        child: Text(
          turkishUpperCase(letter),
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
            color: guessed
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboardRow(
    int row,
    Map<String, TileMark> marks,
    ColorScheme colors,
  ) {
    final letters = _keyboardRows[row];
    final rowStart = row == 0 ? 0 : row == 1 ? 10 : 21;
    final rowEnd = rowStart + letters.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (row == 2)
          _keyboardButton(
            label: 'GİR',
            color: colors.primary,
            foreground: Colors.white,
            flex: 15,
            onPressed: _submitGuess,
          ),
        for (var index = rowStart; index < rowEnd; index++)
          _keyboardButton(
            label: turkishUpperCase(letters[index - rowStart]),
            color: _keyboardColor(
              marks[letters[index - rowStart]] ?? TileMark.empty,
              colors,
            ),
            foreground: _keyboardForeground(
              marks[letters[index - rowStart]] ?? TileMark.empty,
            ),
            flex: 10,
            onPressed: () => _addLetter(letters[index - rowStart]),
          ),
        if (row == 2)
          _keyboardButton(
            label: '⌫',
            color: _isDark ? const Color(0xFF303A35) : const Color(0xFFE5EAE7),
            foreground: colors.onSurface,
            flex: 15,
            onPressed: _removeLetter,
          ),
      ],
    );
  }

  Widget _keyboardButton({
    required String label,
    required Color color,
    required Color foreground,
    required int flex,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: SizedBox(
          height: 46,
          child: Material(
            color: color,
            borderRadius: BorderRadius.circular(7),
            child: InkWell(
              borderRadius: BorderRadius.circular(7),
              onTap: onPressed,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: label.length > 1 ? 10 : 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _keyboardColor(TileMark mark, ColorScheme colors) {
    if (mark == TileMark.empty) {
      return _isDark ? const Color(0xFF303A35) : const Color(0xFFE5EAE7);
    }
    return _markColor(mark, colors);
  }

  Color _keyboardForeground(TileMark mark) {
    if (mark == TileMark.empty || mark == TileMark.present) {
      return _isDark ? Colors.white : const Color(0xFF17201C);
    }
    return Colors.white;
  }
}

class _LengthSelector extends StatelessWidget {
  const _LengthSelector({
    required this.selectedLength,
    required this.onSelected,
  });

  final int selectedLength;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 4, label: Text('4')),
        ButtonSegment(value: 5, label: Text('5')),
        ButtonSegment(value: 6, label: Text('6')),
        ButtonSegment(value: 7, label: Text('7')),
      ],
      selected: {selectedLength},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onSelected(selection.first),
    );
  }
}

class _StatValue extends StatelessWidget {
  const _StatValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _GuessDistributionRow extends StatelessWidget {
  const _GuessDistributionRow({
    required this.count,
    required this.value,
    required this.maxValue,
  });

  final int count;
  final int value;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 18, child: Text('$count')),
          Expanded(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: maxValue == 0 ? 0 : value / maxValue,
              child: Container(
                height: 22,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: value > 0 ? colors.primary : colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$value',
                  style: TextStyle(
                    color: value > 0 ? colors.onPrimary : colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
