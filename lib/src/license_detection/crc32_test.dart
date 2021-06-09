import 'dart:convert';

import 'package:test/test.dart';

import 'crc32.dart';

void main() {
  group('A group of tests', () {
    test('Crc32 Test 1', () {
      expect(
          calculateCrc(utf8.encode('abcdefghijklmnopqrstuvwxyz')), 1277644989);
    });

    test('Crc32 Test 2', () {
      expect(calculateCrc([48]), 4108050209);
    });

    test('Crc32 Test 3', () {
      expect(
          calculateCrc(
              (utf8.encode('The quick brown fox jumps over the lazy dog'))),
          1095738169);
    });
  });
}
