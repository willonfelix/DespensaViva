import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_formatter.dart';
import '../products/catalog_controller.dart';
import '../pantry/pantry_controller.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minQuantityController = TextEditingController();

  int? _selectedCategoryId;
  String _selectedUnit = 'unidade';
  DateTime? _expirationDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(catalogControllerProvider.notifier).load());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _minQuantityController.dispose();
    super.dispose();
  }

  Future<void> _selectExpirationDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _expirationDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione uma categoria.')),
      );
      return;
    }

    setState(() => _saving = true);
    final name = _nameController.text.trim();
    final quantity = double.parse(_quantityController.text.replaceAll(',', '.'));
    final minQuantity = double.parse(_minQuantityController.text.replaceAll(',', '.'));

    try {
      await ref.read(pantryControllerProvider.notifier).add(
            name: name,
            categoryId: _selectedCategoryId!,
            unitOfMeasure: _selectedUnit,
            quantity: quantity,
            minQuantity: minQuantity,
            expirationDate: _expirationDate,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar o item.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogControllerProvider);
    final categories = catalog.categories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar à Dispensa'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nome do Produto (Ex: Arroz Tio João 5kg)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.shopping_bag_outlined),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Informe o nome do produto.' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<int>(
                initialValue: _selectedCategoryId,
                decoration: InputDecoration(
                  labelText: 'Categoria',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                items: categories
                    .map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategoryId = v),
                validator: (v) => v == null ? 'Selecione uma categoria' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _selectedUnit,
                decoration: InputDecoration(
                  labelText: 'Unidade de Medida',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.scale_outlined),
                ),
                items: catalog.units
                    .map((u) => DropdownMenuItem<String>(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedUnit = v ?? 'unidade'),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Qtd Atual',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.add_box_outlined),
                      ),
                      validator: _decimalValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _minQuantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Qtd Mínima (Alerta)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.notification_important_outlined),
                      ),
                      validator: _decimalValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: () => _selectExpirationDate(context),
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Data de Validade (Opcional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    suffixIcon: _expirationDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _expirationDate = null),
                          )
                        : null,
                  ),
                  child: Text(
                    _expirationDate == null ? 'Nenhuma validade informada' : formatDate(_expirationDate),
                    style: TextStyle(
                      color: _expirationDate == null ? Colors.grey.shade600 : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.save),
                label: const Text('Salvar Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _decimalValidator(String? value) {
    final v = value ?? '';
    if (v.trim().isEmpty) return 'Obrigatório';
    if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Valor inválido';
    return null;
  }
}