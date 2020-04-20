import 'dart:collection';
import 'package:suggester/suggester.dart';

final RegExp _matchAlphaUnicode = RegExp(r'\p{L}+', unicode: true);
final RegExp _matchAlphaAscii = RegExp(r'[a-zA-Z]+');
final RegExp _matchAlphaAndNumericUnicode =
    RegExp(r'[\p{L}\p{Nl}\p{Nd}]+', unicode: true);
final RegExp _matchAlphaAndNumericAscii =
    RegExp(r'[0-9a-zA-Z]+');
final RegExp _matchAlphaOrNumericUnicode =
    RegExp(r'\p{L}+|[\p{Nl}\p{Nd}]+', unicode: true);
final RegExp _matchAlphaOrNumericAscii = RegExp(r'[0-9]+|[a-zA-Z]+');

final RegExp _matchSeparatorUnicode =
    RegExp(r'[\p{Zl}\p{Zp}\p{Zs}]+', unicode: true);
final RegExp _matchSeparatorAscii = RegExp(r'[\s]+');

String _collapseWhitespace(String str, bool unicode) => str
    .trim()
    .replaceAll(unicode ? _matchSeparatorUnicode : _matchSeparatorAscii, ' ');

/// Match runs of alphanumeric characters seperated by non alphanuermic characters
class Tokens extends TermMapping {
  /// Construct tokens
  Tokens({double decay})
      : super(
            (String str, bool caseSensitive, bool unicode) =>
                LinkedHashSet<String>.from((caseSensitive
                        ? str
                        : str.toLowerCase())
                    .split(
                        unicode ? _matchSeparatorUnicode : _matchSeparatorAscii)
                    .where((final term) => term.isNotEmpty)),
            decay ?? 0.1);
}

/// Each term represents a run of Letters
class Alpha extends TermMapping {
  /// Construct tokens
  Alpha({double decay})
      : super(
            (String str, bool caseSensitive, bool unicode) =>
                LinkedHashSet<String>.from(
                    (unicode ? _matchAlphaUnicode : _matchAlphaAscii)
                        .allMatches(caseSensitive ? str : str.toLowerCase())
                        .map((m) => m[0])),
            decay ?? 0.1);
}

/// Each term represents a run of Letters and Numbers
class AlphaAndNumeric extends TermMapping {
  /// Construct tokens
  AlphaAndNumeric({double decay})
      : super(
            (String str, bool caseSensitive, bool unicode) =>
                LinkedHashSet<String>.from((unicode?_matchAlphaAndNumericUnicode:_matchAlphaAndNumericAscii)
                    .allMatches(caseSensitive ? str : str.toLowerCase())
                    .map((m) => m[0])),
            decay ?? 0.1);
}

/// Each term represents a run of Letters or Numbers
class AlphaOrNumeric extends TermMapping {
  /// Construct tokens
  AlphaOrNumeric({double decay})
      : super(
            (String str, bool caseSensitive, bool unicode) =>
                LinkedHashSet<String>.from((unicode
                        ? _matchAlphaOrNumericUnicode
                        : _matchAlphaOrNumericAscii)
                    .allMatches(caseSensitive ? str : str.toLowerCase())
                    .map((m) => m[0])),
            decay ?? 0.1);
}

/// Create ngrams of specified size and padding character
class Ngrams extends TermMapping {
  /// Construct [Ngrams] with gram size.
  Ngrams(int n, {double decay, bool padStart, bool padEnd, String padChar})
      : super((String str, bool caseSensitive, bool unicode) {
          padStart = padStart ?? false;
          padEnd = padEnd ?? false;
          padChar = padChar ?? '\u00A0';
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
        }, decay ?? 0.1);

/*
  /// Remove padding from [term] where:
  /// * [termIdx] is index of term in sequence.
  /// * [termCount] is length of terms sequence.
  String _unpad(String term, int termIdx, int termCount) {
    final start = padStart && (termIdx < n - 1) ? (n - termIdx - 1) : 0;
    final end = padEnd && (termIdx > (termCount - n))
        ? (term.length - (n - (termCount - termIdx)))
        : term.length;

    return term.substring(start, end);
  }
*/

}
