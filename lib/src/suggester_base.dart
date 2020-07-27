import 'dart:collection';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:ternarytreap/ternarytreap.dart';

const _JSONKEY_ENTRIES = 'suggestions';
const _JSONKEY_TERMMAPPING = 'termmapping';
const _JSONKEY_CASESENSITIVE = 'casesensitive';
const _JSONKEY_ENTRY_VALUE = 0;
const _JSONKEY_ENTRY_SECONDARY = 1;

/// Maps from an entry to a sequence of terms.
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

  /// Cache results of pow operation and build lookup table
  final List<double> _powLookup;

  /// Performs mapping
  final Iterable<String> Function(
      String entry, bool caseSensitive, bool unicode) map;

  /// Weight terms inversely according to their proximality.
  /// Exponential decay of [termIdx] ensures that proximal terms
  /// are heavily weighted compared to distal.
  ///
  /// A higher decay factor causes faster decay of term proximality.
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
      _powLookup.length = termIdx + 1;
    }

    if (_powLookup[termIdx] == null) {
      _powLookup[termIdx] = pow(1 - termDecay, termIdx).toDouble();
    }

    return _powLookup[termIdx];
  }
}

/// Equality over [Suggester] instances.
class SuggesterEquality implements Equality<Suggester> {
  final _hasher = ListEquality<dynamic>();
  @override
  bool equals(Suggester e1, Suggester e2) {
    if (e1.caseSensitive != e2.caseSensitive ||
        e1.unicode != e2.unicode ||
        e1.entries.length != e2.entries.length ||
        e1.termMapping.toString() != e2.termMapping.toString()) {
      return false;
    }

    for (final e1Entry in e1._entries.values) {
      final e2Entry = e2._entries[e1Entry.value];

      if (e2Entry == null) {
        return false;
      }
      if (e2Entry.value != e1Entry.value ||
          e2Entry.secondaryValue != e1Entry.secondaryValue) {
        return false;
      }
    }
    return true;
  }

  @override
  int hash(Suggester e) =>
      _hasher.hash([e.caseSensitive, e.unicode, ...e._entries.values]);

  @override
  bool isValidKey(Object o) => o is Suggester;
}

/// Represents a single suggestion
class Suggestion {
  /// Construct a [Suggestion].
  Suggestion._(
      {@required this.entry,
      @required this.searchTerms,
      @required this.caseSensitive}) {
    ArgumentError.checkNotNull(entry);
  }

  /// Construct a [Suggestion] from [entry]
  Suggestion.fromEntry(Entry entry)
      : this._(
            entry: entry,
            searchTerms: Iterable<String>.empty(),
            caseSensitive: false);

  /// [Entry] referenced by this [Suggestion].
  final Entry entry;

  /// The terms that led to this suggestion
  final Iterable<String> searchTerms;

  /// True if search was case sensitive, false otherwise.
  final bool caseSensitive;

  /// Split [value] by first occurance of each term in [searchTerms].
  Iterable<T> mapByTerms<T>(
      T Function(String term) mapTerm, T Function(String nonTerm) mapNonTerm) {
    if (searchTerms.isEmpty) {
      return [mapNonTerm(entry.value)];
    }

    final termSrcCase = caseSensitive ? entry.value : entry.value.toLowerCase();

    final termsList = searchTerms
        .map((final term) => (caseSensitive ? term.toLowerCase() : term).trim())
        .toSet()
        .toList();

    // Grow by processing smaller terms first
    // *THIS ORDERING IS NECESSARY FOR CORRECT HIGHLIGHTING OF NGRAM TERMS*
    termsList.sort((a, b) => a.length.compareTo(b.length));

    // Write all term positions to a mask
    final mask = List<bool>.filled(termSrcCase.length, false);

    // If a term is found to be completely occluded by previously processed
    // terms then look for another match.
    for (var term in termsList) {
      // If this term is occluded then keep looking
      var isOccluded = true;
      var termSrcIdx = 0;
      // Search for non occluded instance of term
      while (isOccluded) {
        termSrcIdx = termSrcCase.indexOf(term, termSrcIdx);
        if (termSrcIdx == -1) {
          break;
        }
        // Mask term instance and determine if it is occluded
        for (var termIdx = termSrcIdx;
            termIdx < termSrcIdx + term.length;
            termIdx++) {
          if (!mask[termIdx]) {
            mask[termIdx] = true;
            isOccluded = false;
          }
        }
        termSrcIdx += term.length;
      }
    }

    // Move through mask and build marking
    var termSrcIdx = 0;
    var result = <T>[];

    for (var maskIdx = 0, lastMarkEnd = 0; maskIdx < mask.length;) {
      if (mask[maskIdx]) {
        final skip = maskIdx - lastMarkEnd;
        maskIdx++;
        var length = 1;
        while (maskIdx < mask.length && mask[maskIdx]) {
          maskIdx++;
          length++;
        }

        if (skip > 0) {
          result.add(
              mapNonTerm(entry.value.substring(termSrcIdx, termSrcIdx + skip)));
        }

        termSrcIdx += skip;

        result.add(
            mapTerm(entry.value.substring(termSrcIdx, termSrcIdx + length)));
        termSrcIdx += length;

        lastMarkEnd += skip + length;
      } else {
        maskIdx++;
      }
    }
    if (termSrcIdx < entry.value.length) {
      result.add(mapNonTerm(entry.value.substring(termSrcIdx)));
    }
    return result;
  }
}

/// Represents a single value to be returned as a suggestion.
class Entry {
  /// Construct a new [Entry]
  /// Throws exception if [value] is null or empty.
  Entry._(String value, {int secondaryValue})
      : value = value,
        _secondaryValue = secondaryValue ?? 0 {
    ArgumentError.checkNotNull(value);
    if (value.isEmpty) {
      throw ArgumentError('value.isEmpty');
    }
  }

  /// Construct a new [Entry] from json representing values
  /// to be shared between all instances of [Entry] with same value.
  Entry._fromJson(dynamic json)
      : this._(json[_JSONKEY_ENTRY_VALUE] as String,
            secondaryValue: json[_JSONKEY_ENTRY_SECONDARY] as int);

  /// The original suggestion string supplied by client.
  final String value;

  int _secondaryValue;

  /// Allows differentiation between entries of equal weight.
  int get secondaryValue => _secondaryValue;

  /// Process the event that user has accepted this entry as a suggestion.
  ///
  /// If [secondaryValue] not provided then secondary value incremented by 1
  /// with result that more recently selected entries are given
  /// higher priority.
  void accept({int secondaryValue}) {
    _secondaryValue = secondaryValue ?? _secondaryValue + 1;
  }

  /// Two suggestions are equal if they have the same [value].
  @override
  bool operator ==(final dynamic other) =>
      identical(this, other) || (other is Entry && value == other.value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;

  /// Return json representation of entry
  dynamic _toJson() => [value, secondaryValue];
}

/// A relation between a [Entry] and a term index.
@immutable
class _EntryTermIdx {
  _EntryTermIdx(this.entry, this.termIdx)
      : assert(!identical(termIdx, null)),
        assert(!identical(entry, null));

  /// Term index for [Entry]
  final int termIdx;

  final Entry entry;

  /// Two [_EntryTermIdx] instances are equal if they point to
  /// same [Entry].
  ///
  /// See [Suggester._addEntry] to understand why.
  @override
  bool operator ==(final dynamic other) =>
      identical(this, other) ||
      (other is _EntryTermIdx && entry == other.entry);

  @override
  int get hashCode => entry.hashCode;
}

@immutable
class _TermDistanceEntry {
  _TermDistanceEntry(this.termDistance, this.entryTermIdx)
      : assert(!identical(termDistance, null)),
        assert(!identical(entryTermIdx, null));

  final int termDistance;
  final _EntryTermIdx entryTermIdx;
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
  Suggester._(this.termMapping, this.caseSensitive, this.unicode, this._entries,
      Iterable<Entry> initEntries)
      : _ttMultiMap = TTMultiMapSet<_EntryTermIdx>(),
        entries = UnmodifiableMapView(_entries) {
    ArgumentError.checkNotNull(termMapping);
    ArgumentError.checkNotNull(caseSensitive);
    ArgumentError.checkNotNull(unicode);

    if (!identical(initEntries, null)) {
      for (final suggestion in initEntries) {
        _addEntry(suggestion);
      }
    }
  }

  /// Construct a new [Suggester]
  Suggester(TermMapping termMapping,
      {bool caseSensitive = false, bool unicode = true})
      : this._(termMapping, caseSensitive, unicode, <String, Entry>{}, null);

  /// Construct a new [Suggester] from [json].
  Suggester.fromJson(TermMapping termMapping, dynamic json,
      {bool unicode = true})
      : this._(
            termMapping.runtimeType.toString() == json[_JSONKEY_TERMMAPPING]
                ? termMapping
                : throw ArgumentError.value(json,
                    'Expected termMapping:${termMapping.runtimeType.toString()}, got termMapping:${json[_JSONKEY_TERMMAPPING]}'),
            json[_JSONKEY_CASESENSITIVE] as bool,
            unicode,
            <String, Entry>{},
            (json[_JSONKEY_ENTRIES] as List).map((e) => Entry._fromJson(e)));

  /// Specify case sensitivity of [termMapping].
  final bool caseSensitive;

  /// Specify if [termMapping] uses unicode or ascii RegExp.
  /// Javascript has trouble with Unicode RegExp so set to false if
  /// running in browser.
  final bool unicode;

  /// The [TermMapping] used to convert an entry to a list of terms.
  final TermMapping termMapping;

  /// Store relation from term to entry
  final TTMultiMapSet<_EntryTermIdx> _ttMultiMap;

  /// All current entries
  final UnmodifiableMapView<String, Entry> entries;

  /// All current entries
  final Map<String, Entry> _entries;

  /// Length of longest term yet encountered.
  /// Used to normalise searchTerm length when suggesting.
  int _currentMaxTermLength = 0;

  /// Add [entry] to the set of possible suggestions.
  /// Update [entry.secondaryValue]
  ///
  /// If [entry] is null or empty then throws [ArgumentError].
  ///
  /// If [entry] cannot be mapped to at least 1 key via specified [TermMapping]
  /// then it is not added and return value is false.
  ///
  /// If [entry] is successfully added then return value is true.
  bool _addEntry(Entry entry) {
    _entries[entry.value] = entry;

    // Transform term into list of distinct keys and map them to term
    final terms = mapTerms(entry.value);

    // Unable to add this suggestion
    if (terms.isEmpty) {
      return false;
    }

    var termIdx = 0;
    for (var term in terms) {
      if (term.length > _currentMaxTermLength) {
        _currentMaxTermLength = term.length;
      }
      // Entry should only be associated with each term once
      // This is why [_EntryTermIdx] bases equality testing
      // on it's Suggestion member only.
      if (!_ttMultiMap.add(term, _EntryTermIdx(entry, termIdx))) {
        throw AssertionError('Term mapping returned duplicate term');
      }

      termIdx++;
    }

    return true;
  }

  /// Add [entry] to the set of possible suggestions.
  /// Update [entry.secondaryValue]
  ///
  /// If [entry] is null or empty then throws [ArgumentError].
  ///
  /// If [entry] cannot be mapped to at least 1 key via specified [TermMapping]
  /// then it is not added and return value is false.
  ///
  /// If [entry] is successfully added or already exists then return value is true.
  bool add(String entry, {int secondaryValue = 0}) {
    if (_entries.containsKey(entry)) {
      // we already know this suggestion so just update its secondary value
      if (!identical(secondaryValue, null)) {
        _entries[entry]._secondaryValue = secondaryValue;
      }
      return true;
    }

    return _addEntry(Entry._(entry, secondaryValue: secondaryValue));
  }

  /// Equivilent to [add] for all [entries].
  ///
  /// Throws [ArgumentError] if [add] fails for an entry.
  void addAll(Iterable<String> entries) => entries.forEach((final suggestion) {
        if (!add(suggestion)) {
          throw ArgumentError.value(
              suggestion, 'entries', 'Failed to add entry');
        }
      });

  /// Use supplied [TermMapping] to map [str] to a pairwise
  /// distinct sequence of terms.
  Iterable<String> mapTerms(String entry) {
    ArgumentError.checkNotNull(entry, 'suggestion');
    if (entry.isEmpty) {
      return Iterable<String>.empty();
    }

    final terms = termMapping.map(entry, caseSensitive, unicode);

    return terms;
  }

  /// Return approximate size of [Suggester] instance in memory
  int sizeOf() {
    const SIZE_OF_INT = 4;
    // Strings are shared between multiple instances of Entry.
    // Get all unique Entry strings and find total size of strings
    final uniqueEntries = _ttMultiMap.values.toSet();
    var entryStringBytes = 0;
    for (final entryTerm in uniqueEntries) {
      entryStringBytes += entryTerm.entry.value.codeUnits.length * SIZE_OF_INT;
    }

    // Add to size of underlying TernaryTreap accounting for _tp field
    // that is unique to each Suggestion instance.
    return entryStringBytes + _ttMultiMap.sizeOf(SIZE_OF_INT);
  }

  /// Return list of [Suggestion] based upon [searchString].
  ///
  /// see: [suggestFromTerms] for details of operation.
  Iterable<Suggestion> suggest(String searchString,
          {int maxEditDistance = 0}) =>
      suggestFromTerms(mapTerms(searchString),
          maxEditDistance: maxEditDistance);

  /// Return list of [Suggestion] based upon [searchTerms] aquired from
  /// a [TermMapping].
  ///
  /// Suggestions are ordered descending by weight and then
  /// lexicographically ascending by suggestion.
  ///
  /// [Entry] weight is summation of the products of the following
  /// fuctions for each search term and matched suggestion term.
  ///
  /// * term_proximality(searchTerm) - Rapid decay to emphasise proximal terms.
  /// * term_proximality(suggestionTerm)
  /// * term_length(searchTerm, suggestionTerm) - Linear. Longer search terms typically
  /// carry more confidence, i.e. sheepdog > dog. This is reduced by edit_distance.
  /// Normalised against length of longest term yet encountered.
  /// * inverse_document_frequency(suggestionTerm) - Sub linear.
  ///
  /// The relative growth/decay rates of each function determine overall result ordering:
  ///
  /// term_proximality &#8811; edit_distance &#8811; inverse_document_frequency
  ///
  /// If [predictFirstTerm] is true then [Suggester] will search for a previously promoted
  /// Suggestion prefixed by [searchTerms][0].
  Iterable<Suggestion> suggestFromTerms(Iterable<String> searchTerms,
      {int maxEditDistance = 0}) {
    ArgumentError.checkNotNull(searchTerms, 'searchTerms');
    ArgumentError.checkNotNull(maxEditDistance, 'maxEditDistance');

    if (maxEditDistance < 0) {
      throw ArgumentError.value(maxEditDistance, 'maxEditDistance < 0');
    }

    if (entries.isEmpty) {
      return Iterable<Suggestion>.empty();
    }

    if (searchTerms.isEmpty) {
      return Iterable<Suggestion>.empty();
    }

    final entryWeights = HashMap<Entry, double>();

    var termIdx = 0;
    for (final searchTerm in searchTerms) {
      final tpTerm = termMapping.tpFromTermIdx(termIdx);
      final termEntries = _ttMultiMap
          .valuesByKeyPrefix(searchTerm, maxPrefixEditDistance: maxEditDistance)
          .iterator;

      // Partial term matching allows entries to occur more than once
      // for a particular search term e.g:
      // 'de' may return {'dead', 'detol'}.
      // The suggestion 'Drinking detol makes you dead' may be returned twice.
      // In this case we need only the occurence with the highest term proximity,
      // in this case 'detol'.
      // Suggestions from terms with a lower edit distance are prioritised
      // over those with a higher edit distance.
      final uniqueTermEntries = <Entry, _TermDistanceEntry>{};

      while (termEntries.moveNext()) {
        final termEntry = termEntries.current;
        final currentBest = uniqueTermEntries[termEntry.entry];

        if (identical(currentBest, null)) {
          uniqueTermEntries[termEntry.entry] =
              _TermDistanceEntry(termEntries.prefixEditDistance, termEntry);
        } else if (termEntries.prefixEditDistance <= currentBest.termDistance &&
            termEntry.termIdx < currentBest.entryTermIdx.termIdx) {
          uniqueTermEntries.remove(termEntry.entry);
          uniqueTermEntries[termEntry.entry] =
              _TermDistanceEntry(termEntries.prefixEditDistance, termEntry);
        }
      }

      // scale by the discriminating power of these partial term matches
      final idf = 1 + log(entries.length / uniqueTermEntries.length);
      for (final entryDistance in uniqueTermEntries.values) {
        final termEntry = entryDistance.entryTermIdx;
        // Longer search terms carry more weight than shorter search terms.
        // Reduce by distance and compare to longest known term.
        final termLengthWeight =
            (searchTerm.length - entryDistance.termDistance) /
                _currentMaxTermLength;

        final weightUpdate = tpTerm *
            termMapping.tpFromTermIdx(termEntry.termIdx) *
            termLengthWeight *
            idf;

        final currentWeight = entryWeights[termEntry.entry];

        if (identical(currentWeight, null)) {
          entryWeights[termEntry.entry] = weightUpdate;
        } else {
          entryWeights[termEntry.entry] = currentWeight + weightUpdate;
        }
      }

      termIdx++;
    }

    final sorted = entryWeights.entries.toList()
      ..sort((final e1, final e2) {
        // Sort first by total weight descending
        var diff = e2.value.compareTo(e1.value);

        // Then by last accepted timestamp descending
        if (diff == 0) {
          diff = e2.key.secondaryValue.compareTo(e1.key.secondaryValue);
        }

        // Then by suggestion string value ascending
        if (diff == 0) {
          diff = e1.key.value.compareTo(e2.key.value);
        }

        return diff;
      });

    return sorted.map((final entry) => Suggestion._(
        entry: entry.key,
        searchTerms: searchTerms,
        caseSensitive: caseSensitive));
  }

  /// Return json encodable object representing this [Suggester]
  Map<String, dynamic> toJson() => <String, dynamic>{
        _JSONKEY_TERMMAPPING: termMapping.runtimeType.toString(),
        _JSONKEY_CASESENSITIVE: caseSensitive,
        _JSONKEY_ENTRIES: _entries.values.map((e) => e._toJson()).toList()
      };
}
