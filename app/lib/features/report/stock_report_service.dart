import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/network/api_client.dart';

class StockReportItem {
  const StockReportItem({
    required this.name,
    required this.category,
    required this.quantity,
    required this.unitOfMeasure,
    required this.minQuantity,
    this.expirationDate,
  });

  final String name;
  final String category;
  final double quantity;
  final String unitOfMeasure;
  final double minQuantity;
  final DateTime? expirationDate;

  String get displayCategory => category.trim().isEmpty ? 'Sem categoria' : category.trim();

  String get displayExpirationDate =>
      expirationDate == null ? 'Não informada' : _formatDate(expirationDate!);

  String get displayQuantity =>
      '${_formatNumber(quantity)} ${unitOfMeasure.trim().isEmpty ? 'unidade' : unitOfMeasure.trim()}';

  String get displayMinQuantity =>
      '${_formatNumber(minQuantity)} ${unitOfMeasure.trim().isEmpty ? 'unidade' : unitOfMeasure.trim()}';

  factory StockReportItem.fromJson(Map<String, dynamic> json) => StockReportItem(
        name: (json['name'] as String?) ?? '',
        category: (json['category'] as String?) ?? '',
        quantity: _toDouble(json['quantity']),
        unitOfMeasure: (json['unitOfMeasure'] as String?) ?? 'unidade',
        minQuantity: _toDouble(json['minQuantity']),
        expirationDate: json['expirationDate'] == null
            ? null
            : DateTime.tryParse(json['expirationDate'] as String),
      );

  static double _toDouble(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  static String _formatNumber(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    final text = value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return text;
  }
}

class StockReport {
  const StockReport({
    required this.environmentId,
    required this.environmentName,
    required this.generatedAt,
    required this.items,
  });

  final String environmentId;
  final String environmentName;
  final DateTime generatedAt;
  final List<StockReportItem> items;

  int get totalItems => items.length;

  static String _cleanString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  factory StockReport.fromJson(Map<String, dynamic> json) {
    final environment = json['environment'] as Map<String, dynamic>? ?? const {};
    final reportItems = (json['items'] as List? ?? const [])
        .map((item) => StockReportItem.fromJson(item as Map<String, dynamic>))
        .toList();

    reportItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return StockReport(
      environmentId: _cleanString(environment['id']),
      environmentName:
          _cleanString(environment['name']) == '' ? 'Dispensa' : _cleanString(environment['name']),
      generatedAt: DateTime.tryParse((json['generatedAt'] as String?) ?? '') ?? DateTime.now(),
      items: reportItems,
    );
  }
}

class StockReportService {
  const StockReportService._();

  static Future<StockReport> fetch(String environmentId) async {
    try {
      final response = await ApiClient.dio.get('/environments/$environmentId/report');
      return StockReport.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      final serverMessage = error.response?.data is Map<String, dynamic>
          ? error.response?.data['error']
          : null;
      throw Exception(serverMessage ?? 'Não foi possível gerar o relatório.');
    }
  }

  static Future<Uint8List> generatePdf(
    StockReport report, [
    PdfPageFormat format = PdfPageFormat.a4,
  ]) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Relatório de Itens do Estoque',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 12),
              pw.Text('Dispensa: ${report.environmentName}'),
              pw.Text('Gerado em: ${_formatDateTime(report.generatedAt)}'),
              pw.Text('Total de itens: ${report.totalItems}'),
              pw.SizedBox(height: 20),
              if (report.items.isEmpty)
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Text(
                    'Este estoque está vazio no momento.',
                    style: const pw.TextStyle(fontSize: 14),
                    textAlign: pw.TextAlign.center,
                  ),
                )
              else
                pw.Table.fromTextArray(
                  headers: ['Produto', 'Categoria', 'Quantidade', 'Mínimo', 'Validade'],
                  data: report.items
                      .map(
                        (item) => [
                          item.name,
                          item.displayCategory,
                          item.displayQuantity,
                          item.displayMinQuantity,
                          item.displayExpirationDate,
                        ],
                      )
                      .toList(),
                  border: null,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerRight,
                    3: pw.Alignment.centerRight,
                    4: pw.Alignment.centerLeft,
                  },
                ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}
