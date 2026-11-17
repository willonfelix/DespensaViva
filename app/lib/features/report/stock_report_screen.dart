import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'stock_report_service.dart';

class StockReportScreen extends StatefulWidget {
  const StockReportScreen({super.key, required this.report});

  final StockReport report;

  @override
  State<StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends State<StockReportScreen> {
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPdf());
  }

  Future<void> _openPdf() async {
    if (_opening) return;
    setState(() => _opening = true);

    try {
      await Printing.layoutPdf(
        name: 'relatorio-estoque-${widget.report.environmentName}.pdf',
        onLayout: (PdfPageFormat format) => StockReportService.generatePdf(widget.report, format),
      );
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  Future<void> _sharePdf() async {
    final bytes = await StockReportService.generatePdf(widget.report);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'relatorio-estoque-${widget.report.environmentName}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório de Itens do Estoque'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf, size: 72, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Relatório da dispensa ${widget.report.environmentName}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                '${widget.report.totalItems} item(ns) registrado(s)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _opening ? null : _openPdf,
                icon: const Icon(Icons.preview),
                label: Text(_opening ? 'Abrindo...' : 'Visualizar PDF'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _sharePdf,
                icon: const Icon(Icons.share),
                label: const Text('Compartilhar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
