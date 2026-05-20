import 'dart:convert';

import '../models/receipt_models.dart';
import 'llm_service.dart';

enum LayoutType { col2NamePrice, col1Inline, col3QtyNamePrice, unknown }

class LayoutClassification {
  const LayoutClassification({
    required this.layoutType,
    required this.confidence,
    this.fallbackReason,
  });

  final LayoutType layoutType;
  final double confidence;
  final String? fallbackReason;

  bool get isConfident => confidence >= 0.6;
}

class ReceiptLayoutClassifier {
  ReceiptLayoutClassifier({required LlmService llm}) : _llm = llm;

  final LlmService _llm;

  Future<LayoutClassification?> classify(List<OcrToken> tokens) async {
    if (tokens.isEmpty) return null;
    final response = await _llm.generateText(_buildPrompt(tokens));
    if (response == null || response.isEmpty) return null;
    return _parseResponse(response);
  }

  String _buildPrompt(List<OcrToken> tokens) {
    final sorted = [...tokens]
      ..sort((a, b) {
        final dy = a.centerY - b.centerY;
        if (dy.abs() > 12) return dy.sign.toInt();
        return a.left.compareTo(b.left);
      });

    final lines = <String>[];
    double? lastY;
    var lineId = 0;
    final buf = <String>[];

    for (final t in sorted) {
      if (lastY != null && (t.centerY - lastY).abs() > 12) {
        if (buf.isNotEmpty) {
          lines.add('L$lineId: ${buf.join(' ')}');
          buf.clear();
          lineId++;
        }
      }
      buf.add(t.text);
      lastY = t.centerY;
    }
    if (buf.isNotEmpty) lines.add('L$lineId: ${buf.join(' ')}');

    final sample = lines.take(30).join('\n');
    return '한국 영수증 OCR 라인 데이터입니다. 레이아웃 타입을 분류하세요.\n\n'
        '$sample\n\n'
        'layoutType:\n'
        '- 2col_name_price: 왼쪽=상품명, 오른쪽=금액\n'
        '- 1col_inline: 한 줄에 상품명+금액 혼재\n'
        '- 3col_qty_name_price: 수량+상품명+금액 세 열\n'
        '- unknown: 분류 불가\n\n'
        'JSON만 출력:\n'
        '{"layoutType":"","confidence":0.0,"fallbackReason":null}';
  }

  LayoutClassification? _parseResponse(String response) {
    try {
      var json = response
          .trim()
          .replaceAll(RegExp(r'^```[a-z]*\n?', multiLine: true), '')
          .replaceAll(RegExp(r'\n?```$', multiLine: true), '');
      final start = json.indexOf('{');
      final end = json.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      json = json.substring(start, end + 1);

      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final typeStr =
          (decoded['layoutType'] as String? ?? 'unknown').toLowerCase();
      final confidence = (decoded['confidence'] as num? ?? 0.0).toDouble();
      final fallbackReason = decoded['fallbackReason'] as String?;

      final layoutType = switch (typeStr) {
        '2col_name_price' => LayoutType.col2NamePrice,
        '1col_inline' => LayoutType.col1Inline,
        '3col_qty_name_price' => LayoutType.col3QtyNamePrice,
        _ => LayoutType.unknown,
      };

      return LayoutClassification(
        layoutType: layoutType,
        confidence: confidence,
        fallbackReason: fallbackReason,
      );
    } catch (_) {
      return null;
    }
  }
}
