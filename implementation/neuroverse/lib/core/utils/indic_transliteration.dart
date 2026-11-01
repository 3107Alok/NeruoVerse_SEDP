/// Pure Dart, 100% Offline Rule-Based Phonetic Transliteration Engine
/// Converts Latin/English spellings of Indian proper nouns (names) into
/// native Indic scripts (Devanagari, Bengali, Assamese) with zero cloud/network latency.
class IndicTransliteration {
  IndicTransliteration._();

  /// Check if the text already contains non-ASCII/Indic characters (e.g. Hindi/Bengali script).
  static bool isAlreadyIndic(String text) {
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      // Devanagari: 0x0900 - 0x097F
      // Bengali/Assamese: 0x0980 - 0x09FF
      if (code >= 0x0900 && code <= 0x09FF) {
        return true;
      }
    }
    return false;
  }

  /// Transliterates an English name into the target language script.
  /// Supported [targetLang]: 'hi' (Hindi), 'bn' (Bengali), 'as' (Assamese),
  /// 'mni' (Manipuri/Bengali script), 'lus' (Mizo - Roman script), 'en' (English).
  static String transliterate(String input, String targetLang) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;

    final lang = targetLang.toLowerCase().trim();

    // English and Mizo officially use Latin/Roman script
    if (lang == 'en' ||
        lang == 'english' ||
        lang.startsWith('en') ||
        lang == 'lus' ||
        lang == 'miz' ||
        lang.contains('mizo')) {
      return trimmed;
    }

    // If already typed in native Indic script, preserve as-is
    if (isAlreadyIndic(trimmed)) {
      return trimmed;
    }

    // Determine target script
    final isBengaliScript = (lang == 'bn' || lang == 'as' || lang == 'mni');
    final isAssamese = (lang == 'as');

    return _transliterateWord(trimmed, isBengali: isBengaliScript, isAssamese: isAssamese);
  }

  static String _transliterateWord(String raw, {required bool isBengali, required bool isAssamese}) {
    final lower = raw.toLowerCase();
    final buffer = StringBuffer();
    int i = 0;
    final len = lower.length;

    bool isStartOfWord = true;

    while (i < len) {
      // 1. Check 3-char consonants (e.g., 'chh', 'ksh')
      if (i + 3 <= len) {
        final tri = lower.substring(i, i + 3);
        if (tri == 'chh') {
          buffer.write(isBengali ? 'ছ' : 'छ');
          i += 3;
          isStartOfWord = false;
          final hasVowel = _consumeNextVowels(lower, buffer, i, len, isBengali, isAssamese, (newI) => i = newI);
          if (!hasVowel && i < len && _isConsonant(lower[i])) {
            buffer.write(isBengali ? '্' : '्');
          }
          continue;
        } else if (tri == 'ksh') {
          buffer.write(isBengali ? 'ক্ষ' : 'क्ष');
          i += 3;
          isStartOfWord = false;
          final hasVowel = _consumeNextVowels(lower, buffer, i, len, isBengali, isAssamese, (newI) => i = newI);
          if (!hasVowel && i < len && _isConsonant(lower[i])) {
            buffer.write(isBengali ? '্' : '्');
          }
          continue;
        }
      }

      // 2. Check 2-char consonants & compound vowels
      if (i + 2 <= len) {
        final pair = lower.substring(i, i + 2);
        final consonantPair = _matchTwoCharConsonant(pair, isBengali, isAssamese);
        if (consonantPair != null) {
          buffer.write(consonantPair);
          i += 2;
          isStartOfWord = false;
          final hasVowel = _consumeNextVowels(lower, buffer, i, len, isBengali, isAssamese, (newI) => i = newI);
          if (!hasVowel && i < len && _isConsonant(lower[i])) {
            buffer.write(isBengali ? '্' : '्');
          }
          continue;
        }

        // Check 2-char independent vowels at start
        if (isStartOfWord) {
          final startVowel = _matchIndependentTwoCharVowel(pair, isBengali);
          if (startVowel != null) {
            buffer.write(startVowel);
            i += 2;
            isStartOfWord = false;
            continue;
          }
        }
      }

      // 3. Check 1-char vowel at start of word / after space
      final c = lower[i];
      if (isStartOfWord) {
        final singleVowel = _matchIndependentSingleVowel(c, isBengali);
        if (singleVowel != null) {
          buffer.write(singleVowel);
          i++;
          isStartOfWord = false;
          continue;
        }
      }

      // 4. Check 1-char consonant
      final singleConsonant = _matchSingleConsonant(c, isBengali, isAssamese, isStartOfWord);
      if (singleConsonant != null) {
        buffer.write(singleConsonant);
        i++;
        isStartOfWord = false;
        final hasVowel = _consumeNextVowels(lower, buffer, i, len, isBengali, isAssamese, (newI) => i = newI);
        if (!hasVowel && i < len && _isConsonant(lower[i])) {
          buffer.write(isBengali ? '্' : '्');
        }
        continue;
      }

      // Separator or unrecognized character
      if (c == ' ' || c == '-' || c == '_') {
        buffer.write(c);
        isStartOfWord = true;
      } else {
        buffer.write(c);
      }
      i++;
    }

    return buffer.toString();
  }

  static bool _isConsonant(String c) {
    return 'bcdfghjklmnpqrstvwxyz'.contains(c);
  }

  static bool _consumeNextVowels(
    String lower,
    StringBuffer buffer,
    int i,
    int len,
    bool isBengali,
    bool isAssamese,
    void Function(int) updateI,
  ) {
    if (i >= len) {
      updateI(i);
      return false;
    }

    // Check 2-char vowel matras
    if (i + 2 <= len) {
      final pair = lower.substring(i, i + 2);
      if (pair == 'aa') {
        buffer.write(isBengali ? '\u09BE' : '\u093E');
        updateI(i + 2);
        return true;
      } else if (pair == 'ee' || pair == 'ii') {
        buffer.write(isBengali ? '\u09C0' : '\u0940');
        updateI(i + 2);
        return true;
      } else if (pair == 'oo' || pair == 'uu') {
        buffer.write(isBengali ? '\u09C2' : '\u0942');
        updateI(i + 2);
        return true;
      } else if (pair == 'ai') {
        buffer.write(isBengali ? '\u09C8' : '\u0948');
        updateI(i + 2);
        return true;
      } else if (pair == 'au' || pair == 'ou') {
        buffer.write(isBengali ? '\u09CC' : '\u094C');
        updateI(i + 2);
        return true;
      }
    }

    // Check 1-char vowel matras
    final c = lower[i];
    if (c == 'a') {
      // In Indian names, terminal 'a' usually denotes 'aa' matra (e.g. Priya -> प्रिया, Sunita -> सुनीता)
      final isEnd = (i + 1 >= len) || lower[i + 1] == ' ' || lower[i + 1] == '-';
      if (isEnd) {
        buffer.write(isBengali ? '\u09BE' : '\u093E');
      }
      updateI(i + 1);
      return true;
    } else if (c == 'i') {
      buffer.write(isBengali ? '\u09BF' : '\u093F');
      updateI(i + 1);
      return true;
    } else if (c == 'u') {
      buffer.write(isBengali ? '\u09C1' : '\u0941');
      updateI(i + 1);
      return true;
    } else if (c == 'e') {
      buffer.write(isBengali ? '\u09C7' : '\u0947');
      updateI(i + 1);
      return true;
    } else if (c == 'o') {
      buffer.write(isBengali ? '\u09CB' : '\u094B');
      updateI(i + 1);
      return true;
    }

    updateI(i);
    return false;
  }

  static String? _matchTwoCharConsonant(String pair, bool isBengali, bool isAssamese) {
    switch (pair) {
      case 'kh':
        return isBengali ? 'খ' : 'ख';
      case 'gh':
        return isBengali ? 'ঘ' : 'घ';
      case 'ch':
        return isBengali ? 'চ' : 'च';
      case 'jh':
        return isBengali ? 'ঝ' : 'झ';
      case 'th':
        return isBengali ? 'থ' : 'थ';
      case 'dh':
        return isBengali ? 'ধ' : 'ध';
      case 'ph':
        return isBengali ? 'ফ' : 'फ';
      case 'bh':
        return isBengali ? 'ভ' : 'भ';
      case 'sh':
        return isBengali ? 'শ' : 'श';
      case 'zh':
        return isBengali ? 'ঝ' : 'झ';
      default:
        return null;
    }
  }

  static String? _matchIndependentTwoCharVowel(String pair, bool isBengali) {
    switch (pair) {
      case 'aa':
        return isBengali ? 'আ' : 'आ';
      case 'ee':
      case 'ii':
        return isBengali ? 'ঈ' : 'ई';
      case 'oo':
      case 'uu':
        return isBengali ? 'ঊ' : 'ऊ';
      case 'ai':
        return isBengali ? 'ঐ' : 'ऐ';
      case 'au':
      case 'ou':
        return isBengali ? 'ঔ' : 'औ';
      default:
        return null;
    }
  }

  static String? _matchIndependentSingleVowel(String c, bool isBengali) {
    switch (c) {
      case 'a':
        return isBengali ? 'আ' : 'आ';
      case 'i':
        return isBengali ? 'ই' : 'इ';
      case 'u':
        return isBengali ? 'উ' : 'उ';
      case 'e':
        return isBengali ? 'এ' : 'ए';
      case 'o':
        return isBengali ? 'ও' : 'ओ';
      default:
        return null;
    }
  }

  static String? _matchSingleConsonant(String c, bool isBengali, bool isAssamese, [bool isStartOfWord = false]) {
    switch (c) {
      case 'k':
        return isBengali ? 'ক' : 'क';
      case 'g':
        return isBengali ? 'গ' : 'ग';
      case 'j':
        return isBengali ? 'জ' : 'ज';
      case 't':
        return isBengali ? 'ত' : 'त';
      case 'd':
        return isBengali ? 'দ' : 'द';
      case 'n':
        return isBengali ? 'ন' : 'न';
      case 'p':
        return isBengali ? 'প' : 'प';
      case 'f':
        return isBengali ? 'ফ' : 'फ';
      case 'b':
        return isBengali ? 'ব' : 'ब';
      case 'm':
        return isBengali ? 'ম' : 'म';
      case 'y':
        return isBengali ? (isStartOfWord ? 'য' : 'য়') : 'य';
      case 'r':
        if (isAssamese) return 'ৰ';
        return isBengali ? 'র' : 'र';
      case 'l':
        return isBengali ? 'ল' : 'ल';
      case 'v':
      case 'w':
        if (isAssamese) return 'ৱ';
        return isBengali ? 'ভ' : 'व';
      case 's':
        return isBengali ? 'স' : 'स';
      case 'h':
        return isBengali ? 'হ' : 'ह';
      case 'c':
        return isBengali ? 'ক' : 'क';
      case 'z':
        return isBengali ? 'জ' : 'ज़';
      default:
        return null;
    }
  }
}
