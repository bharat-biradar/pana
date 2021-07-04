import 'package:pana/src/license_detection/license.dart';

/// Instance of range of token matches
class MatchRange {
  
  final int srcStart;
  
  int srcEnd;
  
  final int inpStart;
  
  int inpEnd;
  
  int get tokenCount => inpEnd - inpStart;

  MatchRange(this.srcStart, this.srcEnd, this.inpStart, this.inpEnd);
}

List<MatchRange> getMatchedRanges(PossibleLicense source, PossibleLicense input) {
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

      offsetMap
          .putIfAbsent(offset, () => [])
          .add(MatchRange(cSum.start, cSum.end, checksum.start, checksum.end));
    }
  }

  for(var list in offsetMap.values){
    matches.addAll(list);
  }
  matches.sort(_sortComparator);
  return matches;
} 

int _sortComparator(MatchRange matchA,MatchRange matchB)
   => (matchA.inpStart < matchB.inpStart ? -1 : 1);

// void main(){
//   final a = License.parse('a', '''Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.

// 	THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REG''');
//   final b = License.parse('b', 'Permission to use, copy, modify, and/or chaos IS PROVIDED "AS IS" AND THE');

//   final aa = PossibleLicense.parse(a);
//   final bb = PossibleLicense.parse(b);

//   final lis = getMatchedRanges(aa, bb);

//   lis.forEach((element) { 
//     print('start: ${element.inpStart} end: ${element.inpEnd} src_start: ${element.srcStart} src_start: ${element.srcEnd} ');
//   });
// }