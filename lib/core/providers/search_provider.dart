import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ask_engine.dart';
import '../services/search_service.dart';
import 'document_provider.dart';
import 'person_provider.dart';
import 'service_providers.dart';

class SearchState {
  final String query;
  final List<SearchResult> results;
  final bool searching;

  /// A direct answer when the query reads as a question (shown above results).
  final AskResult? answer;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.searching = false,
    this.answer,
  });

  SearchState copyWith({
    String? query,
    List<SearchResult>? results,
    bool? searching,
    AskResult? answer,
    bool clearAnswer = false,
  }) => SearchState(
    query: query ?? this.query,
    results: results ?? this.results,
    searching: searching ?? this.searching,
    answer: clearAnswer ? null : (answer ?? this.answer),
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
      state = const SearchState();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(query));
  }

  Future<void> _run(String query) async {
    final generation = ++_generation;
    final docs = _ref.read(documentsProvider);
    // A direct answer (if the query is a question) and ranked results run
    // together — both are on-device and cheap.
    final answer = await _ref
        .read(askEngineProvider)
        .ask(query, docs);
    final graph = _ref.read(identityGraphProvider);
    final results = await _ref.read(searchServiceProvider).search(
      query,
      docs,
      persons: graph.persons,
      rels: graph.relationships,
    );
    if (generation != _generation || !mounted) return;
    state = SearchState(
      query: query,
      results: results,
      searching: false,
      answer: answer,
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
