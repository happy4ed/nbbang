import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../models/receipt_models.dart';

class OcrResult {
  const OcrResult({required this.text, required this.tokens});

  final String text;
  final List<OcrToken> tokens;
}

class OcrService {
  OcrService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  TextRecognizer? _recognizer;

  TextRecognizer get _getRecognizer {
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.korean);
    return _recognizer!;
  }

  Future<OcrResult?> pickAndRead(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (image == null) return null;

    final input = InputImage.fromFilePath(image.path);
    final recognized = await _getRecognizer.processImage(input);
    final tokens = <OcrToken>[];

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          final box = element.boundingBox;
          tokens.add(
            OcrToken(
              text: element.text,
              left: box.left,
              top: box.top,
              right: box.right,
              bottom: box.bottom,
            ),
          );
        }
      }
    }

    return OcrResult(text: recognized.text, tokens: tokens);
  }

  Future<void> close() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}
