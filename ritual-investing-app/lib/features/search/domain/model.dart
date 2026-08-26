import 'dart:async';

import 'package:flutter/foundation.dart';

enum SearchKind { asset, coven, grimoire, circleTemplate }

@immutable
class SearchContext {
  SearchContext({required String query, required Set<SearchKind> kinds})
    : query = query.trim(),
      kinds = Set.unmodifiable(kinds);

  final String query;
  final Set<SearchKind> kinds;

  @override
  bool operator ==(Object other) =>
      other is SearchContext &&
      other.query == query &&
      setEquals(other.kinds, kinds);

  @override
  int get hashCode => Object.hash(
    query,
    Object.hashAll(kinds.map((kind) => kind.index).toList()..sort()),
  );
}

@immutable
class SearchItem {
  const SearchItem({
    required this.id,
    required this.revisionId,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.symbol,
    required this.isDemo,
    this.observedAt,
  });

  final String id;
  final String revisionId;
  final SearchKind kind;
  final String title;
  final String subtitle;
  final String? symbol;
  final bool isDemo;
  final DateTime? observedAt;
}

@immutable
class SearchPage {
  SearchPage({
    required List<SearchItem> items,
    required this.nextCursor,
    required this.hasMore,
  }) : items = List.unmodifiable(items);

  final List<SearchItem> items;
  final String? nextCursor;
  final bool hasMore;
}

class SearchCancellation {
  final Completer<void> _cancelled = Completer<void>();

  Future<void> get whenCancelled => _cancelled.future;
  bool get isCancelled => _cancelled.isCompleted;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

@immutable
class SearchRequest {
  const SearchRequest({
    required this.context,
    required this.cursor,
    required this.cancellation,
  });

  final SearchContext context;
  final String? cursor;
  final SearchCancellation cancellation;
}

class SearchRateLimited implements Exception {
  const SearchRateLimited(this.retryAfter);

  final Duration retryAfter;
}

class SearchCancelled implements Exception {
  const SearchCancelled();
}
