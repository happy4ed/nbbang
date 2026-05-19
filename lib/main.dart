import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'models/receipt_models.dart';
import 'state/receipt_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _lastError = details.exceptionAsString();
  };
  runApp(const ProviderScope(child: ReceiptSplitterApp()));
}

String? _lastError;

class ReceiptSplitterApp extends StatelessWidget {
  const ReceiptSplitterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Receipt Splitter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff256f5b)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const _ErrorBoundary(child: ReceiptFlowScreen()),
    );
  }
}

class _ErrorBoundary extends StatefulWidget {
  const _ErrorBoundary({required this.child});
  final Widget child;

  @override
  State<_ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<_ErrorBoundary> {
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_lastError != null) _error = _lastError;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('오류 발생')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('앱 오류가 발생했습니다. 아래 내용을 클로이에게 전달해주세요:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SelectableText(_error!, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => setState(() => _error = null),
                child: const Text('무시하고 계속'),
              ),
            ],
          ),
        ),
      );
    }

    return ErrorWidget.builder == ErrorWidget.withDetails
        ? widget.child
        : Builder(
            builder: (context) {
              ErrorWidget.builder = (details) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _error = details.exceptionAsString());
                });
                return const SizedBox.shrink();
              };
              return widget.child;
            },
          );
  }
}

class ReceiptFlowScreen extends ConsumerWidget {
  const ReceiptFlowScreen({super.key});

  static const _titles = ['가져오기', '파싱 검토', '항목 배정', '정산 결과'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(receiptControllerProvider);
    final controller = ref.read(receiptControllerProvider.notifier);
    final pages = [
      const ReceiptImportScreen(),
      const ParseReviewScreen(),
      const AssignItemsScreen(),
      const SplitSummaryScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[state.step]),
        leading: state.step == 0
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => controller.goTo(state.step - 1),
              ),
      ),
      body: Column(
        children: [
          _StepHeader(step: state.step),
          if (state.error != null)
            MaterialBanner(
              content: Text(state.error!),
              actions: [
                TextButton(
                  onPressed: () => controller.goTo(state.step),
                  child: const Text('확인'),
                ),
              ],
            ),
          Expanded(child: pages[state.step]),
        ],
      ),
      bottomNavigationBar: state.step == 0
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  onPressed: state.step >= 3
                      ? null
                      : () => controller.goTo(state.step + 1),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(state.step == 2 ? '정산 보기' : '다음'),
                ),
              ),
            ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: List.generate(4, (index) {
          final active = index <= step;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index == 3 ? 0 : 6),
              decoration: BoxDecoration(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Colors.black12,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class ReceiptImportScreen extends ConsumerWidget {
  const ReceiptImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(receiptControllerProvider);
    final controller = ref.read(receiptControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: state.isScanning
                  ? const CircularProgressIndicator()
                  : Icon(
                      Icons.receipt_long,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: state.isScanning
              ? null
              : () => controller.importReceipt(ImageSource.camera),
          icon: const Icon(Icons.photo_camera),
          label: const Text('카메라로 촬영'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: state.isScanning
              ? null
              : () => controller.importReceipt(ImageSource.gallery),
          icon: const Icon(Icons.photo_library),
          label: const Text('갤러리에서 선택'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: state.isScanning ? null : controller.useSample,
          icon: const Icon(Icons.science),
          label: const Text('샘플 영수증으로 시작'),
        ),
      ],
    );
  }
}

class ParseReviewScreen extends ConsumerWidget {
  const ParseReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(receiptControllerProvider);
    final controller = ref.read(receiptControllerProvider.notifier);
    final items = state.receipt.items
        .where((item) => item.lineType != LineType.ignored)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '파싱된 라인 ${items.length}개',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (state.usedLlm)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AI 보정됨',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.rule, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '기본 파서',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            IconButton.filledTonal(
              tooltip: '항목 추가',
              onPressed: () => _openItemEditor(context, ref),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final item in items)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(item.name),
              subtitle: Text(
                '${item.lineType.label} · 수량 ${item.qty.clean} · 단가 ${item.unitPrice.money}',
              ),
              trailing: Text(
                item.total.money,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () => _openItemEditor(context, ref, item),
              onLongPress: () => controller.deleteItem(item.id),
            ),
          ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Column(
              children: [
                const Icon(Icons.receipt_long, size: 48, color: Colors.black26),
                const SizedBox(height: 12),
                const Text(
                  '품목을 찾지 못했어요.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  '카드 승인전표가 아닌\n메뉴가 나열된 주문 영수증을 촬영해봐요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => ref
                      .read(receiptControllerProvider.notifier)
                      .goTo(0),
                  icon: const Icon(Icons.camera_alt, size: 16),
                  label: const Text('다시 촬영'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        _OcrDebugPanel(
          receipt: state.receipt,
          usedLlm: state.usedLlm,
          llmStatus: state.llmStatus,
          llmRawResponse: state.llmRawResponse,
          llmElapsedMs: state.llmElapsedMs,
          llmError: state.llmError,
        ),
      ],
    );
  }
}

class _OcrDebugPanel extends StatefulWidget {
  const _OcrDebugPanel({
    required this.receipt,
    required this.usedLlm,
    required this.llmStatus,
    required this.llmRawResponse,
    required this.llmElapsedMs,
    required this.llmError,
  });
  final Receipt receipt;
  final bool usedLlm;
  final int llmStatus;
  final String? llmRawResponse;
  final int llmElapsedMs;
  final String? llmError;

  @override
  State<_OcrDebugPanel> createState() => _OcrDebugPanelState();
}

class _OcrDebugPanelState extends State<_OcrDebugPanel> {
  bool _expanded = false;

  String _llmStatusLabel(int status) => switch (status) {
        0 => '0 UNAVAILABLE',
        1 => '1 DOWNLOADABLE',
        2 => '2 DOWNLOADING',
        3 => '3 AVAILABLE',
        -1 => '미조회',
        _ => '$status UNKNOWN',
      };

  @override
  Widget build(BuildContext context) {
    final allItems = widget.receipt.items;
    final nanoLabel = widget.usedLlm
        ? '✨ AI 보정 성공 (${widget.llmElapsedMs}ms)'
        : widget.llmStatus == 3
            ? '⚠ AVAILABLE인데 파싱 실패'
            : 'status=${_llmStatusLabel(widget.llmStatus)}';

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.bug_report, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OCR 디버그 (전체 ${allItems.length}줄 / 무시 ${allItems.where((i) => i.lineType == LineType.ignored).length}줄)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          'Gemini Nano: $nanoLabel',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: widget.usedLlm
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.orange[700],
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Gemini Nano 디버그 섹션
                  Text('Gemini Nano 상태', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.usedLlm
                          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
                          : Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _debugRow(context, 'checkStatus()', _llmStatusLabel(widget.llmStatus)),
                        _debugRow(context, '개입 여부', widget.usedLlm ? '✅ 사용됨' : '❌ 미사용'),
                        if (widget.llmElapsedMs > 0)
                          _debugRow(context, '소요 시간', '${widget.llmElapsedMs}ms'),
                        if (widget.llmError != null)
                          _debugRow(context, '오류', widget.llmError!),
                        if (widget.llmRawResponse != null) ...[
                          const SizedBox(height: 4),
                          Text('LLM 원본 응답', style: Theme.of(context).textTheme.labelSmall),
                          const SizedBox(height: 2),
                          SelectableText(
                            widget.llmRawResponse!,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('전체 파싱 결과', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  for (final item in allItems)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _typeColor(item.lineType).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.lineType.label,
                              style: TextStyle(
                                fontSize: 10,
                                color: _typeColor(item.lineType),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${item.name}  ${item.total == 0 ? '' : item.total.money}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('OCR 원문', style: Theme.of(context).textTheme.labelMedium),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          final tokenDump = widget.receipt.tokens
                              .map((t) =>
                                  '${t.text.padRight(12)} x=${t.left.round()} y=${t.top.round()} w=${t.width.round()}')
                              .join('\n');
                          final full = '=== RAW TEXT ===\n${widget.receipt.rawText}\n\n=== TOKENS (text x y w) ===\n$tokenDump';
                          await Clipboard.setData(ClipboardData(text: full));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('원문 + 토큰 좌표 복사됨')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_all, size: 14),
                        label: const Text('전체 복사'),
                        style: TextButton.styleFrom(
                          textStyle: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      widget.receipt.rawText.isEmpty ? '(없음)' : widget.receipt.rawText,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                  if (widget.receipt.tokens.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('토큰 좌표 (x y 기준)', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        widget.receipt.tokens
                            .map((t) =>
                                '${t.text.padRight(10)} x=${t.left.round().toString().padLeft(4)} y=${t.top.round().toString().padLeft(4)} w=${t.width.round()}')
                            .join('\n'),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _debugRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Color _typeColor(LineType type) {
    return switch (type) {
      LineType.item => Colors.blue,
      LineType.tax => Colors.orange,
      LineType.service => Colors.purple,
      LineType.discount => Colors.green,
      LineType.payment => Colors.teal,
      LineType.ignored => Colors.grey,
    };
  }
}

class AssignItemsScreen extends ConsumerWidget {
  const AssignItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(receiptControllerProvider);
    final controller = ref.read(receiptControllerProvider.notifier);
    final items = state.receipt.items
        .where((item) => item.lineType == LineType.item)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '참여자',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton.filledTonal(
              tooltip: '참여자 추가',
              onPressed: () => _openParticipantDialog(context, ref),
              icon: const Icon(Icons.person_add),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final participant in state.participants)
              DragTarget<String>(
                onAcceptWithDetails: (details) =>
                    controller.toggleAssignment(details.data, participant.id),
                builder: (context, _, __) => InputChip(
                  avatar: const Icon(Icons.person, size: 18),
                  label: Text(participant.name),
                  onDeleted: state.participants.length <= 1
                      ? null
                      : () => controller.removeParticipant(participant.id),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('항목', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final item in items)
          Draggable<String>(
            data: item.id,
            feedback: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(item.name),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: .45,
              child: _AssignmentTile(item: item),
            ),
            child: _AssignmentTile(
              item: item,
              onTap: () => _openAssignmentSheet(context, ref, item),
            ),
          ),
        if (items.isEmpty) const Center(child: Text('정산 대상 품목이 없습니다.')),
      ],
    );
  }
}

class _AssignmentTile extends ConsumerWidget {
  const _AssignmentTile({required this.item, this.onTap});

  final LineItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(receiptControllerProvider);
    final assigned =
        state.assignments[item.id]?.participantIds ?? const <String>{};
    final names = assigned.isEmpty
        ? '전원 공동 부담'
        : state.participants
              .where((p) => assigned.contains(p.id))
              .map((p) => p.name)
              .join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.drag_indicator),
        title: Text(item.name),
        subtitle: Text(names),
        trailing: Text(item.total.money),
        onTap: onTap,
      ),
    );
  }
}

class SplitSummaryScreen extends ConsumerWidget {
  const SplitSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(receiptControllerProvider);
    final result = state.splitResult;
    final summary = _summaryText(state, result);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final participant in state.participants)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(participant.name),
              subtitle: Text(
                '품목 ${result.baseByParticipant[participant.id].money} · 조정 ${result.adjustmentsByParticipant[participant.id].money}',
              ),
              trailing: Text(
                result.totalByParticipant[participant.id].money,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: summary));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('정산 결과를 복사했습니다.')));
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('결과 복사'),
        ),
      ],
    );
  }
}

Future<void> _openParticipantDialog(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('참여자 추가'),
      content: TextField(
        controller: name,
        decoration: const InputDecoration(labelText: '이름'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            ref
                .read(receiptControllerProvider.notifier)
                .addParticipant(name.text);
            Navigator.pop(context);
          },
          child: const Text('추가'),
        ),
      ],
    ),
  );
}

Future<void> _openAssignmentSheet(
  BuildContext context,
  WidgetRef ref,
  LineItem item,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(receiptControllerProvider);
          final controller = ref.read(receiptControllerProvider.notifier);
          final assigned =
              state.assignments[item.id]?.participantIds ?? const <String>{};

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            shrinkWrap: true,
            children: [
              Text(item.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final participant in state.participants)
                CheckboxListTile(
                  value: assigned.contains(participant.id),
                  title: Text(participant.name),
                  onChanged: (_) =>
                      controller.toggleAssignment(item.id, participant.id),
                ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _openItemEditor(
  BuildContext context,
  WidgetRef ref, [
  LineItem? item,
]) async {
  final name = TextEditingController(text: item?.name ?? '');
  final qty = TextEditingController(text: item?.qty.clean ?? '1');
  final unitPrice = TextEditingController(
    text: item?.unitPrice.toString() ?? '0',
  );
  final total = TextEditingController(text: item?.total.toString() ?? '0');
  var type = item?.lineType ?? LineType.item;

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(item == null ? '항목 추가' : '항목 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: '항목명'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '수량'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: unitPrice,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '단가'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: total,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '금액'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<LineType>(
                value: type,
                decoration: const InputDecoration(labelText: '라인 타입'),
                items: LineType.values
                    .where((value) => value != LineType.ignored)
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => type = value ?? type),
              ),
            ],
          ),
        ),
        actions: [
          if (item != null)
            TextButton(
              onPressed: () {
                ref
                    .read(receiptControllerProvider.notifier)
                    .deleteItem(item.id);
                Navigator.pop(context);
              },
              child: const Text('삭제'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final next = LineItem(
                id:
                    item?.id ??
                    'manual_${DateTime.now().microsecondsSinceEpoch}',
                name: name.text.trim().isEmpty ? '수동 항목' : name.text.trim(),
                qty: double.tryParse(qty.text) ?? 1,
                unitPrice:
                    int.tryParse(unitPrice.text.replaceAll(',', '')) ?? 0,
                total: int.tryParse(total.text.replaceAll(',', '')) ?? 0,
                lineType: type,
              );
              final controller = ref.read(receiptControllerProvider.notifier);
              item == null
                  ? controller.addItem(next)
                  : controller.updateItem(next);
              Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    ),
  );
}

String _summaryText(ReceiptState state, SplitResult result) {
  final lines = ['정산 결과'];
  for (final participant in state.participants) {
    lines.add(
      '${participant.name}: ${result.totalByParticipant[participant.id].money}',
    );
  }
  return lines.join('\n');
}

extension on LineType {
  String get label {
    return switch (this) {
      LineType.item => '품목',
      LineType.tax => '세금',
      LineType.service => '봉사료',
      LineType.discount => '할인',
      LineType.payment => '결제/합계',
      LineType.ignored => '무시',
    };
  }
}

extension on num? {
  String get money {
    final value = (this ?? 0).round();
    final sign = value < 0 ? '-' : '';
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      final left = digits.length - index;
      buffer.write(digits[index]);
      if (left > 1 && left % 3 == 1) buffer.write(',');
    }
    return '$sign${buffer}원';
  }

  String get clean {
    final value = this ?? 0;
    return value % 1 == 0 ? value.round().toString() : value.toString();
  }
}
