// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:meta/meta.dart';
import 'package:pana/src/license_detection/tokenizer.dart';

@sealed
class License {
  /// Name of the license, is empty in case of unknown license.
  final String licenseName;

  /// Original text from the license file.
  final String content;

  /// Normalized [Token]s created from the original text.
  final List<Token> tokens;

  /// A map of tokens and their count.
  final Map<String, int> occurences;

  License._(this.content, this.tokens, this.occurences, this.licenseName);

  factory License.parse(String licenseName, String content) {
    final tokens = tokenize(content);
    final table = generateFrequencyTable(tokens);
    return License._(content, tokens, table, licenseName);
  }
}

// Commented out as they are not yet needed in this stage of detection.
// class Checksum {
//   /// Text for which the hash value was generated.
//   final String text;

//   /// [Crc-32][1] checksum value generated for text.
//   ///
//   /// [1]: https://en.wikipedia.org/wiki/Cyclic_redundancy_check
//   final int crc32;

//   Checksum(this.text, this.crc32);
// }

/// Contains deatils regarding the results of corpus license match with unknwown text.
@sealed
class LicenseMatch {
  /// Name of the license detected from unknown text.
  final String name;

  /// Tokens that were found in the unknown text that matched to tokens
  /// in any of the corpus license.
  final List<Token> tokens;

  /// Confidence score of the detected license.
  final double confidenceScore;

  /// SPDX license which matched with input.
  final License license;

  LicenseMatch(this.name, this.tokens, this.confidenceScore, this.license);
}

/// Genearates a frequency table for the give list of tokens.
@visibleForTesting
Map<String, int> generateFrequencyTable(List<Token> tokens) {
  var map = <String, int>{};

  for (var token in tokens) {
    if (map.containsKey(token.value)) {
      map[token.value] = map[token.value]! + 1;
    } else {
      map[token.value] = 1;
    }
  }

  return map;
}

/// Creates [License] instances for all the corpus licenses.
List<License> loadLicensesFromDirectories(List<String> directories) {
  var licenses = <License>[];
  final length = directories.length;

  for (var i = 0; i < length; i++) {
    final dir = Directory(directories[i]);

    dir.listSync(recursive: false).forEach((element) {
      final license = getLicense(element.path);
      licenses.addAll(license);
    });
  }

  return List.unmodifiable(licenses);
}

/// Returns [License] instance for the given license file.
@visibleForTesting
List<License> getLicense(String path) {
  var licenses = <License>[];
  final file = File(path);

  final fileName = file.uri.toString();
  if (!fileName.endsWith('.txt')) {
    return <License>[];
  }

  final name = file.uri.pathSegments.last.split('.txt').first;
  final content = file.readAsStringSync();
  licenses.add(License.parse(name, content));

  // If a license contains a optional part create and additional license
  // instance with the optional part of text removed to have
  // better chances of matching.
  if (_endOfTerms.hasMatch(content)) {
    final modifiedContent =
        content.replaceAll(_endOfTerms, 'END OF TERMS AND CONDITIONS');
    licenses.add(License.parse('${name}_NOEND', modifiedContent));
  }
  return licenses;
}

// /// Generates crc-32 value for the given list of tokens
// /// by taking 3 token values at a time.
// List<Checksum> generateChecksums(List<Token> tokens) {
//   final length = tokens.length - 2;
//   var checksums = <Checksum>[];

//   for (var i = 0; i < length; i++) {
//     final text =
//         '${tokens[i].value}${tokens[i + 1].value}${tokens[i + 2].value}';
//     final crcValue = crc32(utf8.encode(text));

//     checksums.add(Checksum(text, crcValue));
//   }

//   return checksums;
// }

/// Regex to match the all the text starting from `END OF TERMS AND CONDTIONS`.
final _endOfTerms =
    RegExp(r'END OF TERMS AND CONDITIONS[\s\S]*', caseSensitive: false);
