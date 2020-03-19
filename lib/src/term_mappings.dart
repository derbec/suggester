import 'dart:collection';

import 'package:ternarytreap/ternarytreap.dart';

final RegExp _matchAlpha = RegExp(r'\p{L}+', unicode: true);
final RegExp _matchAlphaNumeric =
    RegExp(r'[\p{L}\p{Nl}\p{Nd}]+', unicode: true);
final RegExp _matchAlphaOrNumericUnicode =
    RegExp(r'\p{L}+|[\p{Nl}\p{Nd}]+', unicode: true);
final RegExp _matchAlphaOrNumericAscii = RegExp(r'[0-9]+|[a-z]+');

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
  final LinkedHashSet<String> Function(
      String suggestion, bool caseInsensitive, bool unicode) map;
}

/// Match runs of alphanumeric characters seperated by non alphanuermic characters
class Tokens extends TermMapping {
  /// Construct tokens
  Tokens()
      : super((String str, bool caseInsensitive, bool unicode) =>
            LinkedHashSet<String>.from(
                (caseInsensitive ? str.toLowerCase() : str)
                    .split(_matchSeparatorUnicode)));
}

/// Each term represents a run of Letters
class Alpha extends TermMapping {
  /// Construct tokens
  Alpha()
      : super((String str, bool caseInsensitive, bool unicode) =>
            LinkedHashSet<String>.from(_matchAlpha
                .allMatches(caseInsensitive ? str.toLowerCase() : str)
                .map((m) => m[0])));
}

/// Each term represents a run of Letters and Numbers
class AlphaAndNumeric extends TermMapping {
  /// Construct tokens
  AlphaAndNumeric()
      : super((String str, bool caseInsensitive, bool unicode) =>
            LinkedHashSet<String>.from(_matchAlphaNumeric
                .allMatches(caseInsensitive ? str.toLowerCase() : str)
                .map((m) => m[0])));
}

/// Each term represents a run of Letters or Numbers
class AlphaOrNumeric extends TermMapping {
  /// Construct tokens
  AlphaOrNumeric()
      : super((String str, bool caseInsensitive, bool unicode) =>
            LinkedHashSet<String>.from((unicode
                    ? _matchAlphaOrNumericUnicode
                    : _matchAlphaOrNumericAscii)
                .allMatches(caseInsensitive ? str.toLowerCase() : str)
                .map((m) => m[0])));
}

/// Create ngrams of specified size and padding character
class Ngrams extends TermMapping {
  /// Construct [Ngrams] with gram size.
  Ngrams(this.n, {this.padChar = '\$'})
      : super((String str, bool caseInsensitive, bool unicode) {
          final orderedNgrams =
              LinkedHashSet<String>(); // ignore: prefer_collection_literals

          if (caseInsensitive) {
            str = str.toLowerCase();
          }

          // Collapse all whitespace
          str = _collapseWhitespace(str, unicode);

          var strLen = str.length;

          final ngramBuffer = StringBuffer();

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

          return orderedNgrams;
        });

  /// Size of each ngram
  final int n;

  /// Padding character
  final String padChar;
}
