// ignore_for_file: avoid_print

import 'package:suggester/suggester.dart';
import 'package:suggester/term_mapping.dart';

void main() {
  // A small list of entries. Suggester comfortably handles any number.
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

  // Suggester works by tokenising both suggestions and input using a Term Mapping
  // and finding partial matches between them via prefix searching.
  // For example a TermMapping that groups inputs and suggestions into sequences of
  // letters and numbers:
  print(AlphaOrNumeric().map('Armani.Klein3@veda.io', false, false));

  // {armani, klein, 3, veda, io}

  // TermMapping that groups inputs and suggestions into [NGrams](https://en.wikipedia.org/wiki/N-gram)
  // of size 3, i.e. trigrams.
  print(Ngrams(3).map('Armani.Klein3@veda.io', false, false));

  // {arm, rma, man, ani, ni., i.k, .kl, kle, lei, ein, in3, n3@, 3@v, @ve, ved, eda, da., a.i, .io}

  // Once you decide on a TermMapping construct a Suggester and add suggestions:
  final suggesterAlphaOrNumeric = Suggester(AlphaOrNumeric())..addAll(entries);
  final suggesterTrigram = Suggester(Ngrams(3))..addAll(entries);

  // Find all suggestions featuring search term 'wen', note the difference between tokenisers.
  print(suggesterAlphaOrNumeric.suggest('wen').map((e) => e.entry.value));

  // (Curtis_McGlynn@wendell.me)

  print(suggesterTrigram.suggest('wen').map((e) => e.entry.value));

  // (Rowena.Klein@abdul.us, banjo.berwen@newell.ca, Curtis_McGlynn@wendell.me)

  // You may want to mark the results with the search terms for user feedback:
  // Pass 2 custom functions to be applied to marked and unmarked.
  // Terms can be mapped to any type, here it is mapped to <em> tags but could as well
  // return an iterable of UI elements.
  print(suggesterTrigram.suggest('wen').map((e) => e
      .mapTermsAndNonTerms((term) => '<em>$term</em>', (nonTerm) => nonTerm)
      .join()));

  // ([Ro, <em>wen</em>, a.Klein@abdul.us], [banjo.ber, <em>wen</em>, @newell.ca], [Curtis_McGlynn@, <em>wen</em>, dell.me])

  // An edit distance may also be specified during search allowing terms to be
  // matched using a Hamming edit distance. This extends the range of
  // TermMapping. Using the original AlphaOrNumeric example with a
  // maxEditDistance of 1:
  print(suggesterAlphaOrNumeric
      .suggest('wen', maxEditDistance: 1)
      .map((e) => e.entry.value));

  // (Curtis_McGlynn@wendell.me, Genesis@osvaldo.me)

  // ... and with a maxEditDistance of 2
  for (final suggestion
      in suggesterAlphaOrNumeric.suggest('wen', maxEditDistance: 2)) {
    print(suggestion.entry.value);
  }

  // Curtis_McGlynn@wendell.me
  // Genesis@osvaldo.me
  // Jeff@travon.me
  // Lonny_Gleichner@stanton.co.uk
  // Reanna@flavio.us
  // Reese@dante.io
  // Reynold.Kunde@leif.net
  // banjo.berwen@newell.ca
  // Bill@dejuan.org
  // Fidel@nelle.com
  // Yolanda@bertram.co.uk
  // Emmanuel.Padberg@newell.ca
  // Luciano_Pouros@keenan.ca
  // Rosalia.Koepp@mellie.name
  // Victor_Crist@dina.ca
  // Armani.Klein3@veda.io

  // Once a selection is accepted this can be recorded via the accept method:
  final result = suggesterAlphaOrNumeric.suggest('lu');

  // Note ordering of search suggestions
  print(result.map((final suggestion) => suggestion.entry.value));
  //(Luciano_Pouros@keenan.ca, Lula_Bartoletti@makenzie.org)

  // Accept last suggestion in ordering
  result.last.entry.accept();

  // Last suggestion now becomes first to reflect prior acceptance.
  print(result.map((final suggestion) => suggestion.entry.value));

  // (Lula_Bartoletti@makenzie.org, Luciano_Pouros@keenan.ca)

  // By default when a suggestion is accepted it results in
  // a subScore value incrementing but any int value may speified
  // including a timestamp so that last used suggestions are always favoured.
  // for example:

  result.last.entry.accept(subScore: DateTime.now().millisecondsSinceEpoch);

  print(result.first.entry);

  // {value: Luciano_Pouros@keenan.ca, subScore: 1609579026000}

  // Iterate through all current entries
  print(suggesterAlphaOrNumeric.entries);

  // Iterate all entries ordered by subScore.
  // Note that the last accepted entry is first with timestamp subScore
  print(suggesterAlphaOrNumeric.entriesBySubScore());

  // [{value: Luciano_Pouros@keenan.ca, subScore: 1609569378812},
  // {value: Lula_Bartoletti@makenzie.org, subScore: 1},
  // {value: Amos@carolina.ca, subScore: 0},
  // {value: Armani.Klein3@veda.io, subScore: 0},
  // {value: Bill@dejuan.org, subScore: 0},
  // {value: Caesar@joana.biz, subScore: 0},
  // {value: Cathrine@shayne.info, subScore: 0},
  // {value: Curtis_McGlynn@wendell.me, subScore: 0},
  // {value: Emmanuel.Padberg@newell.ca, subScore: 0},
  // {value: Eula@shaniya.name, subScore: 0},
  // ...]

  // Suggester is serialisable so suggestions and approval history are easily store
  final json = suggesterAlphaOrNumeric.toJson();

  final rehydrated = Suggester.fromJson(AlphaOrNumeric(), json);

  // ... and rehydrated later
  if (SuggesterEquality().equals(rehydrated, suggesterAlphaOrNumeric)) {
    print('Rehydrated successfully!');
  }

  // Rehydrated successfully!
}
