import 'package:meta/meta.dart';
import 'package:pana/src/license_detection/license.dart';

/// Instance of range of token matches
@sealed
class MatchRange {
  /// Index of first matched known license token in range.
  final int srcStart;

  /// Index of last matched known license token in range.
  int srcEnd;

  /// Index of first matched input token in range.
  final int inpStart;

  /// Index of the last matched input token in range.
  int inpEnd;

  /// Number of tokens matched in this range.
  int get tokenCount => inpEnd - inpStart + 1;

  MatchRange(this.srcStart, this.srcEnd, this.inpStart, this.inpEnd);
}

@visibleForTesting
List<MatchRange> getTargetMatchedRanges(
    PossibleLicense source, PossibleLicense input) {
  var offsetMap = <int, List<MatchRange>>{};
  var matches = <MatchRange>[];

  for (var checksum in input.checksums) {
    var srcChecksums = source.checksumMap[checksum.crc32];
    if (srcChecksums == null) {
      continue;
    }
    for (var cSum in srcChecksums) {
      final offset = checksum.start - cSum.start;

      if (offsetMap.containsKey(offset) &&
          (offsetMap[offset]!.last.inpEnd == checksum.end - 1)) {
        offsetMap[offset]!.last.srcEnd = cSum.end;
        offsetMap[offset]!.last.inpEnd = checksum.end;
        continue;
      }
      print('add new ${checksum.text}');
      offsetMap
          .putIfAbsent(offset, () => [])
          .add(MatchRange(cSum.start, cSum.end, checksum.start, checksum.end));
    }
  }

  for (var list in offsetMap.values) {
    matches.addAll(list);
  }
  matches.sort(_sortComparator);
  return matches;
}

int _sortComparator(MatchRange matchA, MatchRange matchB) =>
    (matchA.inpStart < matchB.inpStart ? -1 : 1);

@visibleForTesting
List<MatchRange> detectRuns(List<MatchRange> matches, PossibleLicense input,
    PossibleLicense knownLicense, double confidenceThreshold,int granularity) {
  final inputTokensCount = input.license.tokens.length;

  if (inputTokensCount == 0) {
    return [];
  }
  
  final licenseTokenCount = knownLicense.license.tokens.length;
  var subsetLength = licenseTokenCount > inputTokensCount
      ? licenseTokenCount
      : inputTokensCount;

  var hits = List<bool>.filled(inputTokensCount, false);

  for (var match in matches) {
    for (var i = match.inpStart; i <= match.inpEnd; i++) {
      hits[i] = true;
    }
  }

  var totalMatches =
      hits.sublist(0, subsetLength).where((element) => element).length;
  final targetTokens = (confidenceThreshold * licenseTokenCount).toInt();

  var out = <int>[];
  if (totalMatches >= targetTokens) {
    out.add(0);
  }

  for (var i = 0; i < inputTokensCount; i++) {
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
    MatchRange(out[0], out[0] + granularity, 0, 0),
  ];

  for (var i = 1; i < out.length; i++) {
    if (out[i] != 1 + out[i - 1]) {
      finalOut.add(MatchRange(out[i], out[i] + granularity, 0, 0));
    } else {
      finalOut.last.srcEnd = out[i] + granularity;
    }
  }

  return finalOut;
}

void fuseMatchRanges(String licenseText, List<MatchRange> matches,
    double confidence, int size, List<MatchRange> runs, int targetSize) {
      var claimed = <MatchRange>[];
      final errorMargin = (size * (1 - confidence)).round();

      var filter = List.filled(targetSize, false);
      var filterDrops = 0;
      var filterPasses = 0;

      for (var match in matches) {
        for (var i = match.inpStart; i <= match.inpEnd; i++) {
          filter[i] = true;
      }
    }

    for(var match in matches){
      var offset = match.inpStart - match.srcStart;

      if(offset<0){
        if(-offset <= errorMargin){
          offset = 0;
        }else{
          continue;
        }
      }

      if(!filter[offset]){
        filterDrops++;
        continue;
      }

      filterPasses++;

      var unclaimed = true;

      for(var claim in claimed){
        
      }
    }

}
void main(){
  final a = License.parse('a', target);
  final b = License.parse('b', target);

  final aa = PossibleLicense.parse(a);
  final bb = PossibleLicense.parse(b);

  final lis = getTargetMatchedRanges(aa, bb);

  lis.forEach((element) {
    print('start: ${element.inpStart} end: ${element.inpEnd} src_start: ${element.srcStart} src_start: ${element.srcEnd} ');
    print('${a.tokens[element.inpStart].value} ${a.tokens[element.inpStart].index}');
  });
}


var target = '''
***
 * ASM: a very small and fast Java bytecode manipulation framework
 * Copyright (c) 2000-2011 INRIA, France Telecom
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holders nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */''';

 var source = '''Copyright (c) <year> <owner>. All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 ''';