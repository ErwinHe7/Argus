import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/features/asset_codex/data/generated_asset_codex_api_service.dart';
import 'package:ritual_investing_app/features/asset_codex/domain/model.dart';
import 'package:ritual_investing_app/features/briefings/data/generated_briefing_api_service.dart';
import 'package:ritual_investing_app/features/circles/data/generated_circle_api_service.dart';
import 'package:ritual_investing_app/features/circles/domain/model.dart';
import 'package:ritual_investing_app/features/coven/data/generated_coven_api_service.dart';
import 'package:ritual_investing_app/features/creators/data/generated_creator_api_service.dart';
import 'package:ritual_investing_app/features/discover/data/generated_discover_api_service.dart';
import 'package:ritual_investing_app/features/grimoires/data/generated_grimoire_api_service.dart';
import 'package:ritual_investing_app/features/search/data/generated_search_api_service.dart';
import 'package:ritual_investing_app/features/search/domain/model.dart';
import 'package:ritual_investing_app/features/starpath/data/generated_starpath_api_service.dart';
import 'package:ritual_investing_app/features/starpath/data/starpath_repository.dart';

void main() {
  test('retained content adapters decode the current typed client', () async {
    final adapter = _ContentAdapter();
    final client = _client(adapter);

    final asset = await GeneratedAssetCodexService(client)
        .fetchDetail(_assetId);
    final assetEvidence = await GeneratedAssetCodexService(client)
        .fetchEvidence(_assetId);
    final briefing = await GeneratedBriefingService(client).get(_briefingId);
    final template = await GeneratedCircleService(client)
        .fetchTemplate(_templateId);
    final coven = await GeneratedCovenApiService(client).fetchDetail(_covenId);
    final covenEvidence = await GeneratedCovenApiService(client)
        .fetchEvidence(_covenId);
    final creator = await GeneratedCreatorService(client).fetchById(_creatorId);
    final discover = await GeneratedDiscoverApiService(client).fetch();
    final grimoire = await GeneratedGrimoireService(client)
        .fetchDetail(_grimoireId);
    final search = await GeneratedSearchService(client).search(
      SearchRequest(
        context: SearchContext(query: 'quiet', kinds: const {}),
        cursor: null,
        cancellation: SearchCancellation(),
      ),
    );
    final starpath = await GeneratedStarpathApiService(client).fetch();

    expect(asset.kind, AssetKind.marketIndex);
    expect(assetEvidence.single.sourceUrl.scheme, 'https');
    expect(briefing.sections.single.sourceSequence, 14);
    expect(template.creator.isFictional, isTrue);
    expect(coven.symbol, isNull);
    expect(covenEvidence.single.publisher, 'Demo Registry');
    expect(creator.id, _creatorId);
    expect(discover.items, hasLength(4));
    expect(grimoire.assets.single.id, _assetId);
    expect(search.items.single.id, _assetId);
    expect(starpath.nodes, hasLength(8));

    expect(
      adapter.requests.map((request) => request.path),
      containsAll([
        '/v1/assets/$_assetId',
        '/v1/assets/$_assetId/evidence',
        '/v1/briefings/$_briefingId',
        '/v1/discover/circle-templates/$_templateId',
        '/v1/coven/$_covenId',
        '/v1/coven/$_covenId/evidence',
        '/v1/discover/creators/$_creatorId',
        '/v1/discover/creators',
        '/v1/discover',
        '/v1/discover/grimoires/$_grimoireId',
        '/v1/search',
        '/v1/starpath',
      ]),
    );
    final searchRequest = adapter.single('GET', '/v1/search');
    expect(
      searchRequest.query['kinds'],
      'asset,circle_template,coven,grimoire',
    );
  });

  test('creator lookup uses the typed point endpoint', () async {
    final adapter = _ContentAdapter();
    final creator = await GeneratedCreatorService(_client(adapter))
        .fetchById(_creatorId);

    expect(creator.id, _creatorId);
    final request = adapter.single('GET', '/v1/discover/creators/$_creatorId');
    expect(request.query, isEmpty);
  });

  test('retained saves and copy use the current generated commands', () async {
    final adapter = _ContentAdapter();
    final client = _client(adapter);

    await GeneratedAssetCodexService(client).save(
      _assetId,
      const AssetSourceContext(
        kind: AssetSourceKind.search,
        resourceId: _searchSourceId,
      ),
    );
    await GeneratedCovenApiService(client).save(_covenId);
    await GeneratedGrimoireService(client).save(_grimoireId);
    await GeneratedCircleService(client).saveTemplate(_templateId);
    final copied = await GeneratedCircleService(client).copy(
      const CircleCopyCommand(
        idempotencyKey: 'retained-copy-key',
        templateId: _templateId,
        title: 'My retained circle',
      ),
    );

    expect(copied.sourceTemplateId, _templateId);
    final assetSave = adapter.single('POST', '/v1/saved/asset/$_assetId');
    expect(assetSave.body, {
      'source_id': _searchSourceId,
      'source_kind': 'search',
    });
    expect(adapter.single('POST', '/v1/saved/coven/$_covenId').body, isEmpty);
    expect(
      adapter.single('POST', '/v1/saved/grimoire/$_grimoireId').body,
      isEmpty,
    );
    expect(
      adapter.single('POST', '/v1/saved/circle_template/$_templateId').body,
      isEmpty,
    );
    final copy = adapter.single(
      'POST',
      '/v1/circle-templates/$_templateId/copy',
    );
    expect(copy.header('Idempotency-Key'), 'retained-copy-key');
    expect(copy.body, {'title': 'My retained circle'});
  });

  test('nullable or insecure evidence links fail closed', () async {
    for (final sourceUrl in [null, 'http://example.invalid/evidence']) {
      final adapter = _ContentAdapter(evidenceUrl: sourceUrl);
      final client = _client(adapter);
      await expectLater(
        GeneratedAssetCodexService(client).fetchEvidence(_assetId),
        throwsA(_terminalFailure),
      );
      await expectLater(
        GeneratedCovenApiService(client).fetchEvidence(_covenId),
        throwsA(_terminalFailure),
      );
    }
  });

  test('unknown Starpath enum values fail closed after generated decoding', () {
    final service = GeneratedStarpathApiService(
      _client(_ContentAdapter(starpathAvailability: 'future_state')),
    );

    expect(service.fetch(), throwsA(isA<StarpathUnsupportedContract>()));
  });
}

RitualInvestingApiClient _client(HttpClientAdapter adapter) {
  final client = RitualInvestingApiClient(
    basePathOverride: 'https://api.ritual-investing.invalid',
  );
  client.dio.httpClientAdapter = adapter;
  return client;
}

final _terminalFailure = isA<LoadFailure>().having(
  (failure) => failure.phase,
  'phase',
  LoadPhase.terminalFailure,
);

const _assetId = '00000000-0000-4000-8000-000000000701';
const _briefingId = '00000000-0000-4000-8000-000000000702';
const _templateId = '00000000-0000-4000-8000-000000000703';
const _covenId = '00000000-0000-4000-8000-000000000704';
const _creatorId = '00000000-0000-4000-8000-000000000705';
const _grimoireId = '00000000-0000-4000-8000-000000000706';
const _circleId = '00000000-0000-4000-8000-000000000707';
const _revisionId = '00000000-0000-4000-8000-000000000708';
const _claimId = '00000000-0000-4000-8000-000000000709';
const _searchSourceId = '00000000-0000-4000-8000-000000000710';
const _userId = '00000000-0000-4000-8000-000000000711';
const _requestId = '00000000-0000-4000-8000-000000000712';

class _Request {
  const _Request({
    required this.method,
    required this.path,
    required this.query,
    required this.headers,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, dynamic> query;
  final Map<String, dynamic> headers;
  final Map<String, dynamic> body;

  Object? header(String name) {
    final normalized = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == normalized) return entry.value;
    }
    return null;
  }
}

class _ContentAdapter implements HttpClientAdapter {
  _ContentAdapter({
    this.evidenceUrl = 'https://example.invalid/evidence',
    this.starpathAvailability = 'available',
  });

  final String? evidenceUrl;
  final String starpathAvailability;
  final List<_Request> requests = [];

  _Request single(String method, String path) => requests.singleWhere(
    (request) => request.method == method && request.path == path,
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = _body(options.data);
    requests.add(
      _Request(
        method: options.method,
        path: options.path,
        query: Map.of(options.queryParameters),
        headers: Map.of(options.headers),
        body: body,
      ),
    );
    final path = options.path;
    if (options.method == 'POST' && path.startsWith('/v1/saved/')) {
      return _json({
        'data': {'saved': true},
        'meta': _meta,
      });
    }
    if (options.method == 'POST' &&
        path == '/v1/circle-templates/$_templateId/copy') {
      return _json({
        'data': {
          ..._circle,
          'title': body['title'],
          'source_template_id': _templateId,
          'source_revision_id': _revisionId,
        },
        'meta': _meta,
      });
    }
    final response = switch (path) {
      '/v1/assets/$_assetId' => {'data': _assetDetail, 'meta': _meta},
      '/v1/assets/$_assetId/evidence' => {
        'data': [_evidence],
        'meta': _meta,
      },
      '/v1/briefings/$_briefingId' => {'data': _briefing, 'meta': _meta},
      '/v1/discover/circle-templates/$_templateId' => {
        'data': _template,
        'meta': _meta,
      },
      '/v1/coven/$_covenId' => {'data': _coven, 'meta': _meta},
      '/v1/coven/$_covenId/evidence' => {
        'data': [_evidence],
        'meta': _meta,
      },
      '/v1/discover/creators/$_creatorId' => {'data': _creator, 'meta': _meta},
      '/v1/discover/creators' => {
        'data': [_creator],
        'meta': _collectionMeta,
      },
      '/v1/discover' => {
        'data': [
          {'kind': 'asset', 'asset': _assetSummary},
          {'kind': 'grimoire', 'grimoire': _grimoireSummary},
          {'kind': 'circle_template', 'circle_template': _templateSummary},
          {'kind': 'coven', 'coven': _covenSummary},
        ],
        'meta': _collectionMeta,
      },
      '/v1/discover/grimoires/$_grimoireId' => {
        'data': _grimoire,
        'meta': _meta,
      },
      '/v1/search' => {
        'data': [
          {'kind': 'asset', 'asset': _assetSummary},
        ],
        'meta': _collectionMeta,
      },
      '/v1/starpath' => {
        'data': _starpathSnapshot(starpathAvailability),
        'meta': _meta,
      },
      _ => {
        'error': {'code': 'not_found', 'message': 'Not found.'},
      },
    };
    return _json(response, status: response.containsKey('error') ? 404 : 200);
  }

  Map<String, dynamic> _body(Object? value) => switch (value) {
    null => <String, dynamic>{},
    String text when text.isEmpty => <String, dynamic>{},
    String text => Map<String, dynamic>.from(jsonDecode(text) as Map),
    Map value => Map<String, dynamic>.from(value),
    _ => throw StateError('Unexpected request body.'),
  };

  ResponseBody _json(Map<String, Object?> value, {int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode(value),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  Map<String, Object?> get _evidence => {
    'claim_id': _claimId,
    'factor_label': 'Provider-neutral evidence',
    'observed_at': '2026-08-25T12:00:00.000Z',
    'summary': 'A deterministic research fixture.',
    'uncertainty': 'The fictional pattern can change.',
    'source': {
      'publisher': 'Demo Registry',
      'title': 'Retained evidence note',
      'url': evidenceUrl,
      'published_at': '2026-08-24T12:00:00.000Z',
    },
  };

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> get _demo => {
  'is_demo': true,
  'observed_at': '2026-08-25T12:00:00.000Z',
  'source_label': 'Deterministic retained fixture',
  'limitations': ['Fictional research; no brokerage provider data.'],
};

Map<String, Object?> get _assetSummary => {
  'id': _assetId,
  'revision_id': _revisionId,
  'slug': 'quiet-index',
  'symbol': 'QIX',
  'name': 'Quiet Index',
  'asset_type': 'market_index',
  'currency': 'USD',
  'appearance_reason': 'A provider-neutral research fixture.',
  'demo': _demo,
};

Map<String, Object?> get _assetDetail => {
  ..._assetSummary,
  'thesis': 'A fictional editorial thesis.',
  'limitations': 'Not investment advice.',
  'metrics_as_of': '2026-08-25T12:00:00.000Z',
  'evidence': [
    {
      'claim_id': _claimId,
      'factor_label': 'Provider-neutral evidence',
      'observed_at': '2026-08-25T12:00:00.000Z',
      'summary': 'A deterministic research fixture.',
      'uncertainty': 'The fictional pattern can change.',
    },
  ],
  'risks': [
    {
      'title': 'Scenario reversal',
      'detail': 'The fictional pattern can reverse.',
      'severity': 'high',
    },
  ],
  'saved': false,
};

Map<String, Object?> get _creator => {
  'id': _creatorId,
  'slug': 'mira-vale',
  'display_name': 'Mira Vale',
  'bio': 'Fictional research curator.',
  'is_fictional': true,
  'demo': _demo,
};

Map<String, Object?> get _templateSummary => {
  'id': _templateId,
  'revision_id': _revisionId,
  'slug': 'quiet-circle',
  'title': 'Quiet Circle',
  'description': 'A fictional editorial collection.',
  'theme': 'durability',
  'creator': _creator,
  'demo': _demo,
};

Map<String, Object?> get _template => {
  ..._templateSummary,
  'assets': [
    {..._assetSummary, 'ordinal': 1, 'note': null, 'weight_bps': 10000},
  ],
  'saved': false,
};

Map<String, Object?> get _covenSummary => {
  'id': _covenId,
  'revision_id': _revisionId,
  'slug': 'aurora-healthworks',
  'company': 'Aurora Healthworks',
  'symbol': null,
  'category': 'founder',
  'focus': 'Preventive care',
  'teaser': 'Dated fictional qualification evidence.',
  'effective_date': '2026-08-01T00:00:00.000Z',
  'verified_as_of': '2026-08-25T12:00:00.000Z',
  'demo': _demo,
};

Map<String, Object?> get _coven => {
  'id': _covenId,
  'revision_id': _revisionId,
  'slug': 'aurora-healthworks',
  'company': 'Aurora Healthworks',
  'symbol': null,
  'category': 'founder',
  'focus': 'Preventive care',
  'teaser': 'Dated fictional qualification evidence.',
  'effective_date': '2026-08-01T00:00:00.000Z',
  'verified_as_of': '2026-08-25T12:00:00.000Z',
  'summary': 'A fictional provider-neutral company profile.',
  'inclusion_rationale': 'Dated evidence is available.',
  'limitations': 'Not investment advice.',
  'qualifications': [
    {
      'category': 'founder',
      'person_name': 'Avery North',
      'effective_date': '2026-08-01T00:00:00.000Z',
      'verified_as_of': '2026-08-25T12:00:00.000Z',
      'valid_to': null,
      'evidence': [],
    },
  ],
  'evidence': [],
  'saved': false,
  'demo': _demo,
};

Map<String, Object?> get _grimoireSummary => {
  'id': _grimoireId,
  'revision_id': _revisionId,
  'slug': 'patient-compounding',
  'title': 'Patient Compounding',
  'description': 'A fictional research path.',
  'theme': 'durability',
  'curator_label': 'Ritual Research Desk',
  'demo': _demo,
};

Map<String, Object?> get _grimoire => {
  ..._grimoireSummary,
  'curator_label': 'Ritual Research Desk',
  'assets': [_assetSummary],
  'saved': false,
};

Map<String, Object?> get _briefing => {
  'id': _briefingId,
  'briefing_type': 'weekly',
  'period_start': '2026-08-18',
  'period_end': '2026-08-25',
  'generated_at': '2026-08-25T12:00:00.000Z',
  'generation': 1,
  'source_sequence': 14,
  'read_at': null,
  'sections': [
    {
      'ordinal': 1,
      'schema_version': 1,
      'source_sequence': 14,
      'disclosure': 'Recorded Demo reflection; not financial advice.',
    },
  ],
};

Map<String, Object?> get _circle => {
  'id': _circleId,
  'user_id': _userId,
  'deletion_epoch': 0,
  'title': 'Private research',
  'description': 'Visible only to the member.',
  'private': true,
  'version': 1,
  'assets': <Object?>[],
  'source_template_id': null,
  'source_revision_id': null,
  'archived_at': null,
};

const _meta = {'request_id': _requestId};
const _collectionMeta = {
  'request_id': _requestId,
  'has_more': false,
  'next_cursor': null,
};

Map<String, Object?> _starpathSnapshot(String availability) => {
  'availability': availability,
  'version': 1,
  'authority': {
    'capability_version': 7,
    'manifest_id': 'manifest-1',
    'manifest_version': 'starpath-beta-v1',
    'policy_version': 'starpath-no-advice-v1',
    'environment': 'beta',
    'jurisdiction': 'US',
  },
  'session': {
    'id': 'session-1',
    'state': 'active',
    'started_at': '2026-08-30T10:00:00.000Z',
    'last_action_at': '2026-08-30T10:01:00.000Z',
    'explicit_start': true,
    'replacement_of_session_id': null,
  },
  'theme': {
    'id': 'theme-1',
    'key': 'steady-orbit',
    'title': 'Steady orbit',
    'horoscope_frame': 'A memory frame, not a forecast.',
    'factual_focus': 'Learn what a share represents.',
    'accessible_label': 'A non-predictive celestial learning theme.',
  },
  'progress': {
    'current_node_ordinal': 1,
    'version': 1,
    'updated_at': '2026-08-30T10:01:00.000Z',
  },
  'nodes': List.generate(8, (index) {
    final ordinal = index + 1;
    return {
      'node_ordinal': ordinal,
      'pathway_ordinal': (index ~/ 2) + 1,
      'pathway_position': (index % 2) + 1,
      'state': index == 0 ? 'current' : 'locked',
      'lesson_id': 'lesson-$ordinal',
      'revision_id': 'revision-$ordinal',
      'title': 'Lesson $ordinal',
      'guide': {
        'tarot_key': 'the-star',
        'accessible_label': 'The Star as a memory aid, not market evidence.',
      },
      'mythic_mnemonic': 'A celestial mnemonic.',
      'factual_summary': 'A factual investment definition.',
      'factual_sections': [
        {
          'ordinal': 1,
          'kind': 'fact',
          'heading': 'Definition',
          'body': 'Common stock generally represents an ownership interest.',
          'uncertainty': 'Rights vary by security and governing documents.',
          'observed_at': '2026-08-29T00:00:00.000Z',
          'evidence': [
            {
              'ordinal': 1,
              'canonical_url': 'https://www.investor.gov/',
              'source_title': 'Stocks',
              'publisher': 'Investor.gov',
              'source_observed_at': '2026-08-29T00:00:00.000Z',
              'effective_at': null,
              'retrieved_at': '2026-08-29T00:00:00.000Z',
              'current_until': '2027-08-29T00:00:00.000Z',
              'claim_summary': 'A stock can represent an ownership interest.',
            },
          ],
        },
      ],
      'material_limitations': 'Share classes and rights differ.',
      'risk_context': 'Market value may fall, including to zero.',
      'recall_prompt': 'What does a share generally represent?',
      'rowan_explanation': 'A reviewed restatement of the definition.',
      'knowledge_check': {
        'id': 'question-$ordinal',
        'prompt': 'Which statement is factual?',
        'options': [
          {
            'id': 'option-a-$ordinal',
            'ordinal': 1,
            'label': 'Ownership interest',
          },
          {
            'id': 'option-b-$ordinal',
            'ordinal': 2,
            'label': 'Guaranteed return',
          },
        ],
      },
    };
  }),
  'recall': null,
  'command_effect': null,
  'answer': null,
};
