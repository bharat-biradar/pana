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

  test('Test token similarity', () {
    var text1 = 'Some tokens to test';
    var text2 = 'some tokens to test';

    var tokens1 = tokenize(text1);

    final license = UnknownLicense(text1, tokens1,
        generateFrequencyTable(tokens1), generateChecksums(tokens1));
    var tokens2 = tokenize(text2);

    expect(license.tokenSimilarity(generateFrequencyTable(tokens2)), 1);

    tokens2 = tokenize('some tokens are different');
    expect(license.tokenSimilarity(generateFrequencyTable(tokens2)), 0.5);

    tokens2 = tokenize('one tokens match');
    expect(license.tokenSimilarity(generateFrequencyTable(tokens2)), 0.25);

    tokens2 = tokenize('');
    expect(license.tokenSimilarity(generateFrequencyTable(tokens2)), 0);
  });

  test('Test checksum generation', () {
    final text = 'generate some checksums for these tokens';
    final expected = [202247124, 3226558818, 1391268045, 1050691930];
    final actual = generateChecksums(tokenize(text));

    expect(actual.length, expected.length);

    for (var i = 0; i < actual.length; i++) {
      expect(actual[i].crc32, expected[i]);
    }
  });
}
