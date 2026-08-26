import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/features/search/application/controller.dart';
import 'package:ritual_investing_app/features/search/data/repository.dart';
import 'package:ritual_investing_app/features/search/domain/model.dart';

void main() {
  test('requires two characters and cancels a stale debounce', () async {
    final service = _SearchService();
    final controller = SearchController(
      repository: SearchRepository(service: service),
      debounce: const Duration(milliseconds: 10),
    );

    controller.updateQuery('v');
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(service.requests, isEmpty);

    controller.updateQuery('vi');
    controller.updateQuery('vig');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(service.requests.map((request) => request.context.query), ['vig']);
    expect(controller.state.value!.items.single.title, 'VIG');
  });

  test(
    'cursor pagination is scoped and a filter change cancels the stale page',
    () async {
      final service = _SearchService(delayPage: true);
      final controller = SearchController(
        repository: SearchRepository(service: service),
        debounce: Duration.zero,
      );
      controller.updateQuery('quiet');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final page = controller.loadMore();
      controller.updateKinds(const {SearchKind.coven});
      await Future<void>.delayed(Duration.zero);
      service.releasePage();
      await page;
      await Future<void>.delayed(Duration.zero);

      expect(service.cancellations, 1);
      expect(controller.context.kinds, const {SearchKind.coven});
      expect(
        controller.state.value?.items.every(
          (item) => item.kind == SearchKind.coven,
        ),
        isTrue,
      );
    },
  );

  test('429 carries Retry-After into a visible throttled state', () async {
    final service = _SearchService(throttled: true);
    final controller = SearchController(
      repository: SearchRepository(service: service),
      debounce: Duration.zero,
    );

    controller.updateQuery('quiet');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.phase, LoadPhase.throttled);
    expect(controller.retryAfter, const Duration(seconds: 12));
  });
}

class _SearchService implements SearchService {
  _SearchService({this.delayPage = false, this.throttled = false});

  final bool delayPage;
  final bool throttled;
  final List<SearchRequest> requests = [];
  Completer<void>? _pageGate;
  int cancellations = 0;

  @override
  Future<SearchPage> search(SearchRequest request) async {
    requests.add(request);
    request.cancellation.whenCancelled.then((_) => cancellations += 1);
    if (throttled) throw const SearchRateLimited(Duration(seconds: 12));
    if (request.cursor != null && delayPage) {
      _pageGate = Completer<void>();
      await _pageGate!.future;
    }
    final kind = request.context.kinds.singleOrNull ?? SearchKind.asset;
    return SearchPage(
      items: [
        SearchItem(
          id: kind == SearchKind.asset
              ? '00000000-0000-4000-8000-000000000201'
              : '00000000-0000-4000-8000-000000000301',
          revisionId: '00000000-0000-4000-8000-000000000302',
          kind: kind,
          title: kind == SearchKind.asset ? 'VIG' : 'Quiet Coven',
          subtitle: 'Provider-free Demo result',
          symbol: kind == SearchKind.asset ? 'VIG' : null,
          isDemo: true,
        ),
      ],
      nextCursor: request.cursor == null ? 'opaque-cursor-for-next-page' : null,
      hasMore: request.cursor == null,
    );
  }

  void releasePage() => _pageGate?.complete();
}
