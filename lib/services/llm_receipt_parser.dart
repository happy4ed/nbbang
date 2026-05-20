import '../models/receipt_models.dart';
import 'llm_service.dart';
import 'receipt_layout_classifier.dart';
import 'receipt_parser.dart';

typedef ParseResult = ({
  Receipt receipt,
  bool usedLlm,
  int llmStatus,
  String? llmRawResponse,
  int llmElapsedMs,
  String? llmError,
});

class LlmReceiptParser {
  LlmReceiptParser({required LlmService llm}) : _llm = llm;

  final LlmService _llm;
  final _fallback = ReceiptParser();
  late final _classifier = ReceiptLayoutClassifier(llm: _llm);

  Future<ParseResult> parse({
    required String rawText,
    required List<OcrToken> tokens,
  }) async {
    Receipt fallbackReceipt() =>
        _fallback.parse(rawText: rawText, tokens: tokens);
    Receipt tokenColumnFallbackReceipt() => tokens.isEmpty
        ? fallbackReceipt()
        : _fallback.parseByTokenColumns(tokens);
    final sw = Stopwatch()..start();

    ParseResult fallbackResult({
      required int status,
      String? rawResponse,
      String? error,
      Receipt? receipt,
    }) => (
      receipt: receipt ?? fallbackReceipt(),
      usedLlm: false,
      llmStatus: status,
      llmRawResponse: rawResponse,
      llmElapsedMs: sw.elapsedMilliseconds,
      llmError: error,
    );

    try {
      int status = await _llm.checkStatus();

      if (status == LlmService.statusDownloadable) {
        try {
          await _llm.prepareIfNeeded();
          status = await _llm.checkStatus();
        } catch (_) {}
      }

      if (status == LlmService.statusUnavailable) {
        return fallbackResult(
          status: status,
          receipt: tokenColumnFallbackReceipt(),
          error:
              'AICore 미초기화 — 설정 > 개발자 옵션 > AICore Settings > Enable on-device GenAI Features 확인 후 재부팅',
        );
      }

      if (status == LlmService.statusDownloading) {
        return fallbackResult(
          status: status,
          receipt: tokenColumnFallbackReceipt(),
          error: 'AI 모델 다운로드 중 — 잠시 후 다시 시도',
        );
      }

      if (status != LlmService.statusAvailable) {
        return fallbackResult(
          status: status,
          receipt: tokenColumnFallbackReceipt(),
        );
      }

      final classification =
          tokens.isEmpty ? null : await _classifier.classify(tokens);

      if (classification == null || !classification.isConfident) {
        final reason = classification == null
            ? '레이아웃 분류 실패'
            : '낮은 신뢰도 (${classification.confidence.toStringAsFixed(2)})'
                '${classification.fallbackReason != null ? ": ${classification.fallbackReason}" : ""}';
        return fallbackResult(
          status: status,
          receipt: tokenColumnFallbackReceipt(),
          error: reason,
        );
      }

      final receipt = _routeByLayout(
        classification: classification,
        rawText: rawText,
        tokens: tokens,
      );

      sw.stop();
      return (
        receipt: receipt,
        usedLlm: true,
        llmStatus: status,
        llmRawResponse:
            '{"layoutType":"${classification.layoutType.name}","confidence":${classification.confidence.toStringAsFixed(2)}}',
        llmElapsedMs: sw.elapsedMilliseconds,
        llmError: null,
      );
    } catch (e) {
      return fallbackResult(
        status: -1,
        receipt: tokenColumnFallbackReceipt(),
        error: e.toString(),
      );
    }
  }

  Receipt _routeByLayout({
    required LayoutClassification classification,
    required String rawText,
    required List<OcrToken> tokens,
  }) => switch (classification.layoutType) {
    LayoutType.col2NamePrice => tokens.isEmpty
        ? _fallback.parse(rawText: rawText, tokens: tokens)
        : _fallback.parseByTokenColumns(tokens),
    LayoutType.col1Inline =>
      _fallback.parse(rawText: rawText, tokens: tokens),
    LayoutType.col3QtyNamePrice => _parseThreeColumn(rawText, tokens),
    LayoutType.unknown => tokens.isEmpty
        ? _fallback.parse(rawText: rawText, tokens: tokens)
        : _fallback.parseByTokenColumns(tokens),
  };

  // Stub: 3-column (qty + name + price) parser — Phase 2 implementation
  Receipt _parseThreeColumn(String rawText, List<OcrToken> tokens) =>
      tokens.isEmpty
          ? _fallback.parse(rawText: rawText, tokens: tokens)
          : _fallback.parseByTokenColumns(tokens);
}
