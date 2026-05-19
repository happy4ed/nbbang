import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/receipt_models.dart';
import '../services/llm_receipt_parser.dart';
import '../services/llm_service.dart';
import '../services/ocr_service.dart';
import '../services/receipt_parser.dart';
import '../services/split_calculator.dart';

final receiptControllerProvider =
    NotifierProvider<ReceiptController, ReceiptState>(ReceiptController.new);

class ReceiptState {
  const ReceiptState({
    required this.step,
    required this.receipt,
    required this.participants,
    required this.assignments,
    required this.isScanning,
    required this.error,
    required this.usedLlm,
    required this.llmStatus,
    required this.llmRawResponse,
    required this.llmElapsedMs,
    required this.llmError,
  });

  factory ReceiptState.initial() {
    return const ReceiptState(
      step: 0,
      receipt: Receipt(items: [], rawText: '', tokens: []),
      participants: [
        Participant(id: 'p_1', name: '1번'),
        Participant(id: 'p_2', name: '2번'),
      ],
      assignments: {},
      isScanning: false,
      error: null,
      usedLlm: false,
      llmStatus: -1,
      llmRawResponse: null,
      llmElapsedMs: 0,
      llmError: null,
    );
  }

  final int step;
  final Receipt receipt;
  final List<Participant> participants;
  final Map<String, Assignment> assignments;
  final bool isScanning;
  final String? error;
  final bool usedLlm;
  final int llmStatus;
  final String? llmRawResponse;
  final int llmElapsedMs;
  final String? llmError;

  ReceiptState copyWith({
    int? step,
    Receipt? receipt,
    List<Participant>? participants,
    Map<String, Assignment>? assignments,
    bool? isScanning,
    String? error,
    bool clearError = false,
    bool? usedLlm,
    int? llmStatus,
    String? llmRawResponse,
    bool clearLlmRawResponse = false,
    int? llmElapsedMs,
    String? llmError,
    bool clearLlmError = false,
  }) {
    return ReceiptState(
      step: step ?? this.step,
      receipt: receipt ?? this.receipt,
      participants: participants ?? this.participants,
      assignments: assignments ?? this.assignments,
      isScanning: isScanning ?? this.isScanning,
      error: clearError ? null : error ?? this.error,
      usedLlm: usedLlm ?? this.usedLlm,
      llmStatus: llmStatus ?? this.llmStatus,
      llmRawResponse: clearLlmRawResponse ? null : llmRawResponse ?? this.llmRawResponse,
      llmElapsedMs: llmElapsedMs ?? this.llmElapsedMs,
      llmError: clearLlmError ? null : llmError ?? this.llmError,
    );
  }

  SplitResult get splitResult {
    return SplitCalculator().calculate(
      receipt: receipt,
      participants: participants,
      assignments: assignments,
    );
  }
}

class ReceiptController extends Notifier<ReceiptState> {
  final _parser = ReceiptParser();
  final _llmParser = LlmReceiptParser(llm: LlmService());
  final _ocr = OcrService();

  @override
  ReceiptState build() => ReceiptState.initial();

  Future<void> importReceipt(ImageSource source) async {
    state = state.copyWith(isScanning: true, clearError: true);
    try {
      final result = await _ocr.pickAndRead(source);
      if (result == null) {
        state = state.copyWith(isScanning: false);
        return;
      }
      final parsed = await _llmParser.parse(
        rawText: result.text,
        tokens: result.tokens,
      );
      state = state.copyWith(
        receipt: parsed.receipt,
        step: 1,
        isScanning: false,
        usedLlm: parsed.usedLlm,
        llmStatus: parsed.llmStatus,
        llmRawResponse: parsed.llmRawResponse,
        llmElapsedMs: parsed.llmElapsedMs,
        llmError: parsed.llmError,
        clearLlmError: parsed.llmError == null,
      );
    } catch (error) {
      state = state.copyWith(
        isScanning: false,
        error: 'OCR 처리에 실패했습니다: $error',
      );
    }
  }

  void useSample() {
    const sample = '''
아메리카노 2 9,000
카페라떼 5,500
행사할인 1,000
부가세 1,350
합계 14,850
신용카드 14,850
''';
    state = state.copyWith(
      receipt: _parser.parse(rawText: sample, tokens: const []),
      step: 1,
      clearError: true,
      usedLlm: false,
      llmStatus: -1,
      clearLlmRawResponse: true,
      llmElapsedMs: 0,
      clearLlmError: true,
    );
  }

  void goTo(int step) => state = state.copyWith(step: step.clamp(0, 3).toInt());

  void updateItem(LineItem item) {
    state = state.copyWith(
      receipt: state.receipt.copyWith(
        items: [
          for (final current in state.receipt.items)
            if (current.id == item.id) item else current,
        ],
      ),
    );
  }

  void addItem(LineItem item) {
    state = state.copyWith(
      receipt: state.receipt.copyWith(items: [...state.receipt.items, item]),
    );
  }

  void deleteItem(String id) {
    final assignments = {...state.assignments}..remove(id);
    state = state.copyWith(
      receipt: state.receipt.copyWith(
        items: state.receipt.items.where((item) => item.id != id).toList(),
      ),
      assignments: assignments,
    );
  }

  void addParticipant(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final id = 'p_${DateTime.now().microsecondsSinceEpoch}';
    state = state.copyWith(
      participants: [
        ...state.participants,
        Participant(id: id, name: trimmed),
      ],
    );
  }

  void removeParticipant(String id) {
    final participants = state.participants
        .where((participant) => participant.id != id)
        .toList();
    final assignments = {
      for (final entry in state.assignments.entries)
        entry.key: Assignment(
          itemId: entry.key,
          participantIds: {...entry.value.participantIds}..remove(id),
        ),
    };
    state = state.copyWith(
      participants: participants,
      assignments: assignments,
    );
  }

  void toggleAssignment(String itemId, String participantId) {
    final current = state.assignments[itemId]?.participantIds ?? <String>{};
    final next = {...current};
    if (next.contains(participantId)) {
      next.remove(participantId);
    } else {
      next.add(participantId);
    }
    state = state.copyWith(
      assignments: {
        ...state.assignments,
        itemId: Assignment(itemId: itemId, participantIds: next),
      },
    );
  }
}
