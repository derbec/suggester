import 'dart:convert';
import 'package:suggester/suggester.dart';
import 'package:suggester/term_mapping.dart';
import 'package:test/test.dart';
import 'emails.dart';

void main() {
  group('Suggester: ', () {
    setUp(() {});

    test('KeysMapping: Text', () {
      // Check term proximality calculated correctly
      final tokens = Tokens();

      expect([0, 1, 2, 9, 6, 7, 3].map((e) => tokens.tpFromTermIdx(e)), [
        1.0,
        0.9,
        0.81,
        0.3874204890000001,
        0.531441,
        0.4782969000000001,
        0.7290000000000001
      ]);

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

      var markedTerms = suggestion.mapByTerms<String>(
          (final term) => '<strong>' + term + '</strong>',
          (final term) => term);

      expect(
          markedTerms,
          equals([
            '<strong>Derek</strong>',
            '_Ba',
            '<strong>rto</strong>',
            'n@jar',
            '<strong>vis</strong>',
            '.com'
          ]));

      suggester = Suggester(Ngrams(3, padStart: true, padEnd: true));
      suggester.add('Derek_Barton@jarvis.com');

      terms = suggester.mapTerms('o rt derek ere vis');

      suggestion = suggester.suggestFromTerms(terms).first;

      markedTerms = suggestion.mapByTerms<String>(
          (final term) => '<strong>' + term + '</strong>',
          (final term) => term);

      expect(
          markedTerms,
          equals([
            '<strong>Derek</strong>',
            '_Ba',
            '<strong>rto</strong>',
            'n@jar',
            '<strong>vis</strong>',
            '.com'
          ]));
    });

    test('json', () {
      final suggester1 = Suggester(Alpha());
      suggester1.add('Banjo_Barton@hotmail.com');
      suggester1.add('Tilly_Smith@jarvis.com');
      suggester1.add('Derek_Barton@jarvis.com');

      final encoded = jsonEncode(suggester1.toJson());

      final suggester2 = Suggester.fromJson(Alpha(), jsonDecode(encoded));

      expect(SuggesterEquality().equals(suggester1, suggester2), equals(true));
    });

    test('SuggesterEquality', () {
      final suggester1 = Suggester(Alpha());
      suggester1.add('Banjo_Barton@hotmail.com');
      suggester1.add('Tilly_Smith@jarvis.com');
      suggester1.add('Derek_Barton@jarvis.com');
      suggester1.add('Tilly_Smith@jarvis.com');

      final suggester2 = Suggester(Alpha());
      suggester2.add('Tilly_Smith@jarvis.com');
      suggester2.add('Derek_Barton@jarvis.com');
      suggester2.add('Tilly_Smith@jarvis.com');
      suggester2.add('Banjo_Barton@hotmail.com');

      expect(SuggesterEquality().equals(suggester1, suggester2), equals(true));

      suggester1.suggest('Derek').first.entry.accept();

      expect(SuggesterEquality().equals(suggester1, suggester2), equals(false));
    });
  });
}
