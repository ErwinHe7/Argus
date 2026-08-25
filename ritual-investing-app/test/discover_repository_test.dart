import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/discover/application/controller.dart';
import 'package:ritual_investing_app/features/discover/data/repository.dart';
import 'package:ritual_investing_app/features/discover/domain/model.dart';

void main() {
  test('mixed Discover preserves all four kinds in server priority order', () async {
    final controller = DiscoverController(
      repository: CachedDiscoverRepository(
        service: _MixedDiscoverService(),
        cache: MemoryReadCache(),
      ),
      personalization: const MemberPersonalization(
        explanationDepth: MemberExplanationDepth.beginner,
        ritualVoice: MemberRitualVoice.practical,
        riskFraming: MemberRiskFraming.low,
      ),
    );

    await controller.load();

    expect(
      controller.state.value!.items.map((item) => item.kind),
      const [
        DiscoverItemKind.asset,
        DiscoverItemKind.grimoire,
        DiscoverItemKind.circleTemplate,
        DiscoverItemKind.coven,
      ],
    );
    expect(controller.lead.id, _assetId);
    expect(controller.personalization.riskFraming, MemberRiskFraming.low);
    expect(controller.personalization.explanationDepth, MemberExplanationDepth.beginner);
    expect(controller.personalization.ritualVoice, MemberRitualVoice.practical);
    expect(controller.state.value!.items.every((item) => item.demo.isDemo), isTrue);
    expect(controller.state.value!.items[1].revisionId, _grimoireRevisionId);
    expect(controller.state.value!.items[2].creator!.isFictional, isTrue);
  });

  test('offline Discover restores a stale account-scoped mixed feed', () async {
    final cache = MemoryReadCache();
    final first = CachedDiscoverRepository(
      service: _MixedDiscoverService(),
      cache: cache,
    );
    await first.load();
    final offline = CachedDiscoverRepository(
      service: _OfflineDiscoverService(),
      cache: cache,
    );

    final restored = await offline.load();

    expect(restored.isStale, isTrue);
    expect(restored.value.items.first.id, _assetId);
    expect(restored.value.items.last.kind, DiscoverItemKind.coven);
  });

  test('generated Dio adapter decodes the complete mixed contract', () async {
    final client = RitualInvestingApiClient(
      basePathOverride: 'https://api.ritual-investing.invalid',
    );
    final adapter = _DiscoverJsonAdapter();
    client.dio.httpClientAdapter = adapter;

    final result = await GeneratedDiscoverApiService(client).fetch();

    expect(adapter.paths, ['/v1/discover', '/v1/community/creators']);
    expect(result.items.map((item) => item.kind), [
      DiscoverItemKind.asset,
      DiscoverItemKind.grimoire,
      DiscoverItemKind.circleTemplate,
      DiscoverItemKind.coven,
    ]);
    expect(result.items.first.id, _assetId);
    expect(result.items[1].revisionId, _grimoireRevisionId);
    expect(result.items[2].creator?.displayName, 'Mira Vale');
    expect(result.items[3].subtitle, contains('Woman founder'));
    expect(result.creators.single.isFictional, isTrue);
    expect(result.nextCursor, 'next-mixed');
    expect(result.hasMore, isTrue);
  });

  test('generated Discover rejects a seeded creator that is not fictional', () async {
    final client = RitualInvestingApiClient(
      basePathOverride: 'https://api.ritual-investing.invalid',
    );
    client.dio.httpClientAdapter = _DiscoverJsonAdapter(isFictional: false);

    await expectLater(
      GeneratedDiscoverApiService(client).fetch(),
      throwsA(
        isA<LoadFailure>().having(
          (failure) => failure.phase,
          'phase',
          LoadPhase.terminalFailure,
        ),
      ),
    );
  });
}

const _assetId = '00000000-0000-4000-8000-000000000701';
const _grimoireId = '00000000-0000-4000-8000-000000000702';
const _grimoireRevisionId = '00000000-0000-4000-8000-000000000703';
const _templateId = '00000000-0000-4000-8000-000000000704';
const _covenId = '00000000-0000-4000-8000-000000000705';

class _MixedDiscoverService implements DiscoverService {
  @override
  Future<DiscoverModel> fetch() async => DiscoverModel(
    items: [
      DiscoverItemView(
        id: _assetId,
        revisionId: '00000000-0000-4000-8000-000000000706',
        slug: 'quiet-power-etf',
        kind: DiscoverItemKind.asset,
        title: 'Quiet Power ETF',
        subtitle: 'A lower-volatility provider-free scenario.',
        symbol: 'QPW',
        appearanceReason: 'Matches the server-personalized risk lens.',
        demo: _demo,
      ),
      DiscoverItemView(
        id: _grimoireId,
        revisionId: _grimoireRevisionId,
        slug: 'patient-compounding',
        kind: DiscoverItemKind.grimoire,
        title: 'Patient Compounding',
        subtitle: 'A fictional research path.',
        theme: 'durability',
        demo: _demo,
      ),
      DiscoverItemView(
        id: _templateId,
        revisionId: '00000000-0000-4000-8000-000000000707',
        slug: 'soft-power-circle',
        kind: DiscoverItemKind.circleTemplate,
        title: 'Soft Power Circle',
        subtitle: 'A read-only seeded example.',
        theme: 'leadership',
        creator: SeededCreatorView(
          id: '00000000-0000-4000-8000-000000000708',
          slug: 'mira-vale',
          displayName: 'Mira Vale',
          bio: 'Fictional Demo curator.',
          isFictional: true,
          demo: _demo,
        ),
        demo: _demo,
      ),
      DiscoverItemView(
        id: _covenId,
        revisionId: '00000000-0000-4000-8000-000000000709',
        slug: 'aurora-healthworks',
        kind: DiscoverItemKind.coven,
        title: 'Aurora Healthworks',
        subtitle: 'Woman founder · verified Demo evidence.',
        symbol: 'AUR',
        demo: _demo,
      ),
    ],
    creators: const [],
    nextCursor: null,
    hasMore: false,
  );
}

class _OfflineDiscoverService implements DiscoverService {
  @override
  Future<DiscoverModel> fetch() => Future.error(const OfflineException());
}

final _demo = ResearchDemoDisclosure(
  isDemo: true,
  observedAt: DateTime.utc(2026, 8, 25, 12),
  sourceLabel: 'Deterministic research fixture',
  limitations: const ['Fictional scenario; no live market provider.'],
);

class _DiscoverJsonAdapter implements HttpClientAdapter {
  _DiscoverJsonAdapter({this.isFictional = true});

  final bool isFictional;
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    final creator = {..._creatorJson, 'is_fictional': isFictional};
    final data = options.path == '/v1/community/creators'
        ? {
            'data': [creator],
            'meta': _meta(hasMore: false, nextCursor: null),
          }
        : {
            'data': [
              {'kind': 'asset', 'asset': _assetJson},
              {'kind': 'grimoire', 'grimoire': _grimoireJson},
              {
                'kind': 'circle_template',
                'circle_template': {..._templateJson, 'creator': creator},
              },
              {'kind': 'coven', 'coven': _covenJson},
            ],
            'meta': _meta(hasMore: true, nextCursor: 'next-mixed'),
          };
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> get _demoJson => {
  'is_demo': true,
  'observed_at': '2026-08-25T12:00:00.000Z',
  'source_label': 'Deterministic research fixture',
  'limitations': ['Fictional scenario; no live market provider.'],
};

Map<String, Object?> get _creatorJson => {
  'id': '00000000-0000-4000-8000-000000000708',
  'slug': 'mira-vale',
  'display_name': 'Mira Vale',
  'bio': 'Fictional Demo curator.',
  'is_fictional': true,
  'demo': _demoJson,
};

Map<String, Object?> get _assetJson => {
  'id': _assetId,
  'revision_id': '00000000-0000-4000-8000-000000000706',
  'slug': 'quiet-power-etf',
  'symbol': 'QPW',
  'name': 'Quiet Power ETF',
  'asset_type': 'etf',
  'currency': 'USD',
  'appearance_reason': 'Matches the server-personalized risk lens.',
  'demo': _demoJson,
};

Map<String, Object?> get _grimoireJson => {
  'id': _grimoireId,
  'revision_id': _grimoireRevisionId,
  'slug': 'patient-compounding',
  'title': 'Patient Compounding',
  'description': 'A fictional research path.',
  'theme': 'durability',
  'curator_label': 'Ritual Research Desk',
  'demo': _demoJson,
};

Map<String, Object?> get _templateJson => {
  'id': _templateId,
  'revision_id': '00000000-0000-4000-8000-000000000707',
  'slug': 'soft-power-circle',
  'title': 'Soft Power Circle',
  'description': 'A read-only seeded example.',
  'theme': 'leadership',
  'creator': _creatorJson,
  'demo': _demoJson,
};

Map<String, Object?> get _covenJson => {
  'id': _covenId,
  'revision_id': '00000000-0000-4000-8000-000000000709',
  'slug': 'aurora-healthworks',
  'company': 'Aurora Healthworks',
  'symbol': 'AUR',
  'focus': 'Preventive care',
  'category': 'founder',
  'effective_date': '2026-08-01',
  'verified_as_of': '2026-08-25T12:00:00.000Z',
  'teaser': 'Verified Demo evidence.',
  'demo': _demoJson,
};

Map<String, Object?> _meta({
  required bool hasMore,
  required String? nextCursor,
}) => {
  'has_more': hasMore,
  'next_cursor': nextCursor,
  'request_id': 'request-u5',
};
