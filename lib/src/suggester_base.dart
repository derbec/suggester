library suggester;

import 'dart:collection';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:ternarytreap/ternarytreap.dart';

const _JSONKEY_ENTRIES = 'a';
const _JSONKEY_TERMMAPPING = 'b';
const _JSONKEY_CASESENSITIVE = 'c';
const _JSONKEY_ENTRY_VALUE = 0;
const _JSONKEY_ENTRY_SECONDARY = 1;

/// (2^53)-1 because javascript
const int _MAX_SAFE_INTEGER = 9007199254740991;

/// Maps from a String to a sequence of terms.
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
/// Suggester works by tokenising both suggestions and input using a Term Mapping
/// and finding partial matches between them via prefix searching.
///
/// For example a TermMapping that groups inputs and suggestions into sequences of
/// letters and numbers:
///
/// ```dart
/// print(AlphaOrNumeric().map('Armani.Klein3@veda.io', false, false));
/// ```
/// ```shell
/// {armani, klein, 3, veda, io}
/// ```
///
/// TermMapping that groups inputs and suggestions into [NGrams](https://en.wikipedia.org/wiki/N-gram)
/// of size 3, i.e. trigrams.
///
/// ```dart
/// print(Ngrams(3).map('Armani.Klein3@veda.io', false, false));
/// ```
///
///```shell
/// {arm, rma, man, ani, ni., i.k, .kl, kle, lei, ein, in3, n3@, 3@v, @ve, ved, eda, da., a.i, .io}
/// ```
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
    // Cannot assume termIdxs are requested sequentially
    while (termIdx >= _powLookup.length) {
      _powLookup.add(pow(1 - termDecay, _powLookup.length).toDouble());
    }

    return _powLookup[termIdx];
  }
}

/// Equality and hashing over [Suggester] instances.
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
          e2Entry.subScore != e1Entry.subScore) {
        return false;
      }
    }
    return true;
  }

  @override
  int hash(Suggester e) =>
      _hasher.hash([e.caseSensitive, e.unicode, ...e._entries.values]);

  @override
  bool isValidKey(Object? o) => o is Suggester;
}

/// Iterate over search result ordering of [Suggestion] instances.
/// The underlying [Suggester] can change between calls to [iterator].
class _SuggestionIterable extends IterableBase<Suggestion> {
  _SuggestionIterable._(this.suggester, this.searchTerms, this.maxEditDistance);

  /// The [Suggester] being iterated
  final Suggester suggester;

  final int maxEditDistance;

  final Iterable<String> searchTerms;

  @override
  Iterator<Suggestion> get iterator =>
      searchTerms.isEmpty || suggester.entries.isEmpty
          ? Iterable<Suggestion>.empty().iterator
          : _SugggestionIterator._(this);
}

/// Iterator for [Suggestion] instances
/// Returns suggestions grouped by edit distance
class _SugggestionIterator implements Iterator<Suggestion> {
  _SugggestionIterator._(this.ownerIterable)
      : validVersion = ownerIterable.suggester._version,
        currentItr = Iterable<Suggestion>.empty().iterator,
        // Set up prefix matching for search terms
        termEntriesItrs = {
          for (final searchTerm in ownerIterable.searchTerms)
            searchTerm: ownerIterable.suggester._ttMultiMap
                .valuesByKeyPrefix(searchTerm,
                    maxPrefixEditDistance: ownerIterable.maxEditDistance)
                .iterator
        },
        entryTermIdxSequence = <Entry, _TermIdxSequence>{};

  /// [Suggester._version] at start of iteration
  final int validVersion;

  /// The [Suggester] being iterated
  final _SuggestionIterable ownerIterable;

  /// Keep track of prefix searching for each search term
  final Map<String, TTIterator<_EntryTermIdx>> termEntriesItrs;

  /// Keep track of last known termIdx sequence for each entry to allow identification
  /// of shared sequential runs of search terms in entries.
  /// Shared sequences between search terms and entries increases similarity.
  final Map<Entry, _TermIdxSequence> entryTermIdxSequence;

  Iterator<Suggestion> currentItr;

  /// Set to -1 so that first increment is 0
  int termEditDistance = -1;

  @override
  Suggestion get current => currentItr.current;

  @override
  bool moveNext() {
    final suggester = ownerIterable.suggester;

    if (suggester._version != validVersion) {
      throw ConcurrentModificationError();
    }

    // First try to advance along current iterator
    if (currentItr.moveNext()) {
      return true;
    }

    // Move to next term edit distance results
    termEditDistance++;

    // Have we passed the client specified max distance?
    if (termEditDistance > ownerIterable.maxEditDistance) {
      return false;
    }

    // set up for next set of edit distance results
    final entryWeights = HashMap<Entry, double>();

    var searchTermIdx = 0;
    for (final searchTerm in ownerIterable.searchTerms) {
      final termEntries = termEntriesItrs[searchTerm]!;

      // Partial term matching allows entries to occur more than once
      // for a particular search term e.g:
      // 'de' may return {'dead', 'detol'}.
      // The suggestion 'Drinking detol makes you dead' may be returned twice.
      // In this case we need only the occurence with the highest term proximity,
      // in this case 'detol'.
      // Suggestions from terms with a lower edit distance are prioritised
      // over those with a higher edit distance.
      final uniqueTermEntries = <Entry, _TermDistanceEntry>{};

      // The previous call advances to the first element of the next edit distance
      // so need to consume this first before calling moveNext this time round.
      var processCurrentValueFirst = termEntries.hasCurrentValue &&
          termEntries.prefixEditDistance == termEditDistance;

      while (processCurrentValueFirst ||
          (termEntries.moveNext() &&
              termEntries.prefixEditDistance <= termEditDistance)) {
        processCurrentValueFirst = false;
        final termEntry = termEntries.current;
        final currentBest = uniqueTermEntries[termEntry.entry];

        if (identical(currentBest, null)) {
          uniqueTermEntries[termEntry.entry] =
              _TermDistanceEntry(termEntries.prefixEditDistance, termEntry);
        } else if (termEntries.prefixEditDistance <= currentBest.termDistance &&
            termEntry.termIdx < currentBest.entryTermIdx.termIdx) {
          uniqueTermEntries[termEntry.entry] =
              _TermDistanceEntry(termEntries.prefixEditDistance, termEntry);
        }
      }

      // Calculate inverse document frequency of current term within all entries.
      final idf = 1 + log(suggester.entries.length / uniqueTermEntries.length);
      for (final entryDistance in uniqueTermEntries.values) {
        final termEntry = entryDistance.entryTermIdx;

        // Update term sequences shared between search terms and entry
        final sharedTermIdxSequence = entryTermIdxSequence.putIfAbsent(
            termEntry.entry, () => _TermIdxSequence(0, 0));

        var termEntryIdx = termEntry.termIdx;

        // Can we extend an existing sequence?
        if (termEntryIdx - 1 == sharedTermIdxSequence.termIdxEnd) {
          sharedTermIdxSequence.termIdxEnd = termEntryIdx;
        } else {
          sharedTermIdxSequence.termIdxStart = termEntryIdx;
          sharedTermIdxSequence.termIdxEnd = termEntryIdx;
        }

        // calculate weight contribution of this search term for entry
        final weightUpdate =
            // Term proximality for current search term
            (suggester.termMapping.tpFromTermIdx(searchTermIdx) *
                    // Term proximality for start of current shared sequence
                    suggester.termMapping
                        .tpFromTermIdx(sharedTermIdxSequence.termIdxStart) *
                    suggester.termProximalityWeighting) +
                // Favour entries that share higher term sequence similarity with
                // search sentance
                ((sharedTermIdxSequence.sequenceLength /
                        ownerIterable.searchTerms.length) *
                    suggester.sharedSequenceLengthWeighting) +
                (idf * suggester.termIdfWeighting);

        final currentWeight = entryWeights[termEntry.entry];

        if (identical(currentWeight, null)) {
          entryWeights[termEntry.entry] = weightUpdate;
        } else {
          entryWeights[termEntry.entry] = currentWeight + weightUpdate;
        }
      }

      searchTermIdx++;
    }

    final sorted = entryWeights.entries.toList()
      ..sort((final e1, final e2) {
        // Sort first by total weight descending
        var diff = e2.value.compareTo(e1.value);

        // Then by last accepted timestamp descending
        if (diff == 0) {
          diff = e2.key.subScore.compareTo(e1.key.subScore);
        }

        // Then by suggestion string value ascending
        if (diff == 0) {
          diff = e1.key.value.compareTo(e2.key.value);
        }

        return diff;
      });

    currentItr = sorted
        .map((final mapEntry) => Suggestion._(
            entry: mapEntry.key,
            score: mapEntry.value,
            searchTerms: ownerIterable.searchTerms,
            caseSensitive: suggester.caseSensitive,
            prefixEditDistance: termEditDistance))
        .iterator;

    if (currentItr.moveNext()) {
      return true;
    }

    // Recursively move to next edit distance
    // Note: This will only go 1 deep worst case
    return moveNext();
  }
}

/// Represents a single match result
class Suggestion {
  /// Construct a [Suggestion].
  Suggestion._(
      {required this.entry,
      required this.score,
      required this.searchTerms,
      required this.caseSensitive,
      required this.prefixEditDistance});

  /// Construct from existing entry
  Suggestion._fromEntry(Entry entry, bool caseSensitive)
      : this._(
            entry: entry,
            score: 0,
            searchTerms: Iterable<String>.empty(),
            caseSensitive: caseSensitive,
            prefixEditDistance: 0);

  /// [Entry] referenced by this [Suggestion].
  final Entry entry;

  /// Recommendation score for this suggestion
  final double score;

  /// The terms that led to this suggestion
  final Iterable<String> searchTerms;

  /// True if search was case sensitive, false otherwise.
  final bool caseSensitive;

  /// The prefix edit distance leading to this suggestion
  final int prefixEditDistance;

  /// Split [entry] by first occurance of each term in [searchTerms].
  /// [mapTerm] and [mapNonTerm] may return any object including string.
  Iterable<T> mapTermsAndNonTerms<T>(
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

  @override
  String toString() =>
      '{entry: ${entry.toString()}, score: $score, searchTerms: $searchTerms,caseSensitive: $caseSensitive,prefixEditDistance: $prefixEditDistance}';
}

/// Represents a single value to be returned as a suggestion.
class Entry {
  /// Construct a new [Entry]
  /// Throws exception if [value] is null or empty.
  Entry._(String value, {int? secondaryValue})
      : value = value,
        _subScore = secondaryValue ?? 0 {
    if (value.isEmpty) {
      throw ArgumentError('value is empty');
    }
  }

  /// Construct a new [Entry] from json representing values
  /// to be shared between all instances of [Entry] with same value.
  Entry._fromJson(dynamic json)
      : this._(json[_JSONKEY_ENTRY_VALUE] as String,
            secondaryValue: json[_JSONKEY_ENTRY_SECONDARY] as int);

  /// The original suggestion string supplied by client.
  final String value;

  int _subScore;

  /// An integer that allows differentiation between entries of equal weight.
  /// By default starts at zero and increments after each [accept] but
  /// could also be a timestamp to allow ordering by latest.
  int get subScore => _subScore;

  /// Process the event that user has accepted this entry as a suggestion.
  ///
  /// If [subScore] not provided then existing [subScore] is incremented by 1.
  void accept({int? subScore}) {
    _subScore = subScore ?? _subScore + 1;
  }

  /// Two Entries are equal if they have the same [value].
  @override
  bool operator ==(final dynamic other) =>
      identical(this, other) || (other is Entry && value == other.value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '{value: $value, subScore: $_subScore}';

  /// Return json representation of entry
  dynamic _toJson() => [value, subScore];
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
  _TermDistanceEntry(this.termDistance, this.entryTermIdx);

  final int termDistance;
  final _EntryTermIdx entryTermIdx;
}

/// Keep track of term index sequences shared between search sentance and entry
class _TermIdxSequence {
  _TermIdxSequence(this.termIdxStart, this.termIdxEnd);

  int termIdxStart;
  int termIdxEnd;

  /// Length of current sequence
  int get sequenceLength => termIdxEnd - termIdxStart + 1;
}

/// Suggests text completions.
///
/// Uses a modified version of [term frequency - inverse document frequency](https://en.wikipedia.org/wiki/Tf%E2%80%93idf)
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
class Suggester {
  Suggester._(
      this.termMapping,
      this.caseSensitive,
      this.unicode,
      this.termIdfWeighting,
      this.termProximalityWeighting,
      this.sharedSequenceLengthWeighting,
      this._entries,
      Iterable<Entry>? initEntries)
      : _ttMultiMap = TTMultiMapSet<_EntryTermIdx>(),
        entries = UnmodifiableMapView(_entries),
        _version = 0 {
    if (!identical(initEntries, null)) {
      for (final suggestion in initEntries) {
        _addEntry(suggestion);
      }
    }
  }

  /// Construct a new [Suggester]
  Suggester(TermMapping termMapping,
      {bool caseSensitive = false,
      bool unicode = true,
      double termIdfWeighting = 1,
      double termProximalityWeighting = 1,
      double sharedSequenceLengthWeighting = 1})
      : this._(
            termMapping,
            caseSensitive,
            unicode,
            termIdfWeighting,
            termProximalityWeighting,
            sharedSequenceLengthWeighting,
            <String, Entry>{},
            null);

  /// Construct a new [Suggester] from [json].
  Suggester.fromJson(TermMapping termMapping, dynamic json,
      {bool unicode = true,
      double termIdfWeighting = 1,
      double termProximalityWeighting = 1,
      double sharedSequenceLengthWeighting = 1})
      : this._(
            termMapping.runtimeType.toString() == json[_JSONKEY_TERMMAPPING]
                ? termMapping
                : throw ArgumentError.value(json,
                    'Expected termMapping:${termMapping.runtimeType.toString()}, got termMapping:${json[_JSONKEY_TERMMAPPING]}'),
            json[_JSONKEY_CASESENSITIVE] as bool,
            unicode,
            termIdfWeighting,
            termProximalityWeighting,
            sharedSequenceLengthWeighting,
            <String, Entry>{},
            (json[_JSONKEY_ENTRIES] as List).map((e) => Entry._fromJson(e)));

  /// Specify case sensitivity of [termMapping].
  final bool caseSensitive;

  /// True if [termMapping] uses unicode RegExp.
  /// Javascript has trouble with Unicode RegExp so set to false if
  /// running in browser.
  final bool unicode;

  /// Term idf contribution to term weighting
  ///
  /// see: [suggestFromTerms]
  final double termIdfWeighting;

  /// Term proximality contribution to term weighting.
  ///
  /// see: [suggestFromTerms]
  final double termProximalityWeighting;

  /// Shared sequence length contribution to term weighting
  ///
  /// see: [suggestFromTerms]
  final double sharedSequenceLengthWeighting;

  /// The [TermMapping] used to convert an entry to a list of terms.
  final TermMapping termMapping;

  /// Store prefix searchable relation from term to entry
  final TTMultiMapSet<_EntryTermIdx> _ttMultiMap;

  /// Unmodifiable view of current entries
  final UnmodifiableMapView<String, Entry> entries;

  /// All current entries
  final Map<String, Entry> _entries;

  /// Track version tofor detection of iterator concurrent modification
  int _version;

  /// Increment keys/structure version
  void _incVersion() {
    _version = (_version >= _MAX_SAFE_INTEGER) ? 1 : _version + 1;
  }

  /// Add [entry] to the set of possible suggestions.
  /// Update [entry.subScore]
  ///
  /// If [entry] cannot be mapped to at least 1 key via specified [TermMapping]
  /// then it is not added and return value is false.
  ///
  /// If [entry] is successfully added then return value is true.
  bool _addEntry(Entry entry) {
    // Transform term into list of distinct keys and map them to term
    final terms = mapTerms(entry.value);

    // Unable to add this suggestion
    if (terms.isEmpty) {
      return false;
    }

    _entries[entry.value] = entry;

    var termIdx = 0;
    for (var term in terms) {
      // Entry should only be associated with each term once
      // This is why [_EntryTermIdx] bases equality testing
      // on it's Suggestion member only.
      if (!_ttMultiMap.add(term, _EntryTermIdx(entry, termIdx))) {
        throw AssertionError('Term mapping returned duplicate term');
      }

      termIdx++;
    }

    _incVersion();

    return true;
  }

  /// Return an iterable over all entries ordered by:
  /// 1) subscore
  /// 2) lexicographically
  Iterable<Entry> entriesBySubScore() => entries.values.toList()
    ..sort((final e1, final e2) {
      // Sort first by subScore descending
      var diff = e2._subScore.compareTo(e1._subScore);

      // Then by suggestion string value ascending
      if (diff == 0) {
        diff = e1.value.compareTo(e2.value);
      }

      return diff;
    });

  /// Add [entryValue] to the set of possible suggestions.
  ///
  /// Optionally update [Entry.subScore] at same time.
  ///
  /// If [entryValue] cannot be mapped to at least 1 key via specified [TermMapping]
  /// then it is not added and return value is false.
  ///
  /// If [entryValue] is successfully added or already exists then return value is true.
  bool add(String entryValue, {int? subScore}) {
    final entry = _entries[entryValue];
    if (identical(entry, null)) {
      return _addEntry(Entry._(entryValue, secondaryValue: subScore));
    }
    // we already know this suggestion so just update its secondary value
    if (!identical(subScore, null)) {
      entry._subScore = subScore;
    }
    return true;
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

  /// Use suggester [TermMapping] to map [entry] to a pairwise
  /// distinct sequence of terms.
  /// If [fallBackToSearchString] is true then [entry] is returned as single
  /// token if [termMapping] generates no tokens
  Iterable<String> mapTerms(String entry,
      {bool fallBackToSearchString = false}) {
    entry = entry.trim();
    if (entry.isEmpty) {
      return Iterable<String>.empty();
    }

    final terms = termMapping.map(entry, caseSensitive, unicode);

    if (fallBackToSearchString && terms.isEmpty) {
      return [caseSensitive ? entry : entry.toLowerCase()];
    }

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

  /// Return [Iterable] of [Suggestion] based upon [searchString].
  ///
  /// [Suggester.termMapping] is applied to [searchString] prior to search.
  ///
  /// see: [suggestFromTerms] for details of operation.
  Iterable<Suggestion> suggest(String searchString,
          {int maxEditDistance = 0}) =>
      suggestFromTerms(mapTerms(searchString, fallBackToSearchString: true),
          maxEditDistance: maxEditDistance);

  /// Return [Iterable] of [Suggestion] based upon [searchTerms] aquired from
  /// a [TermMapping].
  ///
  /// Suggestions are ordered descending by weight and then
  /// lexicographically ascending by suggestion.
  ///
  /// [Entry] weight is summation of the products of the following
  /// fuctions and client specified weighting factors.
  ///
  /// * [TermMapping.tpFromTermIdx] (searchTerm) * [TermMapping.tpFromTermIdx] (suggestionTerm) * [termProximalityWeighting]
  /// * (Ratio of current matching [searchTerms] term sequence length to [Entry] term sequence length) * [sharedSequenceLengthWeighting]
  /// * (Inverse document frequency over all entries (searchTerm)) * [termIdfWeighting]
  ///
  /// The resulting [Iterable] will throw [ConcurrentModificationError] if underlying
  /// [Suggester] changes during iteration. Change between seperate iterations is permitted.
  Iterable<Suggestion> suggestFromTerms(Iterable<String> searchTerms,
      {int maxEditDistance = 0}) {
    if (maxEditDistance < 0) {
      throw ArgumentError.value(maxEditDistance, 'maxEditDistance < 0');
    }

    return _SuggestionIterable._(this, searchTerms, maxEditDistance);
  }

  /// Create suggestion directly from [entryValue].
  ///
  /// Throw [ArgumentError] if [entryValue] does not exist in this suggester.
  Suggestion createSuggestion(String entryValue) {
    final entry = _entries[entryValue];
    if (identical(entry, null)) {
      throw ArgumentError.value(
          entryValue, 'entryValue', 'Value not known to Suggester');
    }
    return Suggestion._fromEntry(entry, caseSensitive);
  }

  /// Return json encodable object representing this [Suggester]
  Map<String, dynamic> toJson() => <String, dynamic>{
        _JSONKEY_TERMMAPPING: termMapping.runtimeType.toString(),
        _JSONKEY_CASESENSITIVE: caseSensitive,
        _JSONKEY_ENTRIES: _entries.values.map((e) => e._toJson()).toList()
      };
}
