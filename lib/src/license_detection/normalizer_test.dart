import 'normalizer.dart';
import 'package:test/test.dart';

void main() {
  group('Normalizer tests', () {
    test('Whitespace', () {
      expect(
          Normalizer.normalize(
              'there are\u00A0different\u2003whitespaces\u2006and\nthere are extra    \u2007\u2008 whitespaces'),
          'there are different whitespaces and\nthere are extra whitespaces');
    });

    test('varietal words and punctuation', () {
      expect(
          Normalizer.normalize(
              'analyse ‟licence” and categorise it as ❝license❞ whilst realise⁃license and sub⏤licence are 〝same〞'),
          "analyze 'license' and categorize it as 'license' while realize-license and sublicense are 'same'");
    });

    test('Ommitable text and all combined', () {
      expect(
          Normalizer.normalize(
              '''copyright (c) <year> <owner>. all rights reserved.\n        Previous line might disappear.
  copyright <year> <copyright holder>\n  This One too.
           but this wont,\ncopyright\nas\nall rights reserved\nor may be not.
'''),
          '''\n previous line might disappear.\n\n this one too.\n but this wont,\ncopyright\nas\n
or may be not.
''');
    });
  });
}
