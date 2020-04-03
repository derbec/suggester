import 'package:suggester/suggester.dart';
import 'package:test/test.dart';
import 'emails.dart';

void main() {
  group('Suggester: ', () {
    setUp(() {});

    test('KeysMapping: Text', () {
      expect(Tokens().map('This is a dog named, Banjo.', false, true),
          equals(['this', 'is', 'a', 'dog', 'named,', 'banjo.']));
      expect(Tokens().map('This is a dog named, Banjo.', true, true),
          equals(['This', 'is', 'a', 'dog', 'named,', 'Banjo.']));

      expect(Alpha().map('This is a dog named, Banjo.', false, true),
          equals(['this', 'is', 'a', 'dog', 'named', 'banjo']));
      expect(Alpha().map('banjo. thedog@gmail..thedog .com gmail', true, true),
          equals(['banjo', 'thedog', 'gmail', 'com']));
      expect(
          AlphaAndNumeric()
              .map('banjo. thedog@gmail..thedog test34 .com gmail', true, true),
          equals(['banjo', 'thedog', 'gmail', 'test34', 'com']));
      expect(
          AlphaOrNumeric()
              .map('ba4nj89o.thedog@g399m ail..thedog34.com*gmail', true, true),
          equals([
            'ba',
            '4',
            'nj',
            '89',
            'o',
            'thedog',
            'g',
            '399',
            'm',
            'ail',
            '34',
            'com',
            'gmail'
          ]));

      expect(
          Ngrams(2, padStart: true, padEnd: true)
              .map('This is a dog named, Banjo.', false, true),
          equals([
            '\u00A0t',
            'th',
            'hi',
            'is',
            's ',
            ' i',
            ' a',
            'a ',
            ' d',
            'do',
            'og',
            'g ',
            ' n',
            'na',
            'am',
            'me',
            'ed',
            'd,',
            ', ',
            ' b',
            'ba',
            'an',
            'nj',
            'jo',
            'o.',
            '.\u00A0'
          ]));

      expect(
          Ngrams(3, padStart: true, padEnd: true)
              .map('This is a dog named, Banjo.', false, true),
          equals([
            '\u00A0\u00A0t',
            '\u00A0th',
            'thi',
            'his',
            'is ',
            's i',
            ' is',
            's a',
            ' a ',
            'a d',
            ' do',
            'dog',
            'og ',
            'g n',
            ' na',
            'nam',
            'ame',
            'med',
            'ed,',
            'd, ',
            ', b',
            ' ba',
            'ban',
            'anj',
            'njo',
            'jo.',
            'o.\u00A0',
            '.\u00A0\u00A0'
          ]));

      expect(
          Ngrams(3, padStart: false, padEnd: true)
              .map('This is a dog named, Banjo.', false, true),
          equals([
            'thi',
            'his',
            'is ',
            's i',
            ' is',
            's a',
            ' a ',
            'a d',
            ' do',
            'dog',
            'og ',
            'g n',
            ' na',
            'nam',
            'ame',
            'med',
            'ed,',
            'd, ',
            ', b',
            ' ba',
            'ban',
            'anj',
            'njo',
            'jo.',
            'o.\u00A0',
            '.\u00A0\u00A0'
          ]));

      expect(
          Ngrams(3, padStart: true, padEnd: false)
              .map('This is a dog named, Banjo.', false, true),
          equals([
            '\u00A0\u00A0t',
            '\u00A0th',
            'thi',
            'his',
            'is ',
            's i',
            ' is',
            's a',
            ' a ',
            'a d',
            ' do',
            'dog',
            'og ',
            'g n',
            ' na',
            'nam',
            'ame',
            'med',
            'ed,',
            'd, ',
            ', b',
            ' ba',
            'ban',
            'anj',
            'njo',
            'jo.',
          ]));

      expect(Ngrams(3).map('dere', false, true), equals(['der', 'ere']));
      expect(Ngrams(2).map('dere', false, true), equals(['de', 'er', 're']));

      expect(
          Ngrams(2, padStart: false, padEnd: false)
              .map('This is a dog named, Banjo.', false, true),
          equals([
            'th',
            'hi',
            'is',
            's ',
            ' i',
            ' a',
            'a ',
            ' d',
            'do',
            'og',
            'g ',
            ' n',
            'na',
            'am',
            'me',
            'ed',
            'd,',
            ', ',
            ' b',
            'ba',
            'an',
            'nj',
            'jo',
            'o.'
          ]));

      expect(
          Ngrams(3).map('This is a dog named, Banjo.', false, true),
          equals([
            'thi',
            'his',
            'is ',
            's i',
            ' is',
            's a',
            ' a ',
            'a d',
            ' do',
            'dog',
            'og ',
            'g n',
            ' na',
            'nam',
            'ame',
            'med',
            'ed,',
            'd, ',
            ', b',
            ' ba',
            'ban',
            'anj',
            'njo',
            'jo.'
          ]));
    });

    test('addAll()', () async {
      final suggester = Suggester(Alpha());
      suggester.addAll(emails);
    });

    test('markKeys', () {
      var suggester = Suggester(Alpha());
      suggester.add('Derek_Barton@jarvis.com');

      var terms = suggester.mapTerms('o rt derek ere vis');

      var suggestion = suggester.suggestFromTerms(terms).first;

      var markTerms =
          suggester.markTerms(terms, suggestion, (final term)=>'<strong>'+term+'</strong>');

      expect(
          markTerms,
          equals(
              '<strong>Derek</strong>_Ba<strong>rto</strong>n@jar<strong>vis</strong>.com'));

      suggester = Suggester(Ngrams(3, padStart: true, padEnd: true));
      suggester.add('Derek_Barton@jarvis.com');

      terms = suggester.mapTerms('o rt derek ere vis');

      suggestion = suggester.suggestFromTerms(terms).first;

      markTerms =
          suggester.markTerms(terms, suggestion, (final term)=>'<strong>'+term+'</strong>');

      expect(
          markTerms,
          equals(
              '<strong>Derek</strong>_Ba<strong>rto</strong>n@jar<strong>vis</strong>.com'));
    });
  });
}
