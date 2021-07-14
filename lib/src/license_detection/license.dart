// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:pana/src/license_detection/tokenizer.dart';

import 'crc32.dart';

@sealed
class License {
  /// SPDX identifier of the license, is empty in case of unknown license.
  final String identifier;

  /// Original text from the license file.
  final String content;

  /// Normalized [Token]s created from the original text.
  final List<Token> tokens;

  /// Map from [Token.value] to their number of occurrences in this license.
  final Map<String, int> occurrences;

  License._(this.content, this.tokens, this.occurrences, this.identifier);

  factory License.parse(String identifier, String content) {
    final tokens = tokenize(content);
    final table = generateFrequencyTable(tokens);
    return License._(content, tokens, table, identifier);
  }
}

@sealed
class Ngram {
  /// Text for which the hash value was generated.
  final String text;

  /// [Crc-32][1] checksum value generated for text.
  ///
  /// [1]: https://en.wikipedia.org/wiki/Cyclic_redundancy_check
  final int crc32;

  /// Index of the first token in the checskum.
  final int start;

  /// Index of the last token in the checksum.
  final int end;

  int get granularity => text.split(' ').length;

  Ngram(this.text, this.crc32, this.start, this.end);
}

@sealed
class PossibleLicense {
  final License license;

  final List<Ngram> checksums;

  final Map<int, List<Ngram>> checksumMap;

  PossibleLicense._(this.license, this.checksums, this.checksumMap);

  factory PossibleLicense.parse(License license) {
    final checksums = generateChecksums(license.tokens, 3);
    final table = generateChecksumMap(checksums);
    return PossibleLicense._(license, checksums, table);
  }
}

/// Contains details regarding the results of corpus license match with unknown text.
@sealed
class LicenseMatch {
  /// Sequence of tokens from input text that were considered a match for the detected [License].
  final List<Token> tokens;

  /// Confidence score of the detected license.
  final double confidence;

  /// Detected license the input have been found to match with given [confidence].
  final License license;

  LicenseMatch(this.tokens, this.confidence, this.license);
}

/// Generates a frequency table for the given list of [tokens].
///
/// [Token.value] is mapped to the number of occurrences in the license text.
@visibleForTesting
Map<String, int> generateFrequencyTable(List<Token> tokens) {
  var table = <String, int>{};

  for (var token in tokens) {
    table[token.value] = table.putIfAbsent(token.value, () => 0) + 1;
  }

  return table;
}

/// Load a list of [License] from the license files found in [directories].
///
/// The files in [directories] should be plain `.txt` and `utf-8` encoded.
/// In case it is not `utf-8` encoded the file will be skipped.
/// Name of the license file is expected to be in the form of `spdx-identifier.txt`.
/// The [directories] are not searched recursively.
/// Throws [FormatException] if any of the directories contains a file that is not a valid license file.
/// Throws [ArgumentError] in case of a invalid [SPDX identifier][1].
///
/// [1]: https://spdx.dev/ids/
List<License> loadLicensesFromDirectories(Iterable<String> directories) {
  var licenses = <License>[];

  for (var dir in directories) {
    Directory(dir).listSync(recursive: false).forEach((file) {
      if (file.path.endsWith('.txt')) {
        if (_invalidIdentifier
            .hasMatch(file.uri.pathSegments.last.split('.txt').first)) {
          throw ArgumentError(
              'Invalid SPDX identifier: ${file.uri.pathSegments.last}');
        }
        final license = licensesFromFile(file.path);
        licenses.addAll(license);
      } else {
        throw FormatException(
            'Invalid file type:\nExpected: "spdx-identifier" Actual: ${file.uri.pathSegments.last}');
      }
    });
  }

  return List.unmodifiable(licenses);
}

/// Returns a list of [License] from the given license file.
///
/// Returns an empty list in case of bad file encoding.
/// If license text contains the phrase `END OF TERMS AND CONDITIONS`
/// which indicates the presence of optional text, two instances
/// of [License] are returned.
@visibleForTesting
List<License> licensesFromFile(String path) {
  var licenses = <License>[];
  final file = File(path);

  final rawContent = file.readAsBytesSync();

  var content = '';

  try {
    content = utf8.decode(rawContent);
  } on FormatException catch (_, e) {
    print('Format Exception: ${file.uri} \n${e.toString()} ');
    return [];
  }

  final identifier = file.uri.pathSegments.last.split('.txt').first;
  licenses.add(License.parse(identifier, content));

  // If a license contains a optional part create an additional license
  // instance with the optional part of text removed to have
  // better chances of matching.
  if (content.contains(_endOfTerms)) {
    final modifiedContent = content.split(_endOfTerms).first + _endOfTerms;
    licenses.add(License.parse(identifier, modifiedContent));
  }
  return licenses;
}

/// Regex to match the all the text starting from `END OF TERMS AND CONDTIONS`.
const _endOfTerms = 'END OF TERMS AND CONDITIONS';

/// Identifier not following the norms of  [SPDX short identifier][1]
/// is a invalid identifier.
///
/// [1]: https://github.com/spdx/license-list-XML/blob/master/DOCS/license-fields.md#explanation-of-spdx-license-list-fields
final _invalidIdentifier = RegExp(r'[^a-zA-Z\d\.\-]');

/// Generates crc-32 value for the given list of tokens
/// by taking 3 token values at a time.
List<Ngram> generateChecksums(List<Token> tokens, int granularity) {
  if (tokens.length < granularity) {
    final text = tokens.join(' ');
    return [Ngram(text, crc32(utf8.encode(text)), 0, tokens.length - 1)];
  }

  var checksums = <Ngram>[];

  for (var i = 0; i + granularity <= tokens.length; i++) {
    var text = '';
    tokens.sublist(i, i + granularity).forEach((token) {
      text += token.value + ' ';
    });
    final crcValue = crc32(utf8.encode(text));

    checksums.add(Ngram(text, crcValue, i, i + granularity));
  }

  return checksums;
}

Map<int, List<Ngram>> generateChecksumMap(List<Ngram> checksums) {
  var table = <int, List<Ngram>>{};
  for (var checksum in checksums) {
    table.putIfAbsent(checksum.crc32, () => []).add(checksum);
  }

  return table;
}