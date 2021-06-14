import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'crc32.dart';

void main() {
  final file = File('./lib/src/license_detection/crc32_random.json');
  var z = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  /// The random vectors were generate using this python code and then
  /// verified with [GO crc32 package][]
  /// ```python
  /// import zlib
  /// import json
  /// import string
  /// import random
  /// f = open('crc.json', 'w')
  /// jsonJ = {}
  /// for i in range(1000):
  ///     z = i % 20
  ///     if z < 1:
  ///         z = 1
  ///     res = ''.join(random.choices(string.printable, k=z))
  ///     crc = zlib.crc32(bytes(res, 'utf8'))
  ///     jsonJ[res] = crc
  /// json.dump(jsonJ, f)
  /// ```
  /// [GO crc32 package] : https://golang.org/pkg/hash/crc32/
  group('crc32 - random vectors', () {
    z.forEach((key, value) {
      test(key, () {
        expect(crc32(utf8.encode(key)), value);
      });
    });
  });

  final allAscii = File('./lib/src/license_detection/crc32_ascii_values.json');
  z = jsonDecode(allAscii.readAsStringSync()) as Map<String, dynamic>;

  group('All ascii value ', () {
    z.forEach((key, value) {
      test('Ascii value $key', () {
        expect(crc32([int.parse(key)]), value);
      });
    });
  });
}
