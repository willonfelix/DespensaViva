import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/category.dart';

class CatalogState {
  final List<Category> categories;
  final List<String> units;
  final bool loading;
  final String? error;

  const CatalogState({
    this.categories = const [],
    this.units = const ['kg', 'g', 'litro', 'ml', 'unidade', 'pacote', 'lata', 'garrafa'],
    this.loading = false,
    this.error,
  });

  CatalogState copyWith({
    List<Category>? categories,
    List<String>? units,
    bool? loading,
    String? error,
  }) =>
      CatalogState(
        categories: categories ?? this.categories,
        units: units ?? this.units,
        loading: loading ?? this.loading,
        error: error,
      );
}

class CatalogController extends StateNotifier<CatalogState> {
  CatalogController() : super(const CatalogState());

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await Future.wait([
        ApiClient.dio.get('/products/categories'),
        ApiClient.dio.get('/products/units'),
      ]);
      final categories = (result[0].data['categories'] as List)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
      final units = (result[1].data['units'] as List)
          .map((e) => e.toString())
          .toList();
      state = CatalogState(categories: categories, units: units);
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _message(e));
    }
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'] as String;
    return 'Erro ao carregar catálogo.';
  }
}

final catalogControllerProvider =
    StateNotifierProvider<CatalogController, CatalogState>((ref) {
  return CatalogController();
});