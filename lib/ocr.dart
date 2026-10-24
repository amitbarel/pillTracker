import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// A line of text read from the photo and how tall it was printed.
class TextLine {
  TextLine(this.text, this.height);
  final String text;
  final double height;
}

/// Reads the text on a medicine box photo.
Future<List<TextLine>> readLabel(String imagePath) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result =
        await recognizer.processImage(InputImage.fromFilePath(imagePath));
    return [
      for (final block in result.blocks)
        for (final line in block.lines)
          TextLine(line.text, line.boundingBox.height),
    ];
  } finally {
    await recognizer.close();
  }
}

final _hasLetters = RegExp(r'[A-Za-z֐-׿]{3,}');
final _strength = RegExp(r'^\d+([.,]\d+)?\s?(mg|mcg|µg|g|ml|iu)\b', caseSensitive: false);
final _noise = RegExp(
    r'^(tablets?|capsules?|caplets?|film[- ]coated|for oral use|oral use|'
    r'rx only|keep out of reach.*|batch.*|lot.*|exp.*|mfg.*|\d+\s?(tablets?|capsules?|caplets?))$',
    caseSensitive: false);

/// Lines most likely to be the medicine's name, best first.
///
/// The brand or generic name is usually the largest print on the box, so lines
/// are ranked by height. A strength printed on the line right after a name
/// ("500 mg") is joined to it.
List<String> nameCandidates(List<TextLine> lines, {int max = 5}) {
  final scored = <({String text, double height})>[];
  for (var i = 0; i < lines.length; i++) {
    final text = lines[i].text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.length < 3 || text.length > 40) continue;
    if (!_hasLetters.hasMatch(text) || _noise.hasMatch(text)) continue;
    var name = _tidy(text);
    if (i + 1 < lines.length && !_strength.hasMatch(text)) {
      final next = lines[i + 1].text.trim();
      if (_strength.hasMatch(next) && next.length <= 12) {
        name = '$name ${next.toLowerCase()}';
      }
    }
    scored.add((text: name, height: lines[i].height));
  }
  scored.sort((a, b) => b.height.compareTo(a.height));

  final seen = <String>{};
  final out = <String>[];
  for (final c in scored) {
    if (seen.add(c.text.toLowerCase())) out.add(c.text);
    if (out.length == max) break;
  }
  return out;
}

/// "PARACETAMOL" → "Paracetamol". Mixed case is left alone.
String _tidy(String s) {
  if (s != s.toUpperCase()) return s;
  return s.split(' ').map((w) {
    if (w.length <= 1 || RegExp(r'\d').hasMatch(w)) return w.toLowerCase();
    return w[0] + w.substring(1).toLowerCase();
  }).join(' ');
}
