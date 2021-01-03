import 'dart:collection';
import 'package:suggester/suggester.dart';

final RegExp _matchAlphaUnicode = RegExp(r'\p{L}+', unicode: true);
final RegExp _matchAlphaAscii = RegExp(r'[a-zA-Z]+');
final RegExp _matchAlphaAndNumericUnicode =
    RegExp(r'[\p{L}\p{Nl}\p{Nd}]+', unicode: true);
final RegExp _matchAlphaAndNumericAscii = RegExp(r'[0-9a-zA-Z]+');
final RegExp _matchAlphaOrNumericUnicode =
    RegExp(r'\p{L}+|[\p{Nl}\p{Nd}]+', unicode: true);
final RegExp _matchAlphaOrNumericAscii = RegExp(r'[0-9]+|[a-zA-Z]+');

final RegExp _matchSeparatorUnicode =
    RegExp(r'[\p{Zl}\p{Zp}\p{Zs}]+', unicode: true);
final RegExp _matchSeparatorAscii = RegExp(r'[\s]+');

String _collapseWhitespace(String str, bool unicode) => str
    .trim()
    .replaceAll(unicode ? _matchSeparatorUnicode : _matchSeparatorAscii, ' ');

/// Match runs of alphanumeric characters seperated by separators
class Tokens extends TermMapping {
  /// Construct tokens
  ///
  /// see: [TermMapping.termDecay] for explanation of [termDecay] usage.
  Tokens({double termDecay = 0.1})
      : super(
            (String str, bool caseSensitive, bool unicode) =>
                LinkedHashSet<String>.from((caseSensitive
                        ? str
                        : str.toLowerCase())
                    .split(
                        unicode ? _matchSeparatorUnicode : _matchSeparatorAscii)
                    .where((final term) => term.isNotEmpty)),
            termDecay);
}

/// Each term represents a run of Letters
class Alpha extends TermMapping {
  /// Construct Alpha
  ///
  /// see: [TermMapping.termDecay] for explanation of [termDecay] usage.
  Alpha({double termDecay = 0.1})
      : super(
            (String str, bool caseSensitive, bool unicode) =>
                LinkedHashSet<String>.from(
                    (unicode ? _matchAlphaUnicode : _matchAlphaAscii)
                        .allMatches(caseSensitive ? str : str.toLowerCase())
                        .map((m) => m[0])),
            termDecay);
}

/// Each term represents a run of Letters and Numbers
class AlphaAndNumeric extends TermMapping {
  /// Construct AlphaAndNumeric
  ///
  /// see: [TermMapping.termDecay] for explanation of [termDecay] usage.
  AlphaAndNumeric({double termDecay = 0.1})
      : super(
            (String str, bool caseSensitive, bool unicode) =>
                LinkedHashSet<String>.from((unicode
                        ? _matchAlphaAndNumericUnicode
                        : _matchAlphaAndNumericAscii)
                    .allMatches(caseSensitive ? str : str.toLowerCase())
                    .map((m) => m[0])),
            termDecay);
}

/// Each term represents a run of Letters or Numbers
class AlphaOrNumeric extends TermMapping {
  /// Construct tokens
  ///
  /// see: [TermMapping.termDecay] for explanation of [termDecay] usage.
  AlphaOrNumeric({double termDecay = 0.1})
      : super(
            (String str, bool caseSensitive, bool unicode) =>
                LinkedHashSet<String>.from((unicode
                        ? _matchAlphaOrNumericUnicode
                        : _matchAlphaOrNumericAscii)
                    .allMatches(caseSensitive ? str : str.toLowerCase())
                    .map((m) => m[0])),
            termDecay);
}

/// Create ngrams of specified size and padding character
class Ngrams extends TermMapping {
  /// Construct [Ngrams] with gram size.
  ///
  /// see: [TermMapping.termDecay] for explanation of [termDecay] usage.
  Ngrams(int n,
      {double termDecay = 0.1,
      bool padStart = false,
      bool padEnd = false,
      String padChar = '\u00A0'})
      : super((String str, bool caseSensitive, bool unicode) {
          padStart = padStart;
          padEnd = padEnd;
          padChar = padChar;
          final orderedNgrams =
              LinkedHashSet<String>(); // ignore: prefer_collection_literals

          if (!caseSensitive) {
            str = str.toLowerCase();
          }

          str = _collapseWhitespace(str, unicode);

          final strLen = str.length;

          final ngramBuffer = StringBuffer();

          final start = padStart ? -(n - 1) : 0;
          final end = padEnd ? strLen : strLen - (n - 1);

          for (var i = start; i < end; i++) {
            for (var j = 0; j < n; j++) {
              final strIdx = i + j;
              if (strIdx < 0 || strIdx >= strLen) {
                ngramBuffer.write(padChar);
              } else {
                ngramBuffer.write(str[strIdx]);
              }
            }
            orderedNgrams.add(ngramBuffer.toString());
            ngramBuffer.clear();
          }

          return orderedNgrams;
        }, termDecay);
}
