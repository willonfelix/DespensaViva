import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pantry_item.dart';
import '../../models/pending_change.dart';
import '../../core/network/api_client.dart';

class PantryState {
  final List<PantryItem> items;
  final List<PendingChange> pending;
  final bool loading;
  final String? error;

  const PantryState({
    this.items = const [],
    this.pending = const [],
    this.loading = false,
    this.error,
  });

  int get pendingCount => pending.length;

  PantryState copyWith({
    List<PantryItem>? items,
    List<PendingChange>? pending,
    bool? loading,
    String? error,
  }) =>
      PantryState(
        items: items ?? this.items,
        pending: pending ?? this.pending,
        loading: loading ?? this.loading,
        error: error,
      );
}

class PantryController extends StateNotifier<PantryState> {
  PantryController() : super(const PantryState());

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final itemsResponse = await ApiClient.dio.get('/pantry');
      final pendingResponse = await ApiClient.dio.get('/pantry/pending');
      final items = (itemsResponse.data['items'] as List)
          .map((e) => PantryItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final pending = (pendingResponse.data['pending'] as List)
          .map((e) => PendingChange.fromJson(e as Map<String, dynamic>))
          .toList();
      state = PantryState(items: items, pending: pending);
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _message(e));
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Erro ao carregar a dispensa.');
    }
  }

  Future<void> increment(PantryItem item) async {
    await _stageQuantity(item, _baseQuantity(item) + step(item.unitOfMeasure));
  }

  Future<void> decrement(PantryItem item) async {
    final base = _baseQuantity(item);
    final newQuantity =
        (base - step(item.unitOfMeasure)).clamp(0, double.infinity).toDouble();
    await _stageQuantity(item, newQuantity);
  }

  // Base do cálculo: usa a pendência já existente do item (se houver),
  // acumulando múltiplos incrementos/decrementos antes da confirmação.
  // Sem isso, a base vira sempre o estoque atual do servidor (que só muda
  // após confirmar) e o 2º clique num item não faz efeito.
  double _baseQuantity(PantryItem item) {
    for (final p in state.pending) {
      if (p.pantryItemId == item.id) return p.newQuantity;
    }
    return item.quantity;
  }

  Future<void> _stageQuantity(PantryItem item, double newQuantity) async {
    state = state.copyWith(error: null);
    _applyPendingLocally(item, newQuantity);
    try {
      await ApiClient.dio.post('/pantry/${item.id}/stage', data: {
        'quantity': newQuantity,
      });
      _applyPendingLocally(item, newQuantity);
    } on DioException catch (e) {
      state = state.copyWith(error: _message(e));
    } finally {
      await load();
    }
  }

  // Atualiza a pendência local otimisticamente, dando feedback imediato
  // (badge) e tornando cada novo clique acumulativo sobre o estado local.
  // O load() em _stageQuantity reconciltia com o servidor (fonte da verdade).
  void _applyPendingLocally(PantryItem item, double newQuantity) {
    final itemId = item.id;
    final others = state.pending.where((p) => p.pantryItemId != itemId).toList();

    // Voltou ao valor atual do estoque -> pendência deixa de existir.
    if (newQuantity == item.quantity) {
      state = state.copyWith(pending: others);
      return;
    }

    final existing = state.pending.firstWhere(
      (p) => p.pantryItemId == itemId,
      orElse: () => PendingChange(
        id: 0,
        pantryItemId: itemId,
        name: item.name,
        unitOfMeasure: item.unitOfMeasure,
        currentQuantity: item.quantity,
        newQuantity: newQuantity,
      ),
    );

    state = state.copyWith(
      pending: [
        ...others,
        existing.id != 0
            ? PendingChange(
                id: existing.id,
                pantryItemId: existing.pantryItemId,
                name: existing.name,
                unitOfMeasure: existing.unitOfMeasure,
                currentQuantity: existing.currentQuantity,
                newQuantity: newQuantity,
              )
            : existing,
      ],
    );
  }

  Future<bool> confirmPending() async {
    state = state.copyWith(error: null);
    try {
      await ApiClient.dio.post('/pantry/confirm');
      await load();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _message(e));
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Erro ao confirmar alterações.');
      return false;
    }
  }

  Future<bool> cancelPending(int id) async {
    state = state.copyWith(error: null);
    try {
      await ApiClient.dio.delete('/pantry/pending/$id');
      await load();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _message(e));
      return false;
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