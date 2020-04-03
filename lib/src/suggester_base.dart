import 'dart:collection';
import 'dart:math';

import 'package:meta/meta.dart';

import 'package:ternarytreap/ternarytreap.dart';

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
///
abstract class TermMapping {
  /// Construct [TermMapping] with specified [map] function.
  ///
  /// Specify [termDecay] constant to control strength of term proximality effect:
  /// * Term proximality is exponentially inversely proportional to term position.
  /// * [termDecay]
  /// * [termDecay] must be greater than 0 and less than 1.
  TermMapping(this.map, this.termDecay) : _powLookup = [1] {
    if (termDecay <= 0 || termDecay >= 1) {
      throw ArgumentError.value(termDecay, 'Decay must be > 0 and < 1');
    }
  }

  /// Exponential decay value for term proximality calculation.
  final double termDecay;

  /// Cache results of expensive pow operation
  final List<double> _powLookup;

  /// Performs mapping
  final Iterable<String> Function(
      String suggestion, bool caseSensitive, bool unicode) map;

  /// Weight terms inversely according to their proximality.
  /// Exponential decay of [termIdx] ensures that proximal terms
  /// are heavily weighted compared to distal.
  ///
  /// A higher decay factor
  ///
  /// ```
  ///   1 +--------------------------------------------------------------------+
  ///     |#**     +        +         +        +        +        +        +    |
  /// 0.9 |#+****                                           Decay: 0.1 *******-|
  ///     |$    ***                                         Decay: 0.5 ####### |
  /// 0.8 |$+      **                                       Decay: 0.9 $$$$$$$-|
  ///     |$#        ****                                                      |
  /// 0.7 |$+#           ***                                                 +-|
  ///     |$ #             ****                                                |
  /// 0.6 |$+#                 ****                                          +-|
  ///     |$  #                   *****                                        |
  /// 0.5 |$+  #                       ****                                  +-|
  ///     |$    #                          *****                               |
  /// 0.4 |-$   #                               ******                       +-|
  ///     | $    #                                   *******                   |
  /// 0.3 |-+$    #                                        ********          +-|
  ///     |  $     ##                                             **********   |
  /// 0.2 |-+$      ##                                                      ***|
  ///     |  $        ##                                                       |
  /// 0.1 |-+ $$        ####                                                 +-|
  ///     |     $$ +       ########   +        +        +        +        +    |
  ///   0 +--------------------------------------------------------------------+
  ///     0        2        4         6        8        10       12       14
  /// ```
  double tpFromTermIdx(int termIdx) {
    if (termIdx >= _powLookup.length) {
      _powLookup.add(pow(1 - termDecay, termIdx).toDouble());
    }

    // Set y intercept for numerical stability
    return 10 * _powLookup[termIdx];
  }
}

/// A suggestion
@immutable
class Suggestion implements Comparable<Suggestion> {
  /// Construct a new [Suggestion]
  Suggestion._(this.value, this._tp);

  /// The original suggestion string supplied by client.
  final String value;

  /// Term proximality
  final double _tp;

  @override
  bool operator ==(final dynamic other) =>
      identical(this, other) || value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  int compareTo(Suggestion other) => value.compareTo(other.value);

  @override
  String toString() => value;
}

/// Suggests text completions.
///
/// Below is totally wrong: now uses binary TF features to save memory.
/// Tradeoff works because only short strings are stored as suggestions.
///
/// Uses a modified version of "term frequency - inverse document frequency" (tf-idf)
/// weighting to allow ordering not just by relevance but by term order similarity to
/// search sentence.
///
/// Makes the assumption that terms closer to start (more proximal) of both search and
/// suggestion strings are more important than later (more distal) terms.
///
/// tf is replaced by a value "term proximality" (tp) that is inversely proprtional to
/// the distance of the term from the start of suggestion string. Eg:
///
/// Let <i>f</i> : &#8469;<sub>&gt;0</sub> &#8594; <i>K</i> is a pairwise distinct sequence of terms
/// as returned by [TermMapping] such that <i>f(x)</i> = term at index x.
///
/// Then tp is given by <i>g</i> : <i>K</i> &#8594; &#8469; | g(x) = 1/<i>f<sup>-1</sup>(x)</i>
///
/// Final weighting of term <i>t</i> for suggestion <i>s</i> is:
/// <i>tp * log(|S|/|S<sub>t</sub>|)</i> where <i>S<sub>t</sub></i>
/// is the subset of S mapping to t.
///
///
///
/// Operation is as follows:
///
/// 1. A suggestion string is mapped to a sequence of <i>n</i> String keys via [TermMapping].
/// 1.
/// 1. blah
///
class Suggester {
  /// Construct a new [Suggester]
  Suggester(this.termMapping, {this.caseSensitive = false, this.unicode = true})
      : _ternaryTreap = TernaryTreapSet<Suggestion>();

  /// Specify case sensitivity of [termMapping].
  final bool caseSensitive;

  /// Specify if [termMapping] uses unicode or ascii RegExp.
  final bool unicode;

  /// The [TermMapping] used to convert suggestions to a list of terms.
  final TermMapping termMapping;

  final TernaryTreapSet<Suggestion> _ternaryTreap;

  /// Numnber of suggestions currently available
  int get length => _length;

  int _length = 0;

  /// Use supplied [TermMapping] to map [str] to a pairwise
  /// distinct sequence of terms.
  ///
  /// If [passThroughIfNoTerms] is true then when no terms are generated original value is
  /// returned modifed only to comply with case sensitivity status. This allows term
  /// mappings that require a minimum number of characters to still provide a search term.
  Iterable<String> mapTerms(String suggestion) {
    if (suggestion == null) {
      throw ArgumentError.notNull('suggestion');
    }
    if (suggestion.isEmpty) {
      return Iterable<String>.empty();
    }

    return termMapping.map(suggestion, caseSensitive, unicode);
  }

  /// Add [suggestion] for to the list of possible suggestions
  ///
  /// If [suggestion] is null or empty then throws [ArgumentError].
  ///
  /// If [suggestion] cannot be mapped to at least 1 key via specified [TermMapping]
  /// then it is not added and return value is false.
  ///
  /// If [suggestion] is successfully added then return value is true.
  bool add(String suggestion) {
    if (suggestion == null) {
      throw ArgumentError.notNull('term');
    }
    if (suggestion.isEmpty) {
      throw ArgumentError.value(suggestion);
    }

    // Transform term into list of distinct keys and map them to term
    final terms = mapTerms(suggestion);

    // Unable to add this term
    if (terms.isEmpty) {
      return false;
    }

    var termIdx = 0;
    for (var term in terms) {
      final suggestionObj =
          Suggestion._(suggestion, termMapping.tpFromTermIdx(termIdx));
      // Add new or retrieve current suggestion.
      _ternaryTreap.lookup(term, suggestionObj) ??
          _ternaryTreap.add(term, suggestionObj);
      termIdx++;
    }

    _length++;
    return true;
  }

  /// Equivilent to [add] for all [suggestions].
  ///
  /// Throws [ArgumentError] if [add] fails.
  void addAll(Iterable<String> suggestions) {
    for (final suggestion in suggestions) {
      if (!add(suggestion)) {
        throw ArgumentError.value(
            suggestion, 'suggestions', 'Failed to add suggestion');
      }
    }
  }

  /// Mark tags
  String markTerms(Iterable<String> terms, Suggestion suggestion,
      String Function(String term) mark) {
    final suggestionValue = suggestion.value;
    final suggestionCase =
        caseSensitive ? suggestionValue : suggestionValue.toLowerCase();

    final termsList = terms.map((final term) => term.trim()).toSet().toList();

    // Grow by processing smaller terms first
    // *THIS ORDERING IS NECESSARY FOR CORRECT HIGHLIGHTING OF NGRAM TERMS*
    termsList.sort((a, b) => a.length.compareTo(b.length));

    // Write all term positions to a mask
    final mask = List<bool>.filled(suggestionCase.length, false);

    // If a term is found to be completely occluded by previously processed
    // terms then look for another match.
    for (var term in termsList) {
      // If this term is occluded then keep looking
      var isOccluded = true;
      var suggestionIdx = 0;
      // Search for non occluded instance of term
      while (isOccluded) {
        suggestionIdx = suggestionCase.indexOf(term, suggestionIdx);
        if (suggestionIdx == -1) {
          break;
        }
        // Mask term instance and determine if it is occluded
        for (var termIdx = suggestionIdx;
            termIdx < suggestionIdx + term.length;
            termIdx++) {
          if (!mask[termIdx]) {
            mask[termIdx] = true;
            isOccluded = false;
          }
        }
        suggestionIdx += term.length;
      }
    }

    // Move through mask and perform marking
    var maskIdx = 0;
    var lastMarkEnd = 0;
    var suggestionIdx = 0;
    var buffer = StringBuffer();

    while (maskIdx < mask.length) {
      if (mask[maskIdx]) {
        final skip = maskIdx - lastMarkEnd;
        maskIdx++;
        var length = 1;
        while (maskIdx < mask.length && mask[maskIdx]) {
          maskIdx++;
          length++;
        }

        buffer.write(
            suggestionValue.substring(suggestionIdx, suggestionIdx + skip));
        suggestionIdx += skip;

        buffer.write(mark(
            suggestionValue.substring(suggestionIdx, suggestionIdx + length)));
        suggestionIdx += length;

        lastMarkEnd += skip + length;
      } else {
        maskIdx++;
      }
    }
    buffer.write(suggestionValue.substring(suggestionIdx));
    return buffer.toString();
  }

  /// Return approximate size of [Suggester] instance in memory
  int sizeOf() {
    const SIZE_OF_INT = 4;
    // Strings are shared between multiple instances of Suggestion.
    // Get all unique suggestions strings and find total size of strings
    final uniqueSuggestions = _ternaryTreap.values.toSet();
    var suggestionStringBytes = 0;
    for (final suggestion in uniqueSuggestions) {
      suggestionStringBytes += suggestion.value.codeUnits.length * SIZE_OF_INT;
    }

    // Add to size of underlying TernaryTreap accounting for _tp field
    // that is unique to each Suggestion instance.
    return suggestionStringBytes + _ternaryTreap.sizeOf(SIZE_OF_INT);
  }

  /// Return list of suggestions based upon [str].
  /// Ordered descending by weight and then ascending by term.
  Iterable<Suggestion> suggest(String str,
          {bool passThroughIfNoTerms = false}) =>
      suggestFromTerms(mapTerms(str));

  /// Return list of suggestions based upon [searchTerms] aquired from
  /// a [TermMapping].
  ///
  /// Suggestions are ordered descending by weight and then
  /// lexicographically ascending by suggestion.
  ///
  /// [Suggestion] weight is summation of the products of the following
  /// fuctions for each search term and matched suggestion term.
  ///
  /// * term_proximality(searchTerm) - Rapid decay to emphasise proximal terms.
  /// * term_proximality(suggestionTerm)
  /// * edit_distance(searchTerm, suggestionTerm) - Linear. Due to partial matching of search terms the set of
  /// suggestionTerms may not equal to the set of searchTerms. We want to
  /// reward those suggestionTerms with greatest similarity to searchTerms.
  /// * inverse_document_frequency(suggestionTerm) - Sub linear.
  ///
  /// The relative growth/decay rates of each function determine overall result ordering:
  ///
  /// term_proximality &#8811; edit_distance &#8811; inverse_document_frequency
  Iterable<Suggestion> suggestFromTerms(Iterable<String> searchTerms) {
    if (searchTerms == null) {
      throw ArgumentError.notNull('terms');
    }

    if (searchTerms.isEmpty) {
      return Iterable<Suggestion>.empty();
    }

    final suggestionWeights = HashMap<Suggestion, double>();

    var termIdx = 0;
    for (final searchTerm in searchTerms) {
      final editDistance = searchTerm.length;
      final tpTerm = termMapping.tpFromTermIdx(termIdx);
      final termSuggestions = _ternaryTreap.entriesByKeyPrefix(searchTerm);

        // Partial term matching allows suggestions to occur more than once
        // for a particular search term e.g: 
        // 'de' may return {'dead', 'detol'}.
        // The suggestion 'Drinking detol makes you dead' may be returned twice.
        // In this case we need only the occurence with the highest term proximity,
        // in this case 'detol'.

      for (final termSuggestion in termSuggestions) {
        final suggestions = termSuggestion.value;
        if (suggestions.isEmpty) {
          throw Error();
        }

        final idf = 1 + log(length / suggestions.length);
        for (final suggestion in suggestions) {
          final currentWeight = suggestionWeights[suggestion];
          final weightUpdate = tpTerm * suggestion._tp * editDistance * idf;

          if (currentWeight == null) {
            suggestionWeights[suggestion] = weightUpdate;
          } else {
            suggestionWeights[suggestion] = currentWeight + weightUpdate;
          }
        }
      }
      termIdx++;
    }

    final entries = suggestionWeights.entries.toList()
      ..sort((final e1, final e2) {
        // Sort first by total weight descending
        var diff = e2.value.compareTo(e1.value);

        // Then by suggestion term order ascending
        if (diff == 0) {
          diff = e1.key.compareTo(e2.key);
        }

        return diff;
      });

    return entries.map((final entry) => entry.key);
  }
}
