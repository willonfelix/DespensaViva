import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class StockReportScreen extends StatelessWidget {
  final String environmentName;
  final Uint8List pdfBytes;

  const StockReportScreen({
    super.key,
    required this.environmentName,
    required this.pdfBytes,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = environmentName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    return Scaffold(
      appBar: AppBar(title: const Text('Relatório'), centerTitle: true),
      body: PdfPreview(
        build: (_) async => pdfBytes,
        pdfFileName:
            'relatorio-${fileName.isEmpty ? 'dispensa' : fileName}.pdf',
        canChangeOrientation: false,
        canChangePageFormat: false,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}
