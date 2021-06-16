import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';

@sealed
class NewToken {
  final String normalizedText;
  final int tokenID;
  final int line;
  final FileSpan fileSpan;

  NewToken(this.normalizedText, this.tokenID, this.line, this.fileSpan);
}

List<NewToken> newTokenizer(String text) {
  // Guideline 3.1.1: All whitespace should be treated as a single blank space.
  text = text.replaceAll(_horizontalWhiteSpaceRegex, ' ');

  // Guideline 5: Equivalent Punctuation marks
  // Replacing punctuations before tokenizing as
  // SpanScanner deals with one UTF-16 codepoint at at a time
  // and dealing with surrogate pairs will be problem.
  // This won't effect either offset, line or column of original text.
  _equivalentPunctuationMarks.forEach((reg, value) {
    text = text.replaceAll(reg, value);
  });

  // Add a space to properly read the last token
  // without having extra if-conditions.
  text = text + ' ';

  final _scanner = SpanScanner(text);

  var tokens = <NewToken>[];
  var tokenID = 0;

  /// Scans through the input text and creates a list of [NewToken]
  /// Whitespace is ignored but newLine token is stored to deal with list Items.
  /// Any Leading or standalone punctuation form a separate token
  /// Example `! !hello!` --> `!`, `!`, `hello!`
  while (!_scanner.isDone) {
    var prevState = _scanner.state;
    var char = _scanner.readChar();

    // Check if the character is alphanumeric,
    // If it is create a span until you reach space or new Line.
    // If not create a span for of the single character.
    // This approach will help us to deal with comment indicators, bullets
    // and list items.
    if (_isAlphaNumeric(char)) {
      while (!_scanner.isDone) {
        char = _scanner.readChar();
        if (_isSpace(char) || char == 10) {
          break;
        }
      }

      // Move the scanner back to exclude space or newLine character
      // from token.
      _scanner.position--;
      _addNewToken(_scanner.spanFrom(prevState), tokenID++, tokens);

      prevState = _scanner.state;
      _scanner.position++;

      if (_isNewLine(char)) {
        _addNewToken(_scanner.spanFrom(prevState), tokenID++, tokens);
      }
    } else if (!_isSpace(char)) {
      _addNewToken(_scanner.spanFrom(prevState), tokenID++, tokens);
    }
  }

  /// Normalizes tokens using the approach of [google licenseClassifier]
  /// to provide better chances of matching.
  /// [google licenseClassifier]: https://github.com/google/licenseclassifier/blob/bb04aff29e72e636ba260ec61150c6e15f111d7e/v2/tokenizer.go#L34
  tokens = _cleanNewTokens(tokens);

  return tokens;
}

void _addNewToken(FileSpan fileSpan, int tokenID, List<NewToken> tokens) {
  final normText = fileSpan.text.toLowerCase();
  final tok = NewToken(normText, tokenID++, fileSpan.start.line, fileSpan);
  tokens.add(tok);
}

List<NewToken> _cleanNewTokens(List<NewToken> tokens) {
  var output = <NewToken>[];
  var tokenID = 0;
  var firstInLine = true;

  for (var token in tokens) {
    // Ignore new line tokens for now.
    // If accuracy of detection is low apply
    // Guideline 2.1.4: Text that can be omited from license.
    if (token.normalizedText == '\n') {
      firstInLine = true;
      continue;
    }

    var char = token.normalizedText.codeUnits.first;

    // Ignores single puntcuations as they are
    // not significant in detection.
    if (!_isAlphaNumeric(char) && token.normalizedText.length == 1) {
      continue;
    }

    // Ignores list items.
    if (firstInLine && _isListItem(token.normalizedText)) {
      continue;
    }

    firstInLine = false;

    final text = _cleanToken(token.normalizedText);

    output.add(NewToken(text, tokenID++, token.line, token.fileSpan));
  }

  return output;
}

/// Normalizes the tokens using the approach of [google licenseClassifier]
/// to provide better chances of matching.
/// [google licenseClassifier]  https://github.com/google/licenseclassifier/blob/bb04aff29e72e636ba260ec61150c6e15f111d7e/v2/tokenizer.go#L85
String _cleanToken(String tok) {
  final runes = tok.runes;
  var buffer = StringBuffer();

  if (!_isLetter(runes.first)) {
    if (_isDigit(runes.first)) {
      runes.forEach((rune) {
        if (_isDigit(rune) || rune == _dot || rune == _hiphen) {
          buffer.write(String.fromCharCode(rune));
        }
      });

      var text = buffer.toString();

      if (text.runes.last == _dot) {
        text = text.substring(0, text.length);
      }

      return text;
    }
  }

  runes.forEach((rune) {
    if (_isLetter(rune)) {
      buffer.write(String.fromCharCode(rune));
    }
  });

  var text = buffer.toString();

  // If this is a varietal word normalize it according to
  // Guideline 8.1.1: Legally equal words must be treated same.
  text = _varietalWords[text] ?? text;
  return text;
}

bool _isListItem(String token) {
  final end = token[token.length - 1];
  final start = token.substring(0, token.length - 1);

  if ((end == '.' || end == ')') && _headers.contains(start)) {
    return true;
  }

  if (_numberHeaderRe.hasMatch(token)) {
    return true;
  }

  return false;
}

bool _isDigit(int rune) {
  return (rune > 47 && rune < 58);
}

bool _isLetter(int rune) {
  return ((rune > 96 && rune < 123) || (rune > 64 && rune < 91));
}

bool _isSpace(int rune) {
  return rune == 32;
}

bool _isAlphaNumeric(int rune) {
  return _isDigit(rune) || _isLetter(rune);
}

bool _isNewLine(int char) {
  switch (char) {
    case 10:
    case 12:
    case 133:
      return true;
  }
  return false;
}

final _headers = HashSet.from(
    'q w e r t y u i o p a s d f g h j k l z x c v b n m i ii iii iv vi vii ix xi xii'
        .split(' '));

final _numberHeaderRe = RegExp(r'^\d{1,2}(\.\d{1,2})*[\.)]$');

final _horizontalWhiteSpaceRegex = RegExp(r'[^\S\r\n]');

final Map<RegExp, String> _equivalentPunctuationMarks = {
  // Guideline 5.1.2: All variants of dashes considered equivalent.
  RegExp(r'[-֊־᠆‐‑–—﹘﹣－‒⁃⁻⎯─⏤]'): '-',

  // Guideline Guideline 5.1.3: All variants of quotations considered equivalent.
  RegExp(r'[“‟”’"‘‛❛❜〝〞«»‹›❝❞]'): "'",
};

const int _dot = 46;
const int _hiphen = 45;

/// Words obtained from [SPDX corpus][]
///
/// [SPDX corpus]: https://github.com/spdx/license-list-XML/blob/master/equivalentwords.txt
// TODO : Some words are left out from the original list
// fina a way to work with remaining words.
final HashMap<String, String> _varietalWords = HashMap.from({
  'acknowledgment': 'acknowledgement',
  'analogue': 'analog',
  'analyse': 'analyze',
  'artefact': 'artifact',
  'authorization': 'authorisation',
  'authorized': 'authorised',
  'calibre': 'caliber',
  'canceled': 'cancelled',
  'capitalizations': 'capitalisations',
  'catalogue': 'catalog',
  'categorise': 'categorize',
  'centre': 'center',
  'emphasised': 'emphasized',
  'favor': 'favour',
  'favorite': 'favourite',
  'fulfil': 'fulfill',
  'fulfillment': 'fulfilment',
  'initialise': 'initialize',
  'judgment': 'judgement',
  'labelling': 'labeling',
  'labor': 'labour',
  'licence': 'license',
  'maximize': 'maximise',
  'modelled': 'modeled',
  'modelling': 'modeling',
  'offence': 'offense',
  'optimise': 'optimize',
  'organization': 'organisation',
  'organize': 'organise',
  'practice': 'practise',
  'programme': 'program',
  'realise': 'realize',
  'recognise': 'recognize',
  'signalling': 'signaling',
  'sublicence': 'sublicense',
  'utilisation': 'utilization',
  'whilst': 'while',
  'wilful': 'wilfull',
  'http:': 'https:',
});

// Remaining varietal words
// final _varietalWords = {
//   'copyright holder': 'copyright owner',
//   'per cent': 'percent',
//   'sub license': 'sublicense',
// };
