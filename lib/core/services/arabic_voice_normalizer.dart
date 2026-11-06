import '../../data/models/excel_vehicle_model.dart';

/// Comprehensive Arabic voice plate normalizer & multi-plate extractor.
/// Ported exactly from CarLogix high-speed engine in the web application.
class ArabicVoiceNormalizer {
  ArabicVoiceNormalizer._();

  static const List<String> carBrands = [
    'مرسيدس', 'تويوتا', 'نيسان', 'هيونداي', 'كيا', 'فورد', 'شيفروليه',
    'النترا', 'كورولا', 'كامري', 'سوناتا', 'اكسنت', 'بي ام', 'لكزس', 'مازدا', 'هافال', 'جيلي'
  ];

  static const List<String> noteKeywords = [
    'جراج يمين', 'برحة يسار', 'موقف مظلل', 'عطلانة', 'مركونة', 'مطربة', 'مصدومة'
  ];

  static const List<MapEntry<String, int>> numUnits = [
    MapEntry('واحد', 1),
    MapEntry('اثنين', 2),
    MapEntry('اتنين', 2),
    MapEntry('ثلاثه', 3),
    MapEntry('تلاته', 3),
    MapEntry('ثلاث', 3),
    MapEntry('تلات', 3),
    MapEntry('اربعه', 4),
    MapEntry('اربع', 4),
    MapEntry('خمسه', 5),
    MapEntry('خمس', 5),
    MapEntry('سته', 6),
    MapEntry('ست', 6),
    MapEntry('سبعه', 7),
    MapEntry('سبع', 7),
    MapEntry('ثمانيه', 8),
    MapEntry('تمانيه', 8),
    MapEntry('ثمان', 8),
    MapEntry('تمان', 8),
    MapEntry('تسعه', 9),
    MapEntry('تسع', 9),
  ];

  static const List<MapEntry<String, int>> numTens = [
    MapEntry('عشرين', 20),
    MapEntry('ثلاثين', 30),
    MapEntry('تلاتين', 30),
    MapEntry('اربعين', 40),
    MapEntry('خمسين', 50),
    MapEntry('ستين', 60),
    MapEntry('سبعين', 70),
    MapEntry('ثمانين', 80),
    MapEntry('تمانين', 80),
    MapEntry('تسعين', 90),
  ];

  /// NOTE: Dart's `\b` only knows ASCII word characters, so `\bخمسه\b` can
  /// never match between spaces and Arabic text. These lookarounds are the
  /// Arabic-aware replacement for `\b`.
  static String _w(String pattern) => '(?<![ء-ي])(?:$pattern)(?![ء-ي])';

  static final List<MapEntry<RegExp, String>> arNumRules = _initNumRules();

  static List<MapEntry<RegExp, String>> _initNumRules() {
    final rules = <MapEntry<RegExp, String>>[];
    for (final ten in numTens) {
      for (final unit in numUnits) {
        final pattern = '(?:و\\s*)?${unit.key}\\s*و\\s*${ten.key}(?![ء-ي])';
        rules.add(MapEntry(RegExp('(?<![ء-ي])$pattern'), '${ten.value + unit.value}'));
      }
    }
    for (final ten in numTens) {
      rules.add(MapEntry(RegExp(_w('(?:و\\s*)?${ten.key}')), '${ten.value}'));
    }
    final singles = <MapEntry<RegExp, String>>[
      MapEntry(RegExp(_w('(?:و\\s*)?(?:صفر|زيرو)')), '0'),
      MapEntry(RegExp(_w('(?:و\\s*)?واحد')), '1'),
      MapEntry(RegExp(_w('(?:و\\s*)?(?:اثنين|اتنين)')), '2'),
      MapEntry(RegExp(_w('(?:و\\s*)?(?:ثلاث[هة]?|تلات[هة]?)')), '3'),
      MapEntry(RegExp(_w('(?:و\\s*)?اربع[هة]?')), '4'),
      MapEntry(RegExp(_w('(?:و\\s*)?خمس[هة]?')), '5'),
      MapEntry(RegExp(_w('(?:و\\s*)?ست[هة]?')), '6'),
      MapEntry(RegExp(_w('(?:و\\s*)?سبع[هة]?')), '7'),
      MapEntry(RegExp(_w('(?:و\\s*)?(?:ثماني[هة]?|تماني[هة]?|ثمان|تمان)')), '8'),
      MapEntry(RegExp(_w('(?:و\\s*)?تسع[هة]?')), '9'),
    ];
    rules.addAll(singles);
    return rules;
  }

  /// Spoken letter names including colloquial Arabic/Egyptian speech recognition variants
  /// (e.g. Google STT writes: "به" for ب, "يه" for ي, "طه" for ط, "را" for ر).
  static final List<MapEntry<RegExp, String>> arLetterNames = [
    MapEntry(RegExp(_w('الف')), 'ا'),
    MapEntry(RegExp(_w('باء|به')), 'ب'),
    MapEntry(RegExp(_w('تاء|ته')), 'ت'),
    MapEntry(RegExp(_w('ثاء|ثه')), 'ث'),
    MapEntry(RegExp(_w('جيم')), 'ج'),
    MapEntry(RegExp(_w('حاء|حا|حه')), 'ح'),
    MapEntry(RegExp(_w('خاء|خا|خه')), 'خ'),
    MapEntry(RegExp(_w('دال|ده')), 'د'),
    MapEntry(RegExp(_w('ذال|ذه')), 'ذ'),
    MapEntry(RegExp(_w('راء|را|ره')), 'ر'),
    MapEntry(RegExp(_w('زاي|زا|زه')), 'ز'),
    MapEntry(RegExp(_w('سين|سا')), 'س'),
    MapEntry(RegExp(_w('شين|شا')), 'ش'),
    MapEntry(RegExp(_w('صاد|صا')), 'ص'),
    MapEntry(RegExp(_w('ضاد|ضا')), 'ض'),
    MapEntry(RegExp(_w('طاء|طا|طه')), 'ط'),
    MapEntry(RegExp(_w('ظاء|ظا|ظه')), 'ظ'),
    MapEntry(RegExp(_w('عين|عا|عه')), 'ع'),
    MapEntry(RegExp(_w('غين|غا|غه')), 'غ'),
    MapEntry(RegExp(_w('فاء|فا|فه')), 'ف'),
    MapEntry(RegExp(_w('قاف|قا|قه')), 'ق'),
    MapEntry(RegExp(_w('كاف|كا|كه')), 'ك'),
    MapEntry(RegExp(_w('لام|لا')), 'ل'),
    MapEntry(RegExp(_w('ميم|ما|مه')), 'م'),
    MapEntry(RegExp(_w('نون|نا|نه')), 'ن'),
    MapEntry(RegExp(_w('هاء|ها|هه')), 'ه'),
    MapEntry(RegExp(_w('واو|وا')), 'و'),
    MapEntry(RegExp(_w('ياء|يه|يا')), 'ي'),
  ];

  /// Normalize raw Arabic speech transcript into canonical letters and digits
  // One-entry memo: every partial speech result is normalised by the plate
  // extractor, the slot extractor, the orphan-note check and the provider on
  // the SAME string. ~200 regex passes each time -> now computed once.
  static String? _memoIn;
  static String _memoOut = '';

  static String normalizeArabicSpoken(String text) {
    if (text.isEmpty) return '';
    if (text == _memoIn) return _memoOut;
    final out = _normalizeUncached(text);
    _memoIn = text;
    _memoOut = out;
    return out;
  }

  static String _normalizeUncached(String text) {

    // Convert Hindi/Eastern digits to Western Arabic digits
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    var cleaned = text.replaceAllMapped(RegExp(r'[٠-٩]'), (match) {
      final digit = match.group(0)!;
      return '${arabicDigits.indexOf(digit)}';
    });

    // Normalize Arabic letters
    cleaned = cleaned
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');

    // Replace Spoken Letter Names (الف -> ا, باء -> ب)
    for (final entry in arLetterNames) {
      cleaned = cleaned.replaceAll(entry.key, ' ${entry.value} ');
    }

    // Replace Spoken Numbers & Compounds (خمسة وعشرين -> 25)
    for (final entry in arNumRules) {
      cleaned = cleaned.replaceAll(entry.key, ' ${entry.value} ');
    }

    // Collapse continuous adjacent digits
    var prev = '';
    while (prev != cleaned) {
      prev = cleaned;
      cleaned = cleaned.replaceAllMapped(RegExp(r'(\d+)\s+(\d+)'), (m) => '${m.group(1)}${m.group(2)}');
    }

    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Normalizer for plate string matching (removes all whitespace, standardizes alefs/yahs/digits)
  static String normalizePlateForMatch(String plate) {
    if (plate.isEmpty) return '';
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    return plate
        .replaceAllMapped(RegExp(r'[٠-٩]'), (m) => '${arabicDigits.indexOf(m.group(0)!)}')
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
  }

  static final RegExp _singleLetter = RegExp(r'^[ا-ي]$');
  static final RegExp _digitsOnly = RegExp(r'^\d+$');

  static bool _isLetter(String t) => _singleLetter.hasMatch(t);
  static bool _isDigits(String t) => _digitsOnly.hasMatch(t);
  static bool _isPlateDigits(String t) => _isDigits(t) && t.length >= 4;

  /// Spoken trigger for an explicit note: "ر س ر 9332 ملحوظة مركونة قدام الباب".
  /// Everything after it (until the next plate) is the note. Letters are
  /// already normalised here (ة -> ه).
  static final RegExp _noteTriggerRe = RegExp(r'^(?:ال)?(?:ملحوظ|ملاحظ)');
  static bool _isNoteTrigger(String t) => t == 'نوت' || _noteTriggerRe.hasMatch(t);
  static const String _noteMark = '\u0001';

  /// True when a new plate (letters + 4 digits) starts at token [k].
  static bool _startsPlate(List<String> tokens, int k) {
    var j = k;
    var n = 0;
    while (j < tokens.length && _isLetter(tokens[j])) {
      n++;
      j++;
    }
    if (n >= 2 && j < tokens.length && _isPlateDigits(tokens[j])) return true;
    if (n == 0 &&
        k + 1 < tokens.length &&
        tokens[k].length >= 2 &&
        tokens[k].length <= 3 &&
        RegExp(r'^[ا-ي]+$').hasMatch(tokens[k]) &&
        _isPlateDigits(tokens[k + 1])) {
      return true;
    }
    return false;
  }

  /// Words that start/stop a sticky mode and must never become a plate note.
  static const List<String> _controlWords = ['بدايه', 'انتهي', 'انتهت'];

  /// Multi-plate scanner (token based).
  ///
  /// Reads the transcript as: letters (2-4) + 4 digits, optionally followed by
  /// free words. Those free words (e.g. "مركونة", "عطلانة", a brand) belong to
  /// the plate that came right before them and become that plate's NOTE only —
  /// they are never mixed into the plate itself.
  static List<ParsedPlateData> extractPlatesFromTranscript(
    String transcriptChunk, {
    String? stickyNote,
  }) {
    final normalized = normalizeArabicSpoken(transcriptChunk);
    final results = <ParsedPlateData>[];
    if (normalized.isEmpty) return results;

    final tokens = normalized.split(' ').where((t) => t.isNotEmpty).toList();
    int i = 0;

    while (i < tokens.length) {
      final letters = <String>[];
      int j = i;

      // Case A: letters spoken one by one  ->  "ر س ص"
      while (j < tokens.length && _isLetter(tokens[j])) {
        letters.add(tokens[j]);
        j++;
      }

      // Case B: recogniser glued the letters into one short word -> "رسص 5352"
      if (letters.isEmpty &&
          j + 1 < tokens.length &&
          tokens[j].length >= 2 &&
          tokens[j].length <= 3 &&
          RegExp(r'^[ا-ي]+$').hasMatch(tokens[j]) &&
          _isPlateDigits(tokens[j + 1])) {
        letters.addAll(tokens[j].split(''));
        j++;
      }

      if (letters.length >= 2 && j < tokens.length && _isPlateDigits(tokens[j])) {
        final usedLetters = letters.length > 4 ? letters.sublist(letters.length - 3) : letters;
        final digits = tokens[j].substring(0, 4);

        // Everything spoken after the digits, up to the next plate, is the note.
        // If the word "ملحوظة" is spoken, only what follows it is the note and
        // it may contain any words (even single letters like "و").
        var k = j + 1;
        final tail = <String>[];
        var noteMode = false;
        while (k < tokens.length) {
          final tk = tokens[k];
          if (_controlWords.contains(tk)) break;
          if (!noteMode && _isNoteTrigger(tk)) {
            noteMode = true;
            tail.add(_noteMark);
            k++;
            continue;
          }
          if (noteMode) {
            if (_startsPlate(tokens, k)) break;
          } else if (_isLetter(tk) || _isDigits(tk)) {
            break;
          }
          tail.add(tk);
          k++;
        }
        // A short word right before the next 4 digits is that plate's letters.
        if (!noteMode &&
            tail.isNotEmpty &&
            k < tokens.length &&
            _isPlateDigits(tokens[k]) &&
            tail.last.length <= 3) {
          tail.removeLast();
          k--;
        }

        final mark = tail.indexOf(_noteMark);
        var preText = mark == -1 ? tail.join(' ') : tail.sublist(0, mark).join(' ');
        var noteText = mark == -1 ? preText : tail.sublist(mark + 1).join(' ');
        if (mark == -1) preText = '';

        var detectedCar = '-';
        for (final brand in carBrands) {
          if (preText.contains(brand) || noteText.contains(brand)) {
            detectedCar = brand;
            preText = preText.replaceAll(brand, ' ');
            noteText = noteText.replaceAll(brand, ' ');
            break;
          }
        }
        noteText = noteText.replaceAll(RegExp(r'\s+'), ' ').trim();
        final detectedNotes = noteText.isNotEmpty ? noteText : (stickyNote ?? '-');

        final formattedLetters = usedLetters.join(' ');
        results.add(ParsedPlateData(
          fullPlate: '$formattedLetters $digits',
          letters: formattedLetters,
          digits: digits,
          detectedBrand: detectedCar,
          detectedNote: detectedNotes,
        ));
        i = k;
        continue;
      }

      i = j > i ? j : i + 1;
    }

    return results;
  }

  /// Canonical key used to match plates between sheets and speech:
  /// Arabic letters (in spoken order) followed by the digits, no spaces.
  /// Works whether the cell is "ر س ر 9332", "رسر9332" or "9332 ر س ر".
  static String plateKey(String plate) {
    final n = normalizePlateForMatch(plate);
    final letters = n.replaceAll(RegExp(r'[^ا-ي]'), '');
    final digits = n.replaceAll(RegExp(r'[^0-9]'), '');
    return '$letters$digits';
  }

  /// A note spoken on its own, with NO plate before it in this transcript
  /// ("ملحوظة مركونة قدام الباب" said after a pause, or after the recogniser
  /// restarted). It belongs to the plate that was recorded just before.
  static String? orphanNote(String transcriptChunk) {
    final normalized = normalizeArabicSpoken(transcriptChunk);
    if (normalized.isEmpty) return null;
    final tokens = normalized.split(' ').where((t) => t.isNotEmpty).toList();
    final t = tokens.indexWhere(_isNoteTrigger);
    if (t == -1) return null;
    if (extractPlatesFromTranscript(tokens.sublist(0, t).join(' ')).isNotEmpty) return null;
    final words = <String>[];
    for (var k = t + 1; k < tokens.length; k++) {
      if (_controlWords.contains(tokens[k])) break;
      if (_startsPlate(tokens, k)) break;
      words.add(tokens[k]);
    }
    final note = words.join(' ').trim();
    return note.isEmpty ? null : note;
  }

  /// The plate that is being spoken RIGHT NOW (l1..l3, d1..d4).
  /// As soon as new letters start after digits, the slots reset: that is a
  /// new plate / new row, we never wait for a note.
  static Map<String, String> extractSlots(String transcriptChunk) {
    final normalized = normalizeArabicSpoken(transcriptChunk);
    final tokens = normalized.split(' ').where((t) => t.isNotEmpty).toList();

    var letters = <String>[];
    var digits = '';
    var noteMode = false;
    for (var i = 0; i < tokens.length; i++) {
      final tk = tokens[i];
      if (_isNoteTrigger(tk)) {
        noteMode = true;
        continue;
      }
      if (noteMode) {
        if (_startsPlate(tokens, i)) {
          noteMode = false;
        } else {
          continue;
        }
      }
      if (_isLetter(tk)) {
        if (digits.isNotEmpty) {
          letters = <String>[];
          digits = '';
        }
        letters.add(tk);
      } else if (_isDigits(tk)) {
        digits += tk;
      } else if (tk.length >= 2 &&
          tk.length <= 3 &&
          RegExp(r'^[ا-ي]+$').hasMatch(tk) &&
          i + 1 < tokens.length &&
          _isDigits(tokens[i + 1])) {
        if (digits.isNotEmpty) {
          letters = <String>[];
          digits = '';
        }
        letters.addAll(tk.split(''));
      }
    }

    final lList = letters.length > 3 ? letters.sublist(letters.length - 3) : letters;
    final dList = (digits.length > 4 ? digits.substring(0, 4) : digits).split('');

    return {
      'l1': lList.isNotEmpty ? lList[0] : '-',
      'l2': lList.length > 1 ? lList[1] : '-',
      'l3': lList.length > 2 ? lList[2] : '-',
      'd1': dList.isNotEmpty && dList[0].isNotEmpty ? dList[0] : '-',
      'd2': dList.length > 1 ? dList[1] : '-',
      'd3': dList.length > 2 ? dList[2] : '-',
      'd4': dList.length > 3 ? dList[3] : '-',
    };
  }
}
