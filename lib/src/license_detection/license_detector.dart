import 'package:pana/src/license_detection/license.dart';
import 'package:pana/src/license_detection/primary_filter.dart';

// Load corpus licenses.
final licenses = loadLicenses();
// WIP: Returns a list of detected licenses whose
// confidence score is above a certain threshold.
List<Result> detectLicense(String text) {
  final unknownLicense = License.parse('', text);

  final possibleLicenses = filter(unknownLicense.occurences, licenses);
  print(possibleLicenses);

  return <Result>[];
}

// void main() {
//   final text = '''Copyright (C) YEAR by AUTHOR EMAIL

// Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.

// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
// ''';
//   detectLicense(text);
// }
