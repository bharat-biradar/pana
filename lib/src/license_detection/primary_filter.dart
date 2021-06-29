import 'package:pana/src/license_detection/license.dart';

/// Filters the corpus licenses and
/// returns a list of [License] which might
/// be a possible match.
List<License> filter(Map<String, int> occurences, List<License> knownLicenses) {
  var possibleLicenses = <License>[];

  knownLicenses.forEach((license) {
    if (tokenSimilarity(occurences, license.occurences) >= 0.5) {
      possibleLicenses.add(license);
    }
  });

  return List.unmodifiable(possibleLicenses);
}

/// Returns a measure for token similarity, indicating if [License] is plausibly present as a
/// substring in [input], as determined by frequency tables over tokens given in [input] and
/// [knownLicense]
// Checks if the unknown text contains enough occurences
// of tokens in a known license to qualify it as a possible match.
// It there are less number of a particular token in input as compared to known license
// there is a low probablity that it might match and hence we do not count it, on the other
// hand if there are more or equal number we count that token
// and finally return the result (number of qualified unique tokens)/(total number of unique tokens in known license).
double tokenSimilarity(Map<String, int> input, Map<String, int> knownLicense) {
  var matches = 0;

  input.keys.forEach((key) {
    if (knownLicense.containsKey(key) && (input[key]! >= knownLicense[key]!)) {
      matches++;
    }
  });

  return matches / input.keys.length;
}
