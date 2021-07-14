import 'package:meta/meta.dart';
import 'package:pana/src/license_detection/license.dart';

/// Instance of [Trigram](s) match in input text and a known license.
@sealed
class MatchRange {
  /// Index of first matched known license token in range.
  int srcStart;

  /// Index of last matched known license token in range.
  int srcEnd;

  /// Index of first matched input token in range.
  int inpStart;

  /// Index of the last matched input token in range.
  int inpEnd;

  /// Number of tokens matched in this range.
  int tokenCount;

  MatchRange(
      this.srcStart, this.srcEnd, this.inpStart, this.inpEnd, this.tokenCount);
}

/// Returns a list of [MatchRange] for [input] that might be the best possible match for [source].
List<MatchRange> findPotentialMatches(PossibleLicense input,
    PossibleLicense source, double confidence, int granularity) {
  final matchedRanges = getMatchRanges(input, source, confidence, granularity);
  final threshold = (confidence * input.license.tokens.length).toInt();

  for (var i = 0; i < matchedRanges.length; i++) {
    if (matchedRanges[i].tokenCount < threshold) {
      return List.unmodifiable(matchedRanges.sublist(0, i));
    }
  }

  return List.unmodifiable(matchedRanges);
}

@visibleForTesting
List<MatchRange> getMatchRanges(PossibleLicense input, PossibleLicense source,
    double confidence, int granularity) {
  final matches = getTargetMatchedRanges(source, input, granularity);

  if (matches.isEmpty) {
    return [];
  }

  final runs = detectRuns(matches, input, source, confidence, granularity);

  if (runs.isEmpty) {
    return [];
  }

  return fuseMatchedRanges(source.license.content, matches, confidence,
      source.license.tokens.length, runs, input.license.tokens.length);
}

/// Returns a list of [MatchRange] for all the continuous range of [Trigram](s) matched in [input] and [source].
@visibleForTesting
List<MatchRange> getTargetMatchedRanges(
    PossibleLicense source, PossibleLicense input, int granularity) {
  var offsetMap = <int, List<MatchRange>>{};
  var matches = <MatchRange>[];

  for (var tgtChecksum in input.checksums) {
    var srcChecksums = source.checksumMap[tgtChecksum.crc32];

    // Check if source contains the checksum.
    if (srcChecksums == null) {
      continue;
    }
    // Iterate over all the trigrams in source having the same checksums.
    for (var srcChecksum in srcChecksums) {
      final offset = tgtChecksum.start - srcChecksum.start;

      // Check if this source checksum extend the last match
      // and update the last match for this offset accordingly.
      if (offsetMap.containsKey(offset) &&
          (offsetMap[offset]!.last.inpEnd == tgtChecksum.end - 1)) {
        offsetMap[offset]!.last.srcEnd = srcChecksum.end;
        offsetMap[offset]!.last.inpEnd = tgtChecksum.end;
        continue;
      }

      // Add new instance of matchRange if doesn't extend the last
      // match of the same offset.
      offsetMap.putIfAbsent(offset, () => []).add(MatchRange(srcChecksum.start,
          srcChecksum.end, tgtChecksum.start, tgtChecksum.end, granularity));
    }
  }

  for (var list in offsetMap.values) {
    // Update the token count of match range.
    for (var match in list) {
      match.tokenCount = match.inpEnd - match.inpStart;
    }
    matches.addAll(list);
  }

  // Sort the matches based on the number of tokens covered in match
  // range in descending order.
  matches.sort(_sortOnTokenCount);
  return List.unmodifiable(matches);
}

/// Returns list of [MatchRange] for all the clusters of ordered [Trigram] in [input] that might be a potential match to the [source].
///
/// For a sequence of N tokens to be considered a potential match,
/// it should have atleast (N * [confidenceThreshold]) number of tokens
/// that appear in atleast in one matching [Trigram].
@visibleForTesting
List<MatchRange> detectRuns(List<MatchRange> matches, PossibleLicense input,
    PossibleLicense source, double confidenceThreshold, int granularity) {
  final inputTokensCount = input.license.tokens.length;
  final licenseTokenCount = source.license.tokens.length;

  // Set the subset length to smaller of the number of input tokens
  // or number of source tokens.
  //
  // If the input has lesser number of tokens than the source
  // i.e target doesn't has atleast one subset of source
  // we decrease the subset length to number of tokens in the
  // input and analyze what we have.
  final subsetLength = inputTokensCount < licenseTokenCount
      ? inputTokensCount
      : licenseTokenCount;

  // Minimum number of tokens that must match in a window of subsetLength
  // to consider it a possible match.
  final targetTokens = (confidenceThreshold * subsetLength).toInt();
  var hits = List<bool>.filled(inputTokensCount, false);

  for (var match in matches) {
    for (var i = match.inpStart; i < match.inpEnd; i++) {
      hits[i] = true;
    }
  }

  // Initialize the total number of matches for the first window
  // i.e [0,subsetLength).
  var totalMatches =
      hits.sublist(0, subsetLength).where((element) => element).length;

  var out = <int>[];
  if (totalMatches >= targetTokens) {
    out.add(0);
  }

  // Slide the window to right and keep on updating the number
  // of hits. If the total number of hits is greater than
  // the confidence threshold add it to the output list.
  for (var i = 1; i < inputTokensCount; i++) {
    // Check if the start of the last window was a
    // hit and decrease the total count.
    if (hits[i - 1]) {
      totalMatches--;
    }

    final end = i + subsetLength - 1;

    if (end < inputTokensCount && hits[end]) {
      totalMatches++;
    }

    if (totalMatches >= targetTokens) {
      out.add(i);
    }
  }

  if (out.isEmpty) {
    return [];
  }

  var finalOut = <MatchRange>[
    MatchRange(out[0], out[0] + granularity, 0, 0, 0),
  ];

  // Create a list of matchRange from the token indexes that were
  // were considered to be a potential match.
  for (var i = 1; i < out.length; i++) {
    if (out[i] != 1 + out[i - 1]) {
      finalOut.add(MatchRange(0, 0, out[i], out[i] + granularity, 0));
    } else {
      finalOut.last.inpEnd = out[i] + granularity;
    }
  }

  return List.unmodifiable(finalOut);
}

/// Fuse
@visibleForTesting
List<MatchRange> fuseMatchedRanges(String licenseText, List<MatchRange> matches,
    double confidence, int size, List<MatchRange> runs, int targetSize) {
  var claimed = <MatchRange>[];
  final errorMargin = (size * (1 - confidence)).round();

  var filter = List.filled(targetSize, false);

  for (var match in runs) {
    for (var i = match.inpStart; i < match.inpEnd; i++) {
      filter[i] = true;
    }
  }

  for (var match in matches) {
    var offset = match.inpStart - match.srcStart;

    if (offset < 0) {
      if (-offset <= errorMargin) {
        offset = 0;
      } else {
        continue;
      }
    }

    // If filter is false this implies that there were not enough instances of
    // match in this range, so this is a spurious hit and is discarded.
    if (!filter[offset]) {
      continue;
    }

    var unclaimed = true;

    final matchOffset = match.inpStart - match.srcStart;
    for (var claim in claimed) {
      var claimOffset = claim.inpStart - claim.srcStart;

      var sampleError = (matchOffset - claimOffset).abs();
      final withinError = sampleError < errorMargin;

      // The offset error
      if (withinError && (match.tokenCount > sampleError)) {
        // Check if this match lies within the claim, if does just update the number
        // of token count.
        if (match.inpStart >= claim.inpEnd && match.inpEnd <= claim.inpEnd) {
          claim.tokenCount += match.tokenCount;
          unclaimed = false;
        }
        // Check if the claim and match can be merged.
        else {
          // Match is within error margin and claim is likely to
          // be an extension of match. So we update the input and
          // source start offsets of claim.
          if (match.inpStart < claim.inpStart &&
              match.srcStart < claim.srcStart) {
            claim.inpStart = match.inpStart;
            claim.srcStart = match.srcStart;
            claim.tokenCount += match.tokenCount;
            unclaimed = false;
          }
          // Match is within error margin and match is likely to
          // to extend claim. So we update the input and source
          // end offsets of claim.
          else if (match.inpEnd > claim.inpEnd && match.srcEnd > claim.srcEnd) {
            claim.inpEnd = match.inpEnd;
            claim.srcEnd = match.srcEnd;
            claim.tokenCount += match.tokenCount;
            unclaimed = false;
          }
        }

        // The match does not extend any existing claims, and
        // can be added as a new claim.
      }

      if (!unclaimed) {
        break;
      }
    }

    // Add as a new claim if it is relevant and has higher quality of
    // hits.
    if (unclaimed && match.tokenCount * 10 > matches[0].tokenCount) {
      claimed.add(match);
    }
  }

  claimed.sort(_sortOnTokenCount);

  return claimed;
}

/// [Comparator] to sort list of [MatchRange] in descending order of their token count.
int _sortOnTokenCount(MatchRange matchA, MatchRange matchB) =>
    (matchA.tokenCount > matchB.tokenCount ? -1 : 1);

// void main() {
//   // var target = 'a b c k d e f';
//   // var source = 'a b c d e f';
//   final a = License.parse('a', source);
//   final b = License.parse('b', target);

//   final src = PossibleLicense.parse(a);
//   final tgt = PossibleLicense.parse(b);

//   final matches = getTargetMatchedRanges(src, tgt, 3);
//   matches.forEach((element) {
//     print(
//         'start: ${element.inpStart} end: ${element.inpEnd} src_start: ${element.srcStart} src_end: ${element.srcEnd} claimed:${element.tokenCount}');
//   });
//   var runs = detectRuns(matches, tgt, src, 0.75, 3);
//   print('Runs');
//   runs.forEach((element) {
//     print(
//         'start: ${element.inpStart} end: ${element.inpEnd} src_start: ${element.srcStart} src_end: ${element.srcEnd} claimed:${element.tokenCount}');
//   });
// }

// var target = '''
//  * Redistribution and use in source and binary forms, with or without
//  * modification, are permitted provided that the following conditions
//  * are met:
//  * 1. Redistributions of source code must retain the above copyright
//  *    notice, this list of conditions and the following disclaimer.
//  * 2. Redistributions in binary form must reproduce the above copyright
//  *    notice, this list of conditions and the following disclaimer in the
//  *    documentation and/or other materials provided with the distribution.
//  * 3. Neither the name of the copyright holders nor the names of its
//  *    contributors may be used to endorse or promote products derived from
//  *    this software without specific prior written permission.
//  *
//  * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
//  * THE POSSIBILITY OF SUCH DAMAGE.
//  */''';

// var source = '''
//  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

//  1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

//  2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

//  3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//  ''';
