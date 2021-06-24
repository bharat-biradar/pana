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
    final actual = genereateFrequencyTable(tokenizer(text));

    actual.forEach((key, value) {
      expect(value, expected[key]);
    });
  });
}
