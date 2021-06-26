import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';

/// A token in this context is a sequence of characters
/// scanned from the original text separated by a space
/// or new line.
@sealed
class Token {
  /// Normalized form of the text in [span].
  final String value;

  /// Denotes the token position.
  final int index;

  /// Zero based line number of token.
  int get line => span.start.line;

  /// SourceSpan of the token.
  final SourceSpan span;

  Token(this.value, this.index, this.span);

  Token.fromSpan(this.span, this.index)
      : value = _normalizeWord(span.text.toLowerCase());
}

/// The tokens are scanned and normalized according to this procedure.
/// 1. Tokens are words separated by spaces or new line. Ex - `hello new\nworld` -->[`hello`,`new`,`world`].
/// 2. Any pure puntcuations texts are ignored. Ex - `// % ^&^&*^ hello` --> [`hello`]
/// 3. Leading punctuations are ignored. Ex - `!hello $world&` --> [`hello`,`world&`]
/// 4. New line tokens are stored to stored initially to identify list items,
///    but later removed while cleaning tokens.
/// 5. Any tokens starting with alphabet are further cleaned to remove any
///    non-alphabet characters. Ex - `(hello wo$r1ld` --> [`hello`, `world`]
/// 6. If a token starts with digit any characters other than `.`, `-` will be ignored.
///    Dot at the end of the token will also be ignored. `1!@#$.1.1 1-1hj.23.` --> [`1.1.1`, `1-1.23`].
List<Token> tokenize(String text) {
  final _scanner = SpanScanner(text);

  var tokens = <Token>[];
  var tokenID = 0;

  Token? nextToken() {
    if (_scanner.scan(_wordRegex)) {
      return Token.fromSpan(_scanner.lastSpan!, tokenID++);
    }

    if (_scanner.scan(_newLineRegex)) {
      return Token('\n', tokenID++, _scanner.lastSpan!);
    }

    // Ignore whitespace
    if (_scanner.scan(_horizontalWhiteSpaceRegex)) {
      return null;
    }

    // Read only © and ignore other leading and standalone puntuation
    // if(_scanner.scan(RegExp(r'©'))){
    //   return NewToken.fromSpan(_scanner.lastSpan!, tokenID++);
    // }

    // If none of the above conditions match, this implies
    // the scanner is at single punctuation mark or leading
    // punctuation in a word. Ignore them and move the scanner forward.
    _scanner.readChar();
    return null;
  }

  /// Scans through the input text and creates a list of [NewToken]
  /// Whitespace, Leading or standalone punctuation are ignored as they are not significant.
  /// But newLine token is stored to deal with list Items.
  while (!_scanner.isDone) {
    final token = nextToken();

    if (token != null) {
      tokens.add(token);
    }
  }

  /// Normalizes tokens using the approach of [google licenseClassifier]
  /// to provide better chances of matching.
  /// [google licenseClassifier]: https://github.com/google/licenseclassifier/blob/bb04aff29e72e636ba260ec61150c6e15f111d7e/v2/tokenizer.go#L34
  tokens = _cleanNewTokens(tokens);

  return tokens;
}

List<Token> _cleanNewTokens(List<Token> tokens) {
  var output = <Token>[];
  var tokenID = 0;
  var firstInLine = true;

  for (var token in tokens) {
    // Ignore new line tokens for now.
    // If accuracy of detection is low apply
    // Guideline 2.1.4: Text that can be omited from license.
    if (_newLineRegex.hasMatch(token.value)) {
      firstInLine = true;
      continue;
    }

    // Ignores list items.
    if (firstInLine && _isListItem(token.value)) {
      continue;
    }

    firstInLine = false;

    final text = _cleanToken(token.value);

    output.add(Token(text, tokenID++, token.span));
  }

  return output;
}

/// Normalizes the tokens using the approach of [google licenseClassifier]
/// to provide better chances of matching.
/// [google licenseClassifier]  https://github.com/google/licenseclassifier/blob/bb04aff29e72e636ba260ec61150c6e15f111d7e/v2/tokenizer.go#L85
String _cleanToken(String tok) {
  if (tok.startsWith(RegExp(r'[^a-z]'))) {
    if (tok.startsWith(RegExp(r'\d'))) {
      var text = tok.replaceAll(RegExp(r'[^\d\.-]'), '');

      if (text.endsWith('.')) {
        text = text.substring(0, text.length - 1);
      }

      return text;
    }
  }

  var text = tok.replaceAll(RegExp(r'[^a-z]'), '');

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

String _normalizeWord(String text) {
  // Guideline 5: Equivalent Punctuation marks.
  _equivalentPunctuationMarks.forEach((reg, value) {
    text = text.replaceAll(reg, value);
  });

  return text;
}

final _headers = HashSet.from(
    'q w e r t y u i o p a s d f g h j k l z x c v b n m i ii iii iv vi vii ix xi xii'
        .split(' '));

final _numberHeaderRe = RegExp(r'^\d{1,2}(\.\d{1,2})*[\.)]$');

final _horizontalWhiteSpaceRegex = RegExp(r'[^\S\r\n]+');

final Map<RegExp, String> _equivalentPunctuationMarks = {
  // Guideline 5.1.2: All variants of dashes considered equivalent.
  RegExp(r'[-֊־᠆‐‑–—﹘﹣－‒⁃⁻⎯─⏤]'): '-',

  // Guideline Guideline 5.1.3: All variants of quotations considered equivalent.
  RegExp(r'[“‟”’"‘‛❛❜〝〞«»‹›❝❞]'): "'",

  // Guideline 9.1.1: “©”, “(c)”, or “Copyright” should be considered equivalent and interchangeable.
  RegExp(r'©'): '(c)'
};

final _wordRegex = RegExp(r'[\w\d][^\s]*');
final _newLineRegex = RegExp(r'(?:\n|\r\n|\r|\u0085)');

/// Words obtained from [SPDX corpus][]
///
/// [SPDX corpus]: https://github.com/spdx/license-list-XML/blob/master/equivalentwords.txt
// TODO : Some words are left out from the original list
// find a way to work with remaining words.
final _varietalWords = {
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
};

// Remaining varietal words
// final _varietalWords = {
//   'copyright holder': 'copyright owner',
//   'per cent': 'percent',
//   'sub license': 'sublicense',
// };
