import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/shopping_list_item.dart';

class ShoppingState {
  final List<ShoppingListItem> items;
  final bool loading;
  final String? error;

  const ShoppingState({
    this.items = const [],
    this.loading = false,
    this.error,
  });

  ShoppingState copyWith({
    List<ShoppingListItem>? items,
    bool? loading,
    String? error,
  }) =>
      ShoppingState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        error: error,
      );

  int get checkedCount => items.where((e) => e.isChecked).length;
}

class ShoppingController extends StateNotifier<ShoppingState> {
  ShoppingController() : super(const ShoppingState());

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final response = await ApiClient.dio.get('/shopping-list');
      final items = (response.data['items'] as List)
          .map((e) => ShoppingListItem.fromJson(e as Map<String, dynamic>))
          .toList();
      state = ShoppingState(items: items);
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _message(e));
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Erro ao carregar a lista de compras.');
    }
  }

  Future<void> sync() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final response = await ApiClient.dio.post('/shopping-list/sync');
      final items = (response.data['items'] as List)
          .map((e) => ShoppingListItem.fromJson(e as Map<String, dynamic>))
          .toList();
      state = ShoppingState(items: items);
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _message(e));
    }
  }

  Future<void> toggle(ShoppingListItem item) async {
    final newValue = !item.isChecked;
    state = ShoppingState(
      items: state.items
          .map((e) => e.id == item.id ? e.copyWith(isChecked: newValue) : e)
          .toList(),
    );
    try {
      await ApiClient.dio.patch('/shopping-list/${item.id}', data: {
        'is_checked': newValue,
      });
    } on DioException catch (e) {
      state = state.copyWith(error: _message(e));
    }
  }

  Future<void> remove(ShoppingListItem item) async {
    try {
      await ApiClient.dio.delete('/shopping-list/${item.id}');
      state = ShoppingState(
        items: state.items.where((e) => e.id != item.id).toList(),
      );
    } on DioException catch (e) {
      state = state.copyWith(error: _message(e));
    }
  }

  Future<int> buySelected() async {
    try {
      await ApiClient.dio.post('/shopping-list/buy');
      await load();
      return 0;
    } on DioException catch (e) {
      state = state.copyWith(error: _message(e));
      rethrow;
    }
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'] as String;
    return 'Erro na lista de compras.';
  }
}

final shoppingControllerProvider =
    StateNotifierProvider<ShoppingController, ShoppingState>((ref) {
  return ShoppingController();
});