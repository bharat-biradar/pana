// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/license_detection/tokenizer.dart';
import 'package:test/scaffolding.dart';
import 'package:test/test.dart';

void main() {
  group('Tokenizer tests', () {
    test('Ignore pure punctuations', () {
      final text = '// hello! ^& world %^& 1.1';
      final expected = <String>['hello', 'world', '1.1'];
      final actual = tokenize(text);

      testOutput(actual, expected);
    });

    test('Ignore puntuations at start of word', () {
      final text = '// !hello @#world -1.1.1';
      final expected = <String>['hello', 'world', '1.1.1'];
      final actual = tokenize(text);

      testOutput(actual, expected);
    });

    test('Ignore puntuation in between a textual world', () {
      final text = '// hell@o wo\$%^rld';
      final expected = ['hello', 'world'];
      final actual = tokenize(text);

      testOutput(actual, expected);
    });

    test('Allow only hiphens and dots if token starts with digit', () {
      final text = 'H.E.L.L.O W.O.R.L.D 1!.2#-3';
      final expected = ['hello', 'world', '1.2-3'];
      final actual = tokenize(text);

      testOutput(actual, expected);
    });

    test('Ignore List Items', () {
      final text = '// 1) hello world.\n   vii. This is a text vii.';
      final expected = ['hello', 'world', 'this', 'is', 'a', 'text', 'vii'];
      final actual = tokenize(text);

      testOutput(actual, expected);
    });

    test('Basic tokenization', () {
      // Tokenize at space or new line
      final text = 'hello    world\r\n take some\n tokens';
      final expected = ['hello', 'world', 'take', 'some', 'tokens'];
      final actual = tokenize(text);

      testOutput(actual, expected);
    });
  });
}

void testOutput(List<Token> actual, List<String> expected) {
  expect(actual.length, expected.length);

  for (var i = 0; i < actual.length; i++) {
    expect(actual[i].value, expected[i]);
  }
}
