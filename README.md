An autocompetion engine for Dart.

Supports highly configurable partial matching.

Fast and memory efficient.

Suitable for both web and mobile devices.

## Test It Live !

<mark>Play with a [Live instance of Suggester](https://derbec.github.io/suggester/).</mark>

Test different combinations of data and parameters tofind what suits your application.

## Usage

### Import

```dart
import 'package:suggester/suggester.dart';
```

### Choose Term Mapping

Suggester works by tokenising both suggestions and input using a Term Mapping and finding partial matches between them via prefix searching.

For example a TermMapping that groups inputs and suggestions into sequences of letters and numbers:

```dart
print(AlphaOrNumeric().map('Armani.Klein3@veda.io', false, false));
```

```shell
{armani, klein, 3, veda, io}
```

TermMapping that groups inputs and suggestions into [NGrams](https://en.wikipedia.org/wiki/N-gram) of size 3, i.e. [Trigrams](https://en.wikipedia.org/wiki/Trigram).


```dart
print(Ngrams(3).map('Armani.Klein3@veda.io', false, false));
```

```shell
{arm, rma, man, ani, ni., i.k, .kl, kle, lei, ein, in3, n3@, 3@v, @ve, ved, eda, da., a.i, .io}
```

### Construct Suggester and Load Entries

A small list of entries. Suggester comfortably handles any number.

```dart
final entries = [
  'Armani.Klein3@veda.io',
  'Tracy@garett.io',
  'Eula@shaniya.name',
  'Reynold.Kunde@leif.net',
  'Reanna@flavio.us',
  'Fidel@nelle.com',
  'Luciano_Pouros@keenan.ca',
  'Curtis_McGlynn@wendell.me',
  'Reese@dante.io',
  'Sallie3@ettie.me',
  'Yolanda@bertram.co.uk',
  'Mariam.Toy@oren.com',
  'Rosalia.Koepp@mellie.name',
  'Rowena.Klein@abdul.us',
  'Jeff@travon.me',
  'Mario_Zulauf@michael.com',
  'Amos@carolina.ca',
  'Lonny_Gleichner@stanton.co.uk',
  'Lula_Bartoletti@makenzie.org',
  'Hardy@marion.ca',
  'Libby_Parker@ursula.biz',
  'banjo.berwen@newell.ca',
  'Genesis@osvaldo.me',
  'Caesar@joana.biz',
  'Cathrine@shayne.info',
  'Bill@dejuan.org',
  'Victor_Crist@dina.ca',
  'Stephany@dillan.io',
  'Emmanuel.Padberg@newell.ca'
];
```

Construct 2 example Suggester objects, each using a different Term Mapping.
Load each with the above list of entries.

```dart
final suggesterAlphaOrNumeric = Suggester(AlphaOrNumeric())
  ..addAll(entries);

final suggesterTrigram = Suggester(Ngrams(3))..addAll(entries);

```

### Suggest!
Find all suggestions featuring search term 'wen', note the difference between TermMappings.

```dart
print(suggesterAlphaOrNumeric.suggest('wen').map((e) => e.entry.value));

```

```shell
(Curtis_McGlynn@wendell.me)

```

```dart
print(suggesterTrigram.suggest('wen').map((e) => e.entry.value));
```

```shell
(Rowena.Klein@abdul.us, banjo.berwen@newell.ca, Curtis_McGlynn@wendell.me)

```

### Mark Suggestion Search Terms

User feedback is helped by marking a suggestion with the search terms.
Pass 2 custom functions to be applied to marked and unmarked terms.
Terms can be mapped to any type, here it is mapped to html tags but could as well return an iterable of UI elements.

```dart
print(suggesterTrigram.suggest('wen').map((e) => e
    .mapTermsAndNonTerms((term) => '<mark>$term</mark>', (nonTerm) => nonTerm)
    .join()));

```

```shell
(Ro<mark>wen</mark>a.Klein@abdul.us, banjo.ber<mark>wen</mark>@newell.ca, Curtis_McGlynn@<mark>wen</mark>dell.me)

```

Ro<mark>wen</mark>a.Klein@abdul.us, banjo.ber<mark>wen</mark>@newell.ca, Curtis_McGlynn@<mark>wen</mark>dell.me

### Expand Search With Edit Distance

An edit distance may also be specified during search allowing terms to be matched using a [Hamming edit distance](https://en.wikipedia.org/wiki/Hamming_distance). This extends the range of a TermMapping. Using the original AlphaOrNumeric example with a maxEditDistance of 1:

```dart
print(suggesterAlphaOrNumeric
    .suggest('wen', maxEditDistance: 1)
    .map((e) => e.entry.value));

```

```shell
(Curtis_McGlynn@wendell.me, Genesis@osvaldo.me)
```

... and with a maxEditDistance of 2

```dart
for (final suggestion
    in suggesterAlphaOrNumeric.suggest('wen', maxEditDistance: 2)) {
  print(suggestion.entry.value);
}

```

```shell
Curtis_McGlynn@wendell.me
Genesis@osvaldo.me
Jeff@travon.me
Lonny_Gleichner@stanton.co.uk
Reanna@flavio.us
Reese@dante.io
Reynold.Kunde@leif.net
banjo.berwen@newell.ca
Bill@dejuan.org
Fidel@nelle.com
Yolanda@bertram.co.uk
Emmanuel.Padberg@newell.ca
Luciano_Pouros@keenan.ca
Rosalia.Koepp@mellie.name
Victor_Crist@dina.ca
Armani.Klein3@veda.io

```

### Accept Suggestions

Once a selection is accepted this can be recorded via the accept method:

```dart
final result = suggesterAlphaOrNumeric.suggest('lu');

print(result.map((final suggestion) => suggestion.entry.value));

```

Note ordering of search suggestions.

```shell
(Luciano_Pouros@keenan.ca, Lula_Bartoletti@makenzie.org)

```

Accept last suggestion in ordering:

```dart
result.last.entry.accept();

print(result.map((final suggestion) => suggestion.entry.value));

```

Last suggestion now becomes first to reflect prior acceptance.

```shell
(Lula_Bartoletti@makenzie.org, Luciano_Pouros@keenan.ca)

```

By default when a suggestion is accepted it results in a subScore value incrementing but any int value may specified including a timestamp so that last used suggestions are always favoured. For example:

```dart
result.last.entry.accept(subScore: DateTime.now().millisecondsSinceEpoch);

print(result.first.entry);

```

```shell
{value: Luciano_Pouros@keenan.ca, subScore: 1609579026000}

```

### Check Current Entries

Iterate through all current entries

```dart
print(suggesterAlphaOrNumeric.entries);
```

Iterate all entries ordered by subScore.
Note that the last accepted entry is first with timestamp subScore.

```dart
print(suggesterAlphaOrNumeric.entriesBySubScore());
```

```shell
[{value: Luciano_Pouros@keenan.ca, subScore: 1609569378812},
  {value: Lula_Bartoletti@makenzie.org, subScore: 1},
  {value: Amos@carolina.ca, subScore: 0},
  {value: Armani.Klein3@veda.io, subScore: 0},
  {value: Bill@dejuan.org, subScore: 0},
  {value: Caesar@joana.biz, subScore: 0},
  {value: Cathrine@shayne.info, subScore: 0},
  {value: Curtis_McGlynn@wendell.me, subScore: 0},
  {value: Emmanuel.Padberg@newell.ca, subScore: 0},
  {value: Eula@shaniya.name, subScore: 0},
  ...]
```

### Serialise
Suggester is serialisable so suggestions and approval history are easily stored and reused.


```dart

final json = suggesterAlphaOrNumeric.toJson();

final rehydrated = Suggester.fromJson(AlphaOrNumeric(), json);

if (SuggesterEquality().equals(rehydrated, suggesterAlphaOrNumeric)) {
  print('Rehydrated successfully!');
}

```

```shell
Rehydrated successfully!

```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/derbec/suggester/issues
