import 'dart:io';

import 'package:suggester/suggester.dart';
import 'emails.dart';

void main(List<String> args) {
  final suggester = Suggester(Ngrams(3, padStart: true, padEnd: true));

  final timer = Stopwatch()..start();

  for (var i = 0; i < 5; i++) {
    suggester.addAll(emails);

    for (final email in emails) {
      suggester.add(String.fromCharCodes(email.codeUnits.reversed));
    }
  }
  timer.stop();
  stdout.writeln('${timer.elapsedMicroseconds}');
}
