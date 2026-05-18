import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_splitter/services/receipt_parser.dart';
import 'package:receipt_splitter/services/split_calculator.dart';
import 'package:receipt_splitter/models/receipt_models.dart';

void main() {
  test('parser separates items, discounts, tax, and payment lines', () {
    final receipt = ReceiptParser().parse(
      rawText: '''
김밥 4,000
라면 5,000
쿠폰할인 1,000
부가세 800
합계 8,800
''',
      tokens: const [],
    );

    expect(
      receipt.items.where((item) => item.lineType == LineType.item),
      hasLength(2),
    );
    expect(
      receipt.items
          .singleWhere((item) => item.lineType == LineType.discount)
          .total,
      -1000,
    );
    expect(
      receipt.items.singleWhere((item) => item.lineType == LineType.tax).total,
      800,
    );
    expect(
      receipt.items
          .singleWhere((item) => item.lineType == LineType.payment)
          .name,
      '합계',
    );
  });

  test(
    'calculator shares unassigned items and allocates adjustments by ratio',
    () {
      const receipt = Receipt(
        rawText: '',
        tokens: [],
        items: [
          LineItem(
            id: 'a',
            name: 'A',
            qty: 1,
            unitPrice: 10000,
            total: 10000,
            lineType: LineType.item,
          ),
          LineItem(
            id: 'b',
            name: 'B',
            qty: 1,
            unitPrice: 5000,
            total: 5000,
            lineType: LineType.item,
          ),
          LineItem(
            id: 'tax',
            name: '부가세',
            qty: 1,
            unitPrice: 1500,
            total: 1500,
            lineType: LineType.tax,
          ),
        ],
      );
      const participants = [
        Participant(id: 'p1', name: 'A'),
        Participant(id: 'p2', name: 'B'),
      ];
      const assignments = {
        'a': Assignment(itemId: 'a', participantIds: {'p1'}),
        'b': Assignment(itemId: 'b', participantIds: {'p2'}),
      };

      final result = SplitCalculator().calculate(
        receipt: receipt,
        participants: participants,
        assignments: assignments,
      );

      expect(result.totalByParticipant['p1'], 11000);
      expect(result.totalByParticipant['p2'], 5500);
    },
  );
}
