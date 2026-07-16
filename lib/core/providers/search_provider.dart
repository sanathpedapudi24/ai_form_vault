import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/search_service.dart';
import 'document_provider.dart';
import 'service_providers.dart';

class SearchState {
  final String query;
  final List<SearchResult> results;
  final bool searching;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.searching = false,
  });

  SearchState copyWith({
    String? query,
    List<SearchResult>? results,
    bool? searching,
  }) => SearchState(
    query: query ?? this.query,
    results: results ?? this.results,
    searching: searching ?? this.searching,
  );
}

/// Debounced hybrid search over the vault.
class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._ref) : super(const SearchState());

  final Ref _ref;
  Timer? _debounce;
  int _generation = 0;

  void onQueryChanged(String query) {
    state = state.copyWith(query: query, searching: query.trim().isNotEmpty);
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      state = state.copyWith(results: [], searching: false);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(query));
  }

  Future<void> _run(String query) async {
    final generation = ++_generation;
    final docs = _ref.read(documentsProvider);
    final results = await _ref.read(searchServiceProvider).search(query, docs);
    if (generation != _generation || !mounted) return;
    state = state.copyWith(
      results: results,
      searching: false,
    );
  }

  void clear() {
    _debounce?.cancel();
    state = const SearchState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>(
  (ref) => SearchNotifier(ref),
);
