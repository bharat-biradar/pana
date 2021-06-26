import 'package:pana/src/license_detection/tokenizer.dart';
import 'package:pana/src/license_detection/license.dart';

// WIP: Returns a list of detected licenses whose
// confidence score is above a certain threshold.
List<DetectedLicense> detectLicense(String text) {
  // Load corpus licenses.
  final licenses = loadLicenses();
  print(licenses.length);
  final tokens = tokenize(text);
  final checksums = generateChecksums(tokens);
  final table = generateFrequencyTable(tokens);
  final unknownLicense = UnknownLicense(text, tokens, table, checksums);

  licenses.forEach((license) {
    if (unknownLicense.tokenSimilarity(license.frequencyTable) > 0.5) {
      print(license.licenseName);
    }
  });

  return <DetectedLicense>[];
}

// void main() {
//   final text = '''Copyright (C) YEAR by AUTHOR EMAIL

// Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.

// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
// ''';
//   detectLicense(text);
// }
