import '../models/receipt_models.dart';

class SplitCalculator {
  SplitResult calculate({
    required Receipt receipt,
    required List<Participant> participants,
    required Map<String, Assignment> assignments,
  }) {
    final base = {for (final participant in participants) participant.id: 0};
    final adjustments = {
      for (final participant in participants) participant.id: 0,
    };
    if (participants.isEmpty) {
      return const SplitResult(
        baseByParticipant: {},
        adjustmentsByParticipant: {},
        totalByParticipant: {},
      );
    }

    for (final item in receipt.items.where(
      (item) => item.lineType == LineType.item,
    )) {
      final assignees = _assignees(item.id, participants, assignments);
      _allocate(base, assignees, item.total);
    }

    final baseTotal = base.values.fold<int>(0, (sum, value) => sum + value);
    final globalAdjustments = receipt.items.where((item) {
      return item.lineType == LineType.tax ||
          item.lineType == LineType.service ||
          item.lineType == LineType.discount;
    });

    for (final adjustment in globalAdjustments) {
      if (baseTotal == 0) {
        _allocate(
          adjustments,
          participants.map((p) => p.id).toList(),
          adjustment.total,
        );
      } else {
        _allocateByRatio(adjustments, base, adjustment.total);
      }
    }

    final totals = {
      for (final participant in participants)
        participant.id:
            (base[participant.id] ?? 0) + (adjustments[participant.id] ?? 0),
    };

    return SplitResult(
      baseByParticipant: base,
      adjustmentsByParticipant: adjustments,
      totalByParticipant: totals,
    );
  }

  List<String> _assignees(
    String itemId,
    List<Participant> participants,
    Map<String, Assignment> assignments,
  ) {
    final assigned =
        assignments[itemId]?.participantIds.toList() ?? const <String>[];
    return assigned.isEmpty ? participants.map((p) => p.id).toList() : assigned;
  }

  void _allocate(Map<String, int> target, List<String> ids, int amount) {
    if (ids.isEmpty) return;
    final share = amount ~/ ids.length;
    var remainder = amount - share * ids.length;
    for (final id in ids) {
      final extra = remainder == 0 ? 0 : (remainder > 0 ? 1 : -1);
      target[id] = (target[id] ?? 0) + share + extra;
      remainder -= extra;
    }
  }

  void _allocateByRatio(
    Map<String, int> target,
    Map<String, int> weights,
    int amount,
  ) {
    final totalWeight = weights.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    if (totalWeight == 0) {
      _allocate(target, weights.keys.toList(), amount);
      return;
    }

    var allocated = 0;
    final ids = weights.keys.toList();
    for (var index = 0; index < ids.length; index++) {
      final id = ids[index];
      final share = index == ids.length - 1
          ? amount - allocated
          : (amount * (weights[id] ?? 0) / totalWeight).round();
      target[id] = (target[id] ?? 0) + share;
      allocated += share;
    }
  }
}
