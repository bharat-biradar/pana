// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/license_detection/license.dart';
import 'package:pana/src/license_detection/tokenizer.dart';

import 'package:test/scaffolding.dart';
import 'package:test/test.dart';

void main() {
  test('Test frequency table', () {
    final text = 'some text to t-o generate table ta%^&*ble';
    var expected = <String, int>{
      'some': 1,
      'text': 1,
      'to': 2,
      'generate': 1,
      'table': 2,
    };
    final actual = generateFrequencyTable(tokenize(text));

    actual.forEach((key, value) {
      expect(value, expected[key]);
    });
  });

  test('Load licenses from directory', () {
    final licenses =
        loadLicensesFromDirectories(['test/license_test_assets/licenses']);
    const licenseNames = [
      'agpl_v3',
      'agpl_v3_NOEND',
      'apache_v2',
      'apache_v2_NOEND',
      'bsd_2_clause',
      'bsd_2_clause_in_comments',
      'bsd_3_clause'
    ];

    expect(licenses.length, 7);

    for (var i = 0; i < 7; i++) {
      expect(licenses[i].licenseName, licenseNames[i]);
    }
  });

  test('Test checksum generation', () {
    final text = 'generate some checksums for these tokens';
    final expected = [3898316725, 3188174184, 1984569744, 820879958];
    final actual = generateChecksums(tokenize(text), 3);

    expect(actual.length, expected.length);

    for (var i = 0; i < actual.length; i++) {
      print(
          'Text: ${actual[i].text} start: ${actual[i].start} end: ${actual[i].end}');
      expect(actual[i].crc32, expected[i]);
    }
  });
}
