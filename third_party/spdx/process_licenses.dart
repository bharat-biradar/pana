import 'dart:core';
import 'dart:io';

/// If a license contains optional `END OF TERMS AND CONDTIONS`
/// it removes all the text under this section except the header
/// and stores it in the [processed_licenses][1] directory as new file.
///
/// [1]: https://github.com/dart-lang/pana/tree/master/third_party/spdx/processed_licenses
void main() {
  var regex =
      RegExp(r'END OF TERMS AND CONDITIONS[\s\S]*', caseSensitive: false);
  final replaceRegex = RegExp(r'third_party/spdx/licenses');
  var dir = Directory('third_party/spdx/licenses');

  dir.list().forEach((element) async {
    final file = File(element.path);
    final content = await file.readAsString();

    if (regex.hasMatch(content)) {
      var path = 'third_party/spdx/processed_licenses' +
          element.path.replaceAll(replaceRegex, '');
      path = path.split('.txt').first;
      path = path + '_NOEND.txt';

      final file = File(path);
      await file.create(recursive: false);
      var text = content.replaceAll(regex, 'END OF TERMS AND CONDITIONS');
      await file.writeAsString(text);
    }
  });
}
