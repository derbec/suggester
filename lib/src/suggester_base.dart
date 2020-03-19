import 'dart:collection';
import 'dart:math';

import 'package:suggester/src/term_mappings.dart';
import 'package:ternarytreap/ternarytreap.dart';
import 'package:meta/meta.dart';

/// A suggestion
@immutable
class Suggestion implements Comparable<Suggestion> {
  /// Construct a new [Suggestion]
  Suggestion._(this.value, this._tp);

  /// The original suggestion string supplied by client.
  final String value;

  /// Term Proximality of this [Suggestion] instance in [value]
  final double _tp;

  @override
  bool operator ==(final dynamic other) =>
      identical(this, other) || value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  int compareTo(Suggestion other) => value.compareTo(other.value);
}

/// Suggests text completions.
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
  Suggester(this.termMapping,
      {this.caseInsensitive = true, this.unicode = true})
      : _ternaryTreap = TernaryTreapSet<Suggestion>();

  /// Specify case sensitivity of [termMapping].
  final bool caseInsensitive;

  /// Specify if [termMapping] uses unicode or ascii RegExp.
  final bool unicode;

  /// The [TermMapping] used to convert suggestions to a list of keys.
  final TermMapping termMapping;

  final TernaryTreapSet<Suggestion> _ternaryTreap;

  int _length = 0;

  /// Numnber of suggestions currently available
  int get length => _length;

  /// Add [term] for to the list of possible suggestions
  ///
  /// If [term] is null or empty then throws [ArgumentError].
  ///
  /// If [term] cannot be mapped to at least 1 key via specified [TermMapping]
  /// then it is not added and return value is false.
  ///
  /// If [term] is successfully added then return value is true.
  bool add(String term) {
    if (term == null) {
      throw ArgumentError.notNull('term');
    }
    if (term.isEmpty) {
      throw ArgumentError.value(term);
    }
    // Transform term into list of keys and map them to term
    final keys = termMapping.map(term, caseInsensitive, unicode);

    // Unable to add this term
    if (keys.isEmpty) {
      return false;
    }

    var termIdx = 0;
    for (var key in keys) {
      final suggestionKey = Suggestion._(term, _tpFromTermIdx(termIdx));

      // Add new or retrieve current suggestion.
      _ternaryTreap.lookup(key, suggestionKey) ??
          _ternaryTreap.add(key, suggestionKey);

      termIdx++;
    }

    _length++;
    return true;
  }

  /// Add [name] for to the list of possible suggestions
  ///
  /// Equivilent to [add] for all [terms].
  ///
  /// Throws
  void addAll(Iterable<String> terms) {
    for (final term in terms) {
      if (!add(term)) {
        throw ArgumentError.value(term, 'terms', 'Failed to add term');
      }
    }
  }

  /// Return approximate size of [Suggester] instance in memory
  int sizeOf() {
    const SIZE_OF_INT = 4;
    // Get all unique suggestions strings and find total size
    final uniqueSuggestions = _ternaryTreap.values.toSet();
    var suggestionStringBytes = 0;
    for (final suggestion in uniqueSuggestions) {
      suggestionStringBytes += suggestion.value.codeUnits.length*SIZE_OF_INT;
    }

    // Add to size of underlying TernaryTreap calculated with size
    // of suggestion._tp field.
    return suggestionStringBytes + _ternaryTreap.sizeOf(SIZE_OF_INT);
  }

  /// Return list of suggestions based upon [str].
  /// Ordered descending by weight and then ascending by term.
  Iterable<Suggestion> suggest(String str) {
    final keys = termMapping.map(str, caseInsensitive, unicode);

    if (keys.isEmpty) {
      return Iterable<Suggestion>.empty();
    }

    final suggestionWeights = HashMap<Suggestion, double>();

    for (final key in keys) {
      final tpKey = 1;
      final keySuggestions = _ternaryTreap.entriesByKeyPrefix(key);

      for (final keySuggestion in keySuggestions) {
        final values = keySuggestion.value;
        if (values.isEmpty) {
          throw Error();
        }
        final idf = log(length / values.length);
        for (final suggestion in values) {
          final currentWeight = suggestionWeights[suggestion];
          final weightUpdate = tpKey * suggestion._tp * idf;
          if (currentWeight == null) {
            suggestionWeights[suggestion] = weightUpdate;
          } else {
            suggestionWeights[suggestion] = currentWeight + weightUpdate;
          }
        }
      }
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

double _tpFromTermIdx(int termIdx) => (1 / (termIdx + 1));
