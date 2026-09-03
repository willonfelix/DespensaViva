import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/product_suggestion.dart';

enum ScanSource { camera, manual }

class BarcodeState {
  final bool searching;
  final bool searched;
  final ProductSuggestion? suggestion;
  final String? error;
  final ScanSource? source;

  const BarcodeState({
    this.searching = false,
    this.searched = false,
    this.suggestion,
    this.error,
    this.source,
  });

  BarcodeState copyWith({
    bool? searching,
    bool? searched,
    ProductSuggestion? suggestion,
    String? error,
    ScanSource? source,
  }) =>
      BarcodeState(
        searching: searching ?? this.searching,
        searched: searched ?? this.searched,
        suggestion: suggestion ?? this.suggestion,
        error: error,
        source: source ?? this.source,
      );
}

class BarcodeController extends StateNotifier<BarcodeState> {
  BarcodeController() : super(const BarcodeState());

  Future<bool> searchByCode(String code, {ScanSource source = ScanSource.manual}) async {
    final normalized = code.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) {
      state = BarcodeState(
        searched: true,
        error: 'Digite um código de barras válido.',
        source: source,
      );
      return false;
    }

    state = state.copyWith(searching: true, searched: false, error: null, source: source);
    try {
      final response = await ApiClient.dio.get('/barcode/$normalized');
      final suggestion =
          ProductSuggestion.fromJson(response.data['product'] as Map<String, dynamic>);
      state = BarcodeState(
        searching: false,
        searched: true,
        suggestion: suggestion,
        source: source,
      );
      return true;
    } on DioException catch (e) {
      state = BarcodeState(
        searching: false,
        searched: true,
        error: _message(e),
        source: source,
      );
      return false;
    } catch (_) {
      state = BarcodeState(
        searching: false,
        searched: true,
        error: 'Erro inesperado ao buscar o produto.',
        source: source,
      );
      return false;
    }
  }

  void clear() => state = const BarcodeState();

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'] as String;
    return 'Não foi possível buscar o produto.';
  }
}

final barcodeControllerProvider =
    StateNotifierProvider<BarcodeController, BarcodeState>((ref) {
  return BarcodeController();
});
