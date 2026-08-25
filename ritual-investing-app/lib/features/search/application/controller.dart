// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/view_state.dart';
import '../data/repository.dart';
import '../domain/model.dart';

class SearchController extends ChangeNotifier {
  SearchController({
    required SearchRepository repository,
    this.debounce = const Duration(milliseconds: 300),
  }) : _repository = repository;

  final SearchRepository _repository;
  final Duration debounce;
  SearchContext _context = SearchContext(
    query: '',
    kinds: SearchKind.values.toSet(),
  );
  ViewState<SearchPage> _state = const ViewState(phase: LoadPhase.idle);
  Duration? _retryAfter;
  Timer? _timer;
  SearchCancellation? _activeCancellation;
  int _generation = 0;
  bool _loadingMore = false;

  SearchContext get context => _context;
  ViewState<SearchPage> get state => _state;
  Duration? get retryAfter => _retryAfter;
  bool get loadingMore => _loadingMore;

  void updateQuery(String value) =>
      _replaceContext(SearchContext(query: value, kinds: _context.kinds));

  void updateKinds(Set<SearchKind> value) =>
      _replaceContext(SearchContext(query: _context.query, kinds: value));

  void _replaceContext(SearchContext next) {
    _timer?.cancel();
    _activeCancellation?.cancel();
    _activeCancellation = null;
    _generation += 1;
    _context = next;
    _retryAfter = null;
    _loadingMore = false;
    if (next.query.runes.length < 2) {
      _state = const ViewState(phase: LoadPhase.idle);
      notifyListeners();
      return;
    }
    _state = const ViewState(phase: LoadPhase.loading);
    notifyListeners();
    final generation = _generation;
    _timer = Timer(debounce, () => unawaited(_load(generation, null)));
  }

  Future<void> loadMore() async {
    final page = _state.value;
    if (_loadingMore ||
        page == null ||
        !page.hasMore ||
        page.nextCursor == null) {
      return;
    }
    _loadingMore = true;
    notifyListeners();
    await _load(_generation, page.nextCursor);
  }

  Future<void> retry() => _load(_generation, null);

  Future<void> _load(int generation, String? cursor) async {
    final cancellation = SearchCancellation();
    _activeCancellation?.cancel();
    _activeCancellation = cancellation;
    final requestContext = _context;
    try {
      final page = await _repository.search(
        SearchRequest(
          context: requestContext,
          cursor: cursor,
          cancellation: cancellation,
        ),
      );
      if (generation != _generation ||
          requestContext != _context ||
          cancellation.isCancelled) {
        return;
      }
      if (cursor == null) {
        _state = ViewState(
          phase: page.items.isEmpty ? LoadPhase.empty : LoadPhase.ready,
          value: page,
        );
      } else {
        final previous = _state.value!;
        _state = ViewState(
          phase: LoadPhase.ready,
          value: SearchPage(
            items: [...previous.items, ...page.items],
            nextCursor: page.nextCursor,
            hasMore: page.hasMore,
          ),
        );
      }
    } on SearchCancelled {
      // Superseded query/page responses never replace the current context.
    } on SearchRateLimited catch (failure) {
      if (generation == _generation) {
        _retryAfter = failure.retryAfter;
        _state = const ViewState(phase: LoadPhase.throttled);
      }
    } on LoadFailure catch (failure) {
      if (generation == _generation) {
        _state = ViewState(phase: failure.phase);
      }
    } finally {
      if (identical(_activeCancellation, cancellation)) {
        _activeCancellation = null;
      }
      if (generation == _generation) {
        _loadingMore = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _activeCancellation?.cancel();
    super.dispose();
  }
}
