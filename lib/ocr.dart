import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

/// A line of text read from the photo and how tall it was printed.
class TextLine {
  TextLine(this.text, this.height, {this.confidence});
  final String text;
  final double height;

  /// How sure the reader was, 0 to 1, where the platform reports it.
  final double? confidence;
}

/// Reads the text on a medicine box photo, in English and (on Android) Hebrew.
///
/// Either reader may fail on its own; the other's lines are still returned.
Future<List<TextLine>> readLabel(String imagePath) async {
  final results = await Future.wait([
    _readLatin(imagePath).catchError((Object e) {
      debugPrint('Latin reading failed: $e');
      return <TextLine>[];
    }),
    _readHebrew(imagePath).catchError((Object e) {
      debugPrint('Hebrew reading failed: $e');
      return <TextLine>[];
    }),
  ]);
  return [...results[0], ...results[1]];
}

/// ML Kit has no Hebrew, so Android runs Tesseract for it (see MainActivity).
const _hebrewChannel = MethodChannel('pill_tracker/hebrew_ocr');

Future<List<TextLine>> _readHebrew(String imagePath) async {
  if (!Platform.isAndroid) return [];
  final dataPath = await _hebrewModelDir();
  final lines = await _hebrewChannel.invokeListMethod<Map<Object?, Object?>>(
      'read', {'imagePath': imagePath, 'dataPath': dataPath});
  return [
    for (final l in lines ?? const <Map<Object?, Object?>>[])
      TextLine(
        l['text']! as String,
        (l['height']! as num).toDouble(),
        confidence: (l['confidence'] as num?)?.toDouble(),
      ),
  ];
}

/// Tesseract reads its model from a real file, so copy it out of the assets
/// once. Returns the folder that holds `tessdata/`.
Future<String> _hebrewModelDir() async {
  final base = await getApplicationSupportDirectory();
  final model = File('${base.path}/tessdata/heb.traineddata');
  if (!model.existsSync()) {
    final data = await rootBundle.load('assets/tessdata/heb.traineddata');
    await model.parent.create(recursive: true);
    final tmp = File('${model.path}.tmp');
    await tmp.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    await tmp.rename(model.path);
  }
  return base.path;
}

Future<List<TextLine>> _readLatin(String imagePath) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result =
        await recognizer.processImage(InputImage.fromFilePath(imagePath));
    return [
      for (final block in result.blocks)
        for (final line in block.lines)
          // The short side of the box is the print height, even when the
          // line runs up the side of the box.
          TextLine(
            line.text,
            line.boundingBox.shortestSide,
            confidence: line.confidence,
          ),
    ];
  } finally {
    await recognizer.close();
  }
}

final _hasLetters = RegExp(r'[A-Za-z֐-׿]{3,}');
final _letter = RegExp(r'[A-Za-z֐-׿]');
final _vowel = RegExp(r'[aeiouy]', caseSensitive: false);
final _hebrew = RegExp(r'[֐-׿]');
final _stroke = RegExp(r'[lIi1|!]');
final _edgeJunk = RegExp(r'^[\s|\[\](){}<>\\/.,:;_\-]+|[\s|\[\](){}<>\\/.,:;_\-]+$');

/// Below this the reader is usually guessing, often at Hebrew it can't read.
const minConfidence = 0.6;
final _strength = RegExp(r'^\d+([.,]\d+)?\s?(mg|mcg|µg|g|ml|iu|מ["״]?ג|מק["״]?ג|מ["״]?ל)(?![A-Za-z])',
    caseSensitive: false);
final _noise = RegExp(
    r'^(tablets?|capsules?|caplets?|film[- ]coated|for oral use|oral use|'
    r'rx only|keep out of reach.*|batch.*|lot.*|exp.*|mfg.*|\d+\s?(tablets?|capsules?|caplets?)|'
    r'טבליות|טבליה|כמוסות|קפליות|תרופת מרשם|לשימוש חיצוני|\d+\s?(טבליות|כמוסות|קפליות))$',
    caseSensitive: false);

/// Lines most likely to be the medicine's name, best first.
///
/// The brand or generic name is usually the largest print on the box, so lines
/// are ranked by height. A strength printed on the line right after a name
/// ("500 mg") is joined to it.
List<String> nameCandidates(List<TextLine> lines, {int max = 6}) {
  final scored = <({String text, double height})>[];
  for (var i = 0; i < lines.length; i++) {
    // Stray marks at the ends ("| name", "name [") come from box edges.
    final text = lines[i]
        .text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(_edgeJunk, '')
        .trim();
    if (text.length < 3 || text.length > 40) continue;
    if (!_hasLetters.hasMatch(text) || _noise.hasMatch(text)) continue;
    if (!_looksLikeWords(text)) continue;
    final confidence = lines[i].confidence;
    if (confidence != null && confidence < minConfidence) continue;
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

/// Mostly letters, and Latin words have vowels. Hebrew misread as Latin
/// letters tends to come out as "lIl1|" runs that fail one of these.
bool _looksLikeWords(String text) {
  final chars = text.replaceAll(' ', '');
  final letters = _letter.allMatches(chars).length;
  if (letters < chars.length * 0.6) return false;
  // Runs of l, I and 1 are what unreadable print usually turns into.
  if (chars.replaceAll(_stroke, '').length < 3) return false;
  return _hebrew.hasMatch(text) || _vowel.hasMatch(text);
}

/// "PARACETAMOL" → "Paracetamol". Mixed case is left alone.
String _tidy(String s) {
  if (s != s.toUpperCase()) return s;
  return s.split(' ').map((w) {
    if (w.length <= 1 || RegExp(r'\d').hasMatch(w)) return w.toLowerCase();
    return w[0] + w.substring(1).toLowerCase();
  }).join(' ');
}
