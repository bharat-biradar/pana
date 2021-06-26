import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:pana/src/license_detection/crc32.dart';
import 'package:pana/src/license_detection/tokenizer.dart';

@sealed
class License {
  /// Name of the license.
  final String licenseName;

  /// Original text from the license file.
  final String text;

  /// Normalized [Token]s created from the original text.
  final List<Token> tokens;

  /// A Hashmap of tokens and their count.
  final HashMap<String, int> frequencyTable;

  /// List of [Crc-32][1] checksum values generated for tokens.
  ///
  /// [1]: https://en.wikipedia.org/wiki/Cyclic_redundancy_check
  final List<Checksum> checksums;

  License(this.text, this.tokens, this.frequencyTable, this.licenseName,
      this.checksums);
}

class Checksum {
  /// Text for which the hash value was generated.
  final String text;

  /// [Crc-32][1] checksum value generated for text.
  ///
  /// [1]: https://en.wikipedia.org/wiki/Cyclic_redundancy_check
  final int crc32;

  Checksum(this.text, this.crc32);
}

class UnknownLicense {
  final String text;
  final List<Token> tokens;
  final HashMap<String, int> frequencyTable;

  /// List of [Crc-32][1] checksum values generated for tokens.
  ///
  /// [1]: https://en.wikipedia.org/wiki/Cyclic_redundancy_check
  final List<Checksum> checksums;

  UnknownLicense(this.text, this.tokens, this.frequencyTable, this.checksums);

  /// Returns confidence score of token similarity between
  /// unknown text and corpus license license according
  /// to [LicenseClassifier][1] metrics.
  ///
  /// [1]: https://github.com/google/licenseclassifier/blob/bb04aff29e72e636ba260ec61150c6e15f111d7e/v2/frequencies.go#L41
  double tokenSimilarity(HashMap<String, int> licenseTokens) {
    var matches = 0;

    frequencyTable.keys.forEach((key) {
      if (licenseTokens.containsKey(key) &&
          (frequencyTable[key]! >= licenseTokens[key]!)) {
        matches++;
      }
    });
    return matches / frequencyTable.keys.length;
  }
}

class DetectedLicense {
  /// Name of the license detected from unknown text.
  final String name;

  /// Tokens that were found in the unknown text that matched to tokens
  /// in any of the corpus license.
  final List<Token> tokens;

  /// Confidence score of the detected license.
  final double confidenceScore;

  DetectedLicense(this.name, this.tokens, this.confidenceScore);
}

/// Genearates a frequency table for the give list of tokens.
HashMap<String, int> generateFrequencyTable(List<Token> tokens) {
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
  var dir = Directory('lib/src/license_detection/licenses/licenses');

  dir.listSync(recursive: false).forEach((element) {
    final license = _getLicense(element.path);
    licenses.add(license);
  });
  dir = Directory('lib/src/license_detection/licenses/licenses_NOEND');

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
  final tokens = tokenize(content);
  final table = generateFrequencyTable(tokens);
  final checksums = generateChecksums(tokens);

  return License(content, tokens, table, name, checksums);
}

final _nameRegex = RegExp(r'lib/.*[/\\]');

/// Generates crc-32 value for the given list of tokens
/// by taking 3 token values at a time.
List<Checksum> generateChecksums(List<Token> tokens) {
  final length = tokens.length - 2;
  var checksums = <Checksum>[];

  for (var i = 0; i < length; i++) {
    final text =
        '${tokens[i].value}${tokens[i + 1].value}${tokens[i + 2].value}';
    final crcValue = crc32(utf8.encode(text));

    checksums.add(Checksum(text, crcValue));
  }

  return checksums;
}
