import '../models/receipt_models.dart';

class ReceiptParser {
  Receipt parse({required String rawText, required List<OcrToken> tokens}) {
    final rows = tokens.isEmpty
        ? _rowsFromText(rawText)
        : _rowsFromTokens(tokens);
    final items = <LineItem>[];
    String? pendingName;

    for (final row in rows) {
      final parsed = _parseRow(row.text, items.length);
      if (parsed == null) {
        if (_looksLikeContinuation(row.text)) {
          pendingName = [
            pendingName,
            row.text.trim(),
          ].whereType<String>().join(' ');
        }
        continue;
      }

      final item = pendingName == null || parsed.lineType != LineType.item
          ? parsed
          : parsed.copyWith(name: '$pendingName ${parsed.name}'.trim());
      pendingName = null;
      items.add(item);
    }

    return Receipt(items: items, rawText: rawText, tokens: tokens);
  }

  List<_OcrRow> _rowsFromTokens(List<OcrToken> tokens) {
    final sorted = [...tokens]..sort((a, b) => a.centerY.compareTo(b.centerY));
    final rows = <List<OcrToken>>[];

    for (final token in sorted) {
      final row = rows.cast<List<OcrToken>?>().firstWhere(
        (candidate) =>
            candidate != null &&
            (candidate.first.centerY - token.centerY).abs() <= 9,
        orElse: () => null,
      );
      if (row == null) {
        rows.add([token]);
      } else {
        row.add(token);
      }
    }

    return rows.map((row) {
      row.sort((a, b) => a.left.compareTo(b.left));
      return _OcrRow(row.map((token) => token.text).join(' '));
    }).toList();
  }

  List<_OcrRow> _rowsFromText(String rawText) {
    return rawText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map(_OcrRow.new)
        .toList();
  }

  LineItem? _parseRow(String row, int index) {
    final normalized = row.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return null;

    // Skip date/time-only rows (e.g. "26.05.08 13:42", "2026-05-08", "13:42")
    if (RegExp(r'^\d{2,4}[./-]\d{2}[./-]\d{2}').hasMatch(normalized)) return null;

    final hasMoneyAnchor =
        RegExp(r'원|금액|합계|결제|이용|청구|합').hasMatch(normalized);

    // Filter amount candidates: exclude hyphen-adjacent numbers and
    // uncomma'd numbers > 5 digits unless a money anchor is present.
    final amountMatches = RegExp(
      r'[-]?\d[\d,]*(?:\.\d+)?',
    ).allMatches(normalized).where((m) {
      final start = m.start;
      final end = m.end;
      // Exclude if adjacent to hyphen (phone/card/biz-reg numbers)
      if (start > 0 && normalized[start - 1] == '-') return false;
      if (end < normalized.length && normalized[end] == '-') return false;
      // Exclude 8+ digit uncomma'd numbers (approval codes, biz-reg, card numbers)
      // unless a money anchor is present. Allows OCR-mangled amounts like "150000".
      final digits = m.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 8 && !m.group(0)!.contains(',') && !hasMoneyAnchor) {
        return false;
      }
      return true;
    }).toList();
    if (amountMatches.isEmpty) return null;

    final amountText = amountMatches.last.group(0)!;
    final amount = _parseMoney(amountText);
    if (amount == null) return null;

    final label = normalized.substring(0, amountMatches.last.start).trim();
    if (label.isEmpty) return null;

    final type = _classify(label, normalized);
    if (type == LineType.ignored) {
      return LineItem(
        id: 'line_$index',
        name: label,
        qty: 1,
        unitPrice: 0,
        total: 0,
        lineType: type,
      );
    }

    final columns = _extractColumns(label, amount);
    final signedAmount = type == LineType.discount && amount > 0
        ? -amount
        : amount;
    final qty = columns.qty ?? _extractQty(normalized);
    final unitPrice =
        columns.unitPrice ??
        (qty > 0 ? (signedAmount / qty).round() : signedAmount);

    return LineItem(
      id: 'line_$index',
      name: columns.name,
      qty: qty,
      unitPrice: unitPrice,
      total: signedAmount,
      lineType: type,
    );
  }

  LineType _classify(String label, String row) {
    final text = '$label $row'.toLowerCase();
    if (RegExp(r'합계|total|결제대상|총액|받을금액|청구금액|이용금액|승인금액|결제금액').hasMatch(text)) {
      return LineType.payment;
    }
    if (RegExp(r'부가세|vat|tax|세금').hasMatch(text)) return LineType.tax;
    if (RegExp(r'봉사료|service').hasMatch(text)) return LineType.service;
    if (RegExp(r'할인|쿠폰|discount|행사|적립사용').hasMatch(text))
      return LineType.discount;
    if (RegExp(r'카드|현금|승인|거스름|포인트|전화|tel|사업자|영수증|보증금|deposit|가맹점|대표자|주소|등록번호|판매자|일시').hasMatch(text)) {
      return LineType.ignored;
    }
    return LineType.item;
  }

  bool _looksLikeContinuation(String row) {
    final text = row.trim();
    if (text.length < 2) return false;
    return !RegExp(r'\d[\d,]*$').hasMatch(text) &&
        !RegExp(r'합계|승인|카드|현금|사업자|전화').hasMatch(text.toLowerCase());
  }

  double _extractQty(String row) {
    final qtyMatch = RegExp(
      r'(?:x|\*)\s*(\d+(?:\.\d+)?)|(\d+(?:\.\d+)?)\s*(?:개|ea)',
    ).firstMatch(row.toLowerCase());
    final value = qtyMatch?.group(1) ?? qtyMatch?.group(2);
    return double.tryParse(value ?? '') ?? 1;
  }

  _LineColumns _extractColumns(String label, int total) {
    final matches = RegExp(r'\d[\d,]*(?:\.\d+)?').allMatches(label).toList();
    if (matches.isEmpty || matches.last.end != label.length) {
      return _LineColumns(name: label);
    }

    final last = _parseMoney(matches.last.group(0)!);
    if (last == null) return _LineColumns(name: label);

    if (matches.length >= 2) {
      final previous = matches[matches.length - 2];
      final between = label.substring(previous.end, matches.last.start);
      final unit = _parseMoney(previous.group(0)!);
      if (unit != null && between.trim().isEmpty && last > 0 && last <= 99) {
        final expected = unit * last;
        if ((expected - total).abs() <= 2) {
          return _LineColumns(
            name: label.substring(0, previous.start).trim(),
            qty: last.toDouble(),
            unitPrice: unit,
          );
        }
      }
    }

    if (last > 0 && last <= 99) {
      return _LineColumns(
        name: label.substring(0, matches.last.start).trim(),
        qty: last.toDouble(),
      );
    }

    return _LineColumns(name: label);
  }

  int? _parseMoney(String value) {
    final cleaned = value.replaceAll(',', '');
    final parsed = double.tryParse(cleaned);
    return parsed == null ? null : parsed.round();
  }
}

class _OcrRow {
  const _OcrRow(this.text);

  final String text;
}

class _LineColumns {
  const _LineColumns({required this.name, this.qty, this.unitPrice});

  final String name;
  final double? qty;
  final int? unitPrice;
}
