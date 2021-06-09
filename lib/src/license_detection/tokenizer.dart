import 'dart:collection';
import 'dart:convert';

class Token {
  String token;
  int? position;
  final int line;

  Token(this.token, this.position, this.line);
}

class Tokenizer {
  static const lineSplitter = LineSplitter();
  static List<Token> tokenize(String text) {
    var tokens = <Token>[];

    var lines = lineSplitter.convert(text);
    var position = 0;

    for (var i = 1; i <= lines.length; i++) {
      var line = lines[i - 1];

      var buffer = StringBuffer();
      var prevSignificant = false;

      for (var rune in line.runes) {
        if (!_isDigit(rune) && !prevSignificant) {
          continue;
        }

        if (_isSpace(rune)) {
          if (buffer.isNotEmpty) {
            tokens.add(Token(buffer.toString(), position++, i));
            buffer.clear();
          }
          prevSignificant = false;
          continue;
        }

        buffer.write(String.fromCharCode(rune));
        prevSignificant = true;
      }
      if (buffer.isNotEmpty) {
        tokens.add(Token(buffer.toString(), position++, i));
      }

      tokens.add(Token('\n', null, i));
    }

    //Guideline 7.1.1: Ignore list item for matching purposes.
    tokens = removeListItems(tokens);

    return tokens;
  }

  static List<Token> removeListItems(List<Token> tokens) {
    var newLine = true;
    var position = 0;
    var output = <Token>[];

    for (var i = 0; i < tokens.length; i++) {
      if (newLine && isListItem(tokens[i].token)) {
        continue;
      }

      if (tokens[i].token == '\n') {
        newLine = true;
        continue;
      }

      newLine = false;
      tokens[i].position = position++;
      output.add(tokens[i]);
    }

    return output;
  }
}

bool _isSpace(int rune) {
  switch (rune) {
    case 32:
    case 133:
      return true;
    default:
      return false;
  }
}

bool _isDigit(int rune) {
  return (rune > 47 && rune < 58) || (rune > 96 && rune < 123);
}

bool isListItem(String token) {
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

final _headers = HashSet.from(
    'q w e r t y u i o p a s d f g h j k l z x c v b n m i ii iii iv vi vii ix xi xii 0 1 2 3 4 5 6 7 8 9'
        .split(' '));
final _numberHeaderRe = RegExp(r'^\d{1,2}(\.\d{1,2})*\.$');
