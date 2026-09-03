import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pantry_item.dart';
import '../../core/network/api_client.dart';

class PantryState {
  final List<PantryItem> items;
  final bool loading;
  final String? error;

  const PantryState({
    this.items = const [],
    this.loading = false,
    this.error,
  });

  PantryState copyWith({
    List<PantryItem>? items,
    bool? loading,
    String? error,
  }) =>
      PantryState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        error: error,
      );
}

class PantryController extends StateNotifier<PantryState> {
  PantryController() : super(const PantryState());

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final response = await ApiClient.dio.get('/pantry');
      final items = (response.data['items'] as List)
          .map((e) => PantryItem.fromJson(e as Map<String, dynamic>))
          .toList();
      state = PantryState(items: items);
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _message(e));
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Erro ao carregar a dispensa.');
    }
  }

  Future<void> increment(PantryItem item) =>
      _updateQuantity(item, item.quantity + step(item.unitOfMeasure));

  Future<void> decrement(PantryItem item) => _updateQuantity(
        item,
        (item.quantity - step(item.unitOfMeasure)).clamp(0, double.infinity).toDouble(),
      );

  Future<void> _updateQuantity(PantryItem item, double newQuantity) async {
    // Atualização otimista
    final items = state.items
        .map((e) => e.id == item.id ? e.copyWith(quantity: newQuantity) : e)
        .toList();
    state = PantryState(items: items);

    try {
      await ApiClient.dio.put('/pantry/${item.id}', data: {
        'quantity': newQuantity,
      });
      await load();
    } on DioException catch (e) {
      state = state.copyWith(error: _message(e));
      await load();
    }
  }

  Future<void> add({
    required String name,
    required int categoryId,
    required String unitOfMeasure,
    required double quantity,
    required double minQuantity,
    DateTime? expirationDate,
  }) async {
    try {
      await ApiClient.dio.post('/pantry', data: {
        'name': name,
        'category_id': categoryId,
        'unit_of_measure': unitOfMeasure,
        'quantity': quantity,
        'min_quantity': minQuantity,
        'expiration_date': expirationDate?.toIso8601String(),
      });
      await load();
    } on DioException catch (e) {
      state = state.copyWith(error: _message(e));
      rethrow;
    }
  }

  Future<void> remove(int id) async {
    try {
      await ApiClient.dio.delete('/pantry/$id');
      final items = state.items.where((e) => e.id != id).toList();
      state = PantryState(items: items);
    } on DioException catch (e) {
      state = state.copyWith(error: _message(e));
    }
  }

  // Passo de incremento/decremento baseado na unidade de medida
  static double step(String unit) {
    switch (unit.toLowerCase()) {
      case 'kg':
      case 'litro':
        return 0.5;
      case 'g':
      case 'ml':
        return 100.0;
      case 'unidade':
      case 'pacote':
      case 'lata':
      case 'garrafa':
      default:
        return 1.0;
    }
  }

  static String format(double quantity, String unit) {
    final u = unit.toLowerCase();
    if (u == 'kg' || u == 'litro') {
      return '${quantity.toStringAsFixed(1)} $unit';
    } else if (u == 'g' || u == 'ml') {
      return '${quantity.toStringAsFixed(0)} $unit';
    } else {
      return '${quantity.toStringAsFixed(0)} ${quantity == 1 ? unit : '$unit(s)'}';
    }
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'] as String;
    return 'Não foi possível processar a operação.';
  }
}

final pantryControllerProvider =
    StateNotifierProvider<PantryController, PantryState>((ref) {
  return PantryController();
});