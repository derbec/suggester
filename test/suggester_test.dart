import 'package:suggester/src/term_mappings.dart';
import 'package:suggester/suggester.dart';
import 'package:test/test.dart';
import 'emails.dart';

void main() {
  group('Suggester: ', () {
    setUp(() {});

    test('KeysMapping: Text', () {
      expect(Tokens().map('This is a dog named, Banjo.', true, true),
          equals(['this', 'is', 'a', 'dog', 'named,', 'banjo.']));
      expect(
          Tokens().map('This is a dog named, Banjo.',
              false, true),
          equals(['This', 'is', 'a', 'dog', 'named,', 'Banjo.']));

      expect(Alpha().map('This is a dog named, Banjo.', true, true),
          equals(['this', 'is', 'a', 'dog', 'named', 'banjo']));
      expect(Alpha().map('banjo. thedog@gmail..thedog .com gmail', true, true)
      ,    equals(['banjo', 'thedog', 'gmail', 'com']));
      expect(
          AlphaAndNumeric().map(
              'banjo. thedog@gmail..thedog test34 .com gmail', true, true),
          equals(['banjo', 'thedog', 'gmail', 'test34', 'com']));
      expect(
          AlphaOrNumeric().map(
              'ba4nj89o.thedog@g399m ail..thedog34.com*gmail', true, true),
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
          Ngrams(2).map('This is a dog named, Banjo.', true, true),
          equals([
            '\$t',
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
            '.\$'
          ]));

      expect(
          Ngrams(3).map('This is a dog named, Banjo.', true, true),
          equals([
            '\$\$t',
            '\$th',
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
            'o.\$',
            '.\$\$'
          ]));
          
    });

    test('addAll()', () async {
      final suggester = Suggester(Alpha());
      suggester.addAll(emails);
    });

    test('sizeOf', () {
      var sizeofEmails = 0;
      for (final email in emails) {
        sizeofEmails += email.codeUnits.length * 4;
      }
      print(sizeofEmails);

      final suggester = Suggester(AlphaOrNumeric());
      suggester.addAll(emails);
      
      print('Size increase: ' + (suggester.sizeOf()/sizeofEmails).toString());
    });

  });
}
