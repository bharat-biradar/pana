import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:pana/src/license_detection/tokenizer.dart';

@sealed
class License {
  final String originalText;
  final List<Token> tokens;
  final HashMap<String, int> frequencyTable;

  License(this.originalText, this.tokens, this.frequencyTable);
}

HashMap<String, int> genereateFrequencyTable(List<Token> tokens) {
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

double tokenSimilarity(
    HashMap<String, int> unknownText, HashMap<String, int> licenseTokens) {
  var matches = 0;

  unknownText.keys.forEach((key) {
    if (unknownText[key]! >= licenseTokens[key]!) {
      matches++;
    }
  });
  return matches / unknownText.keys.length;
}
