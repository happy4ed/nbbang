import 'dart:convert';

import '../models/receipt_models.dart';
import 'llm_service.dart';
import 'receipt_parser.dart';

typedef ParseResult = ({Receipt receipt, bool usedLlm});

class LlmReceiptParser {
  LlmReceiptParser({required LlmService llm}) : _llm = llm;

  final LlmService _llm;
  final _fallback = ReceiptParser();

  Future<ParseResult> parse({
    required String rawText,
    required List<OcrToken> tokens,
  }) async {
    final fallbackReceipt = _fallback.parse(rawText: rawText, tokens: tokens);

    try {
      final status = await _llm.checkStatus();
      if (status != LlmService.statusAvailable) {
        return (receipt: fallbackReceipt, usedLlm: false);
      }

      final response = await _llm.generateText(_buildPrompt(rawText));
      if (response == null || response.isEmpty) {
        return (receipt: fallbackReceipt, usedLlm: false);
      }

      final items = _parseResponse(response);
      if (items == null || items.isEmpty) {
        return (receipt: fallbackReceipt, usedLlm: false);
      }

      return (
        receipt: Receipt(items: items, rawText: rawText, tokens: tokens),
        usedLlm: true,
      );
    } catch (_) {
      return (receipt: fallbackReceipt, usedLlm: false);
    }
  }

  String _buildPrompt(String rawText) =>
      '다음은 한국 영수증 OCR 텍스트입니다. JSON으로 파싱하세요.\n\n'
      'OCR:\n$rawText\n\n'
      'type 값: item(품목) tax(부가세) service(봉사료) discount(할인, 음수금액) '
      'payment(합계/결제) ignored(카드/승인 등 무관)\n'
      'qty 기본값 1, unitPrice 없으면 total과 동일\n\n'
      'JSON 형식만 출력:\n'
      '{"items":[{"name":"","qty":1,"unitPrice":0,"total":0,"type":"item"}]}';

  List<LineItem>? _parseResponse(String response) {
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
      final rawItems = decoded['items'] as List<dynamic>?;
      if (rawItems == null || rawItems.isEmpty) return null;

      return rawItems.asMap().entries.map((entry) {
        final i = entry.key;
        final m = entry.value as Map<String, dynamic>;
        final total = (m['total'] as num? ?? 0).toInt();
        final unitPrice = (m['unitPrice'] as num? ?? total).toInt();
        return LineItem(
          id: 'llm_$i',
          name: m['name'] as String? ?? '',
          qty: (m['qty'] as num? ?? 1).toDouble(),
          unitPrice: unitPrice,
          total: total,
          lineType: _parseType((m['type'] as String? ?? 'item').toLowerCase()),
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  LineType _parseType(String s) => switch (s) {
        'tax' => LineType.tax,
        'service' => LineType.service,
        'discount' => LineType.discount,
        'payment' => LineType.payment,
        'ignored' => LineType.ignored,
        _ => LineType.item,
      };
}
