import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/network/api_client.dart';

class StockReportException implements Exception {
  final String message;

  const StockReportException(this.message);
}

class StockReport {
  final String environmentName;
  final Uint8List pdfBytes;

  const StockReport({required this.environmentName, required this.pdfBytes});
}

class StockReportService {
  final Dio _dio;

  StockReportService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  Future<StockReport> generate(String environmentId) async {
    late final Response<dynamic> response;
    try {
      response = await _dio.get(
        '/environments/${Uri.encodeComponent(environmentId)}/report',
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = data is Map && data['error'] is String
          ? data['error'] as String
          : 'Não foi possível carregar os dados do relatório.';
      throw StockReportException(message);
    }

    final payload = response.data;
    if (payload is! Map) {
      throw const StockReportException('A resposta do relatório é inválida.');
    }

    final environment = payload['environment'];
    final rawItems = payload['items'];
    final generatedAt = DateTime.tryParse(
      payload['generatedAt']?.toString() ?? '',
    );
    if (environment is! Map ||
        environment['name'] is! String ||
        rawItems is! List ||
        generatedAt == null) {
      throw const StockReportException('A resposta do relatório é inválida.');
    }

    final items = <_StockReportItem>[];
    for (final rawItem in rawItems) {
      if (rawItem is! Map) {
        throw const StockReportException('A resposta do relatório é inválida.');
      }
      items.add(_StockReportItem.fromJson(Map<String, dynamic>.from(rawItem)));
    }

    final environmentName = environment['name'] as String;
    try {
      final pdfBytes = await _buildPdf(
        environmentName: environmentName,
        generatedAt: generatedAt,
        items: items,
      );
      return StockReport(environmentName: environmentName, pdfBytes: pdfBytes);
    } on Exception {
      throw const StockReportException('Não foi possível gerar o arquivo PDF.');
    }
  }

  static Future<Uint8List> _buildPdf({
    required String environmentName,
    required DateTime generatedAt,
    required List<_StockReportItem> items,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => [
          pw.Text(
            'Relatório de Itens do Estoque',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Dispensa: $environmentName'),
          pw.Text('Gerado em: ${_formatDateTime(generatedAt)}'),
          pw.Text('Total de itens: ${items.length}'),
          pw.SizedBox(height: 20),
          if (items.isEmpty)
            pw.Text('O estoque desta Dispensa está vazio.')
          else
            _itemsTable(items),
        ],
      ),
    );
    return document.save();
  }

  static pw.Widget _itemsTable(List<_StockReportItem> items) {
    const headerStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      fontSize: 9,
    );
    const cellStyle = pw.TextStyle(fontSize: 9);

    pw.Widget cell(String value, {bool header = false}) => pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(value, style: header ? headerStyle : cellStyle),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.2),
        1: pw.FlexColumnWidth(1.7),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            cell('Produto', header: true),
            cell('Categoria', header: true),
            cell('Quantidade', header: true),
            cell('Mínimo', header: true),
            cell('Validade', header: true),
          ],
        ),
        ...items.map(
          (item) => pw.TableRow(
            children: [
              cell(item.name),
              cell(item.category),
              cell(_formatQuantity(item.quantity, item.unitOfMeasure)),
              cell(_formatQuantity(item.minQuantity, item.unitOfMeasure)),
              cell(_formatDate(item.expirationDate)),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${_twoDigits(local.day)}/${_twoDigits(local.month)}/${local.year} '
        '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return 'Não informada';
    return '${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year}';
  }

  static String _formatQuantity(double quantity, String unit) {
    final formatted = quantity % 1 == 0
        ? quantity.toStringAsFixed(0)
        : quantity
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
    return '$formatted $unit';
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _StockReportItem {
  final String name;
  final String category;
  final double quantity;
  final String unitOfMeasure;
  final double minQuantity;
  final DateTime? expirationDate;

  const _StockReportItem({
    required this.name,
    required this.category,
    required this.quantity,
    required this.unitOfMeasure,
    required this.minQuantity,
    required this.expirationDate,
  });

  factory _StockReportItem.fromJson(Map<String, dynamic> json) =>
      _StockReportItem(
        name: json['name']?.toString() ?? '',
        category: json['category']?.toString().isNotEmpty == true
            ? json['category'].toString()
            : 'Sem categoria',
        quantity: _requiredQuantity(json['quantity']),
        unitOfMeasure: json['unitOfMeasure']?.toString() ?? 'unidade',
        minQuantity: _requiredQuantity(json['minQuantity']),
        expirationDate: _parseDate(json['expirationDate']),
      );

  static double _requiredQuantity(dynamic value) {
    final quantity = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (quantity == null || !quantity.isFinite) {
      throw const StockReportException('A resposta do relatório é inválida.');
    }
    return quantity;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
