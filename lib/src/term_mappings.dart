import 'dart:collection';

final RegExp _matchAlphaUnicode = RegExp(r'\p{L}+', unicode: true);
final RegExp _matchAlphaAscii = RegExp(r'[a-zA-Z]+');
final RegExp _matchAlphaAndNumeric =
    RegExp(r'[\p{L}\p{Nl}\p{Nd}]+', unicode: true);
final RegExp _matchAlphaOrNumericUnicode =
    RegExp(r'\p{L}+|[\p{Nl}\p{Nd}]+', unicode: true);
final RegExp _matchAlphaOrNumericAscii = RegExp(r'[0-9]+|[a-zA-Z]+');

final RegExp _matchSeparatorUnicode =
    RegExp(r'[\p{Zl}\p{Zp}\p{Zs}]+', unicode: true);
final RegExp _matchSeparatorAscii = RegExp(r'[\s]+');

String _collapseWhitespace(String str, bool unicode) => str
    .trim()
    .replaceAll(unicode ? _matchSeparatorUnicode : _matchSeparatorAscii, ' ');

/// Maps from [suggestion] to a sequence of terms.
///
/// <i>f</i> :  <i>S</i> &twoheadrightarrow; <i>S</i><sup>&#8469;</sup>
///
/// such that
///
/// * <i>S</i> is the set of all non empty Strings
/// * &#8469; is the set of Natural numbers
/// * <i>S</i><sup>&#8469;</sup> is the set of all functions &#8469; &mapsto; <i>S</i>
///
/// The sequence of terms is pairwise distinct, i.e. a term can occur only once
/// in the returned sequence.
///
/// The term order relects the order of characters in [suggestion].
class TermMapping {
  /// Construct [TermMapping] with specified [map] function
  TermMapping(this.map);

  /// Performs mapping
  final Iterable<String> Function(
      String suggestion, bool caseSensitive, bool unicode) map;
}

/// Match runs of alphanumeric characters seperated by non alphanuermic characters
class Tokens extends TermMapping {
  /// Construct tokens
  Tokens()
      : super((String str, bool caseSensitive, bool unicode) =>
            LinkedHashSet<String>.from((caseSensitive ? str : str.toLowerCase())
                .split(_matchSeparatorUnicode)));
}

/// Each term represents a run of Letters
class Alpha extends TermMapping {
  /// Construct tokens
  Alpha()
      : super((String str, bool caseSensitive, bool unicode) =>
            LinkedHashSet<String>.from(
                (unicode ? _matchAlphaUnicode : _matchAlphaAscii)
                    .allMatches(caseSensitive ? str : str.toLowerCase())
                    .map((m) => m[0])));
}

/// Each term represents a run of Letters and Numbers
class AlphaAndNumeric extends TermMapping {
  /// Construct tokens
  AlphaAndNumeric()
      : super((String str, bool caseSensitive, bool unicode) =>
            LinkedHashSet<String>.from(_matchAlphaAndNumeric
                .allMatches(caseSensitive ? str : str.toLowerCase())
                .map((m) => m[0])));
}

/// Each term represents a run of Letters or Numbers
class AlphaOrNumeric extends TermMapping {
  /// Construct tokens
  AlphaOrNumeric()
      : super((String str, bool caseSensitive, bool unicode) =>
            LinkedHashSet<String>.from((unicode
                    ? _matchAlphaOrNumericUnicode
                    : _matchAlphaOrNumericAscii)
                .allMatches(caseSensitive ? str : str.toLowerCase())
                .map((m) => m[0])));
}

/// Create ngrams of specified size and padding character
class Ngrams extends TermMapping {
  /// Construct [Ngrams] with gram size.
  Ngrams(this.n, {this.pad = false, this.padChar = '\u00A0'})
      : super((String str, bool caseSensitive, bool unicode) {
          final orderedNgrams =
              LinkedHashSet<String>(); // ignore: prefer_collection_literals

          if (!caseSensitive) {
            str = str.toLowerCase();
          }

          str = _collapseWhitespace(str, unicode);

          final strLen = str.length;

          final ngramBuffer = StringBuffer();

          if (pad) {
            for (var i = -(n - 1); i < strLen; i++) {
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
          } else {
            for (var i = 0; i < strLen - (n-1); i++) {
              for (var j = 0; j < n; j++) {
                ngramBuffer.write(str[i + j]);
              }
              orderedNgrams.add(ngramBuffer.toString());
              ngramBuffer.clear();
            }
          }

          return orderedNgrams;
        });

  /// Size of each ngram
  final int n;

  /// If true then padding is applied at start and end of string.
  final bool pad;

  /// Padding character
  final String padChar;
}
