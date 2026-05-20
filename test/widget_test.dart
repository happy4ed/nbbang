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

  test('parser reconstructs receipt rows from token columns', () {
    const tokens = [
      OcrToken(text: '김밥', left: 10, top: 10, right: 50, bottom: 30),
      OcrToken(text: '4,000', left: 180, top: 12, right: 230, bottom: 32),
      OcrToken(text: '라면', left: 10, top: 40, right: 50, bottom: 60),
      OcrToken(text: '5,000원', left: 180, top: 42, right: 240, bottom: 62),
      OcrToken(text: '합계', left: 10, top: 70, right: 50, bottom: 90),
      OcrToken(text: '9,000', left: 180, top: 72, right: 230, bottom: 92),
    ];

    final receipt = ReceiptParser().parseByTokenColumns(tokens);

    expect(receipt.items, hasLength(3));
    expect(receipt.items[0].name, '김밥');
    expect(receipt.items[0].total, 4000);
    expect(receipt.items[1].name, '라면');
    expect(receipt.items[1].total, 5000);
    expect(receipt.items[2].lineType, LineType.payment);
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
