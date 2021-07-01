// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/license_detection/tokenizer.dart';
import 'package:test/scaffolding.dart';
import 'package:test/test.dart';

void main() {
  group('Tokenizer tests', () {
    testTokenizer('Ignore pure punctuations',
        text: '// hello! ^& world %^& 1.1',
        expected: ['hello', 'world', '1.1']);

    testTokenizer('Ignore puntuations at start of word',
        text: '// !hello @#world -1.1.1',
        expected: ['hello', 'world', '1.1.1']);

    testTokenizer('Ignore puntuation in between a textual world',
        text: '// hell@o wo\$%^rld', expected: ['hello', 'world']);

    testTokenizer('Allow only hiphens and dots if token starts with digit',
        text: 'H.E.L.L.O W.O.R.L.D 1!.2#-3',
        expected: ['hello', 'world', '1.2-3']);

    testTokenizer('Ignore List Items',
        text: '// 1) hello world.\n   vii. This is a text vii.',
        expected: ['hello', 'world', 'this', 'is', 'a', 'text', 'vii']);

    // Tokenize at space or new line.
    testTokenizer('Basic tokenization',
        text: 'hello    world\r\n take some\n tokens',
        expected: ['hello', 'world', 'take', 'some', 'tokens']);
  });
}

void testTokenizer(String name,
    {required String text, required List<String> expected}) {
  test(name, () => testOutput(tokenize(text), expected));
}

void testOutput(List<Token> actual, List<String> expected) {
  expect(actual.length, expected.length);

  for (var i = 0; i < actual.length; i++) {
    expect(actual[i].value, expected[i]);
  }
}
