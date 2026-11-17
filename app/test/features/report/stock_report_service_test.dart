import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/report/stock_report_service.dart';

void main() {
  group('StockReportService', () {
    test('gera PDF válido quando o estoque está vazio', () async {
      final report = StockReport(
        environmentId: 'env-1',
        environmentName: 'Despensa principal',
        generatedAt: DateTime(2026, 11, 16, 20, 38),
        items: const [],
      );

      final pdf = await StockReportService.generatePdf(report);
      expect(pdf, isNotEmpty);
      expect(pdf.length, greaterThan(0));
    });

    test('exibe categoria e validade vazias com textos amigáveis', () {
      const item = StockReportItem(
        name: 'Arroz',
        category: '',
        quantity: 2,
        unitOfMeasure: 'kg',
        minQuantity: 1,
        expirationDate: null,
      );

      expect(item.displayCategory, 'Sem categoria');
      expect(item.displayExpirationDate, 'Não informada');
      expect(item.displayQuantity, '2 kg');
    });

    test('parseia o relatório com itens ordenados por nome', () {
      final report = StockReport.fromJson({
        'environment': {'id': 'env-1', 'name': 'Despensa principal'},
        'generatedAt': '2026-11-16T20:38:00.000Z',
        'items': [
          {'name': 'Leite', 'category': 'Laticínios', 'quantity': 3, 'unitOfMeasure': 'unidade', 'minQuantity': 2, 'expirationDate': null},
          {'name': 'Arroz', 'category': '', 'quantity': 2, 'unitOfMeasure': 'kg', 'minQuantity': 1, 'expirationDate': null},
        ],
      });

      expect(report.items.first.name, 'Arroz');
      expect(report.environmentName, 'Despensa principal');
      expect(report.totalItems, 2);
    });
  });
}
