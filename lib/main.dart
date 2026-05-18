import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'models/receipt_models.dart';
import 'state/receipt_controller.dart';

void main() {
  runApp(const ProviderScope(child: ReceiptSplitterApp()));
}

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
      home: const ReceiptFlowScreen(),
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
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: Text('인식된 항목이 없습니다. + 버튼으로 직접 추가하세요.')),
          ),
      ],
    );
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
