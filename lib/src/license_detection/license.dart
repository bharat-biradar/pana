import 'dart:collection';
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

class Result {
  /// Name of the license detected from unknown text.
  final String name;

  /// Tokens that were found in the unknown text that matched to tokens
  /// in any of the corpus license.
  final List<Token> tokens;

  /// Confidence score of the detected license.
  final double confidenceScore;

  Result(this.name, this.tokens, this.confidenceScore);
}

/// Genearates a frequency table for the give list of tokens.
Map<String, int> generateFrequencyTable(List<Token> tokens) {
  var map = HashMap<String, int>();

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
List<License> loadLicenses() {
  var licenses = <License>[];
  var dir = Directory('third_party/spdx/licenses');

  dir.listSync(recursive: false).forEach((element) {
    final license = _getLicense(element.path);
    licenses.add(license);
  });
  dir = Directory('third_party/spdx/processed_licenses');

  dir.listSync(recursive: false).forEach((element) {
    licenses.add(_getLicense(element.path));
  });

  return List.unmodifiable(licenses);
}

/// Returns [License] instance for the given license file.
License _getLicense(String path) {
  final file = File(path);

  final name = file.path.replaceAll(_nameRegex, '').split('.txt')[0];
  final content = file.readAsStringSync();

  return License.parse(name, content);
}

final _nameRegex = RegExp(r'lib/.*[/\\]');

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
