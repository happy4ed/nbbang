import 'dart:math';

enum LineType { item, tax, service, discount, payment, ignored }

class OcrToken {
  const OcrToken({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get centerY => (top + bottom) / 2;
  double get width => max(0, right - left);
}

class LineItem {
  const LineItem({
    required this.id,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.total,
    required this.lineType,
  });

  final String id;
  final String name;
  final double qty;
  final int unitPrice;
  final int total;
  final LineType lineType;

  LineItem copyWith({
    String? id,
    String? name,
    double? qty,
    int? unitPrice,
    int? total,
    LineType? lineType,
  }) {
    return LineItem(
      id: id ?? this.id,
      name: name ?? this.name,
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice,
      total: total ?? this.total,
      lineType: lineType ?? this.lineType,
    );
  }
}

class Participant {
  const Participant({required this.id, required this.name});

  final String id;
  final String name;
}

class Assignment {
  const Assignment({required this.itemId, required this.participantIds});

  final String itemId;
  final Set<String> participantIds;
}

class Receipt {
  const Receipt({
    required this.items,
    required this.rawText,
    required this.tokens,
  });

  final List<LineItem> items;
  final String rawText;
  final List<OcrToken> tokens;

  Receipt copyWith({
    List<LineItem>? items,
    String? rawText,
    List<OcrToken>? tokens,
  }) {
    return Receipt(
      items: items ?? this.items,
      rawText: rawText ?? this.rawText,
      tokens: tokens ?? this.tokens,
    );
  }
}

class SplitResult {
  const SplitResult({
    required this.baseByParticipant,
    required this.adjustmentsByParticipant,
    required this.totalByParticipant,
  });

  final Map<String, int> baseByParticipant;
  final Map<String, int> adjustmentsByParticipant;
  final Map<String, int> totalByParticipant;
}
