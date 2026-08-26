import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    show RitualInvestingApiClient;
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/circles/application/controller.dart';
import 'package:ritual_investing_app/features/circles/data/repository.dart';
import 'package:ritual_investing_app/features/circles/domain/model.dart';
import 'package:ritual_investing_app/features/grimoires/data/repository.dart';
import 'package:ritual_investing_app/features/rowan/data/repository.dart';
import 'package:ritual_investing_app/features/rowan/domain/model.dart';

void main() {
  test(
    'U5 generated Dio adapters preserve saves, versions, and headers',
    () async {
      final client = RitualInvestingApiClient(
        basePathOverride: 'https://api.ritual-investing.invalid',
        interceptors: [
          RitualAuthInterceptor(tokenProvider: const _TokenProvider()),
        ],
      );
      final adapter = _U5Adapter();
      client.dio.httpClientAdapter = adapter;

      final grimoire = GeneratedGrimoireService(client);
      expect((await grimoire.fetchDetail(_grimoireId)).saved, isFalse);
      await grimoire.save(_grimoireId);
      expect((await grimoire.fetchDetail(_grimoireId)).saved, isTrue);

      final coven = GeneratedCovenApiService(client);
      expect((await coven.fetchDetail(_covenId)).saved, isFalse);
      expect(await coven.fetchEvidence(_covenId), hasLength(1));
      await coven.save(_covenId);
      expect((await coven.fetchDetail(_covenId)).saved, isTrue);

      final circleService = GeneratedCircleService(client);
      expect(
        (await circleService.fetchList(includeArchived: true)).items,
        hasLength(1),
      );
      expect((await circleService.fetchTemplate(_templateId)).saved, isFalse);
      await circleService.saveTemplate(_templateId);
      expect((await circleService.fetchTemplate(_templateId)).saved, isTrue);
      final copied = await circleService.copy(
        const CircleCopyCommand(
          idempotencyKey: 'copy-key-u5',
          templateId: _templateId,
          title: 'My copied research',
        ),
      );
      expect(copied.sourceTemplateId, _templateId);

      final repository = CircleRepository(
        service: circleService,
        cache: MemoryReadCache(),
      );
      final detail = CircleDetailController(
        circleId: _circleId,
        repository: repository,
      );
      await detail.load();
      adapter.conflictNextPatch = true;
      detail.updateDraft(
        title: 'My preserved draft',
        description: 'Still private.',
      );

      await detail.saveDraft();

      expect(detail.state.phase, LoadPhase.conflict);
      expect(detail.state.value!.version, 3);
      expect(detail.draft.title, 'My preserved draft');
      await detail.reviewAndRetry();
      expect(
        adapter.requests.where((request) => request.method == 'PATCH'),
        hasLength(2),
      );
      expect(detail.state.phase, LoadPhase.ready);
      expect(detail.state.value!.version, 4);
      expect(detail.state.value!.title, 'My preserved draft');

      await detail.putAsset(
        const CircleAsset(
          assetId: _assetA,
          ordinal: 1,
          note: 'Updated over generated Dio',
          weightBps: 5500,
        ),
      );
      await detail.removeAsset(_assetB);
      await detail.archive();
      expect(detail.state.value!.isArchived, isTrue);
      expect(detail.state.value!.version, 7);

      final rowan = await GeneratedRowanService(client)
          .fetch(RowanRequest.coven(_covenId));
      expect(rowan.surface, RowanSurface.coven);

      expect(
        adapter.requests.every(
          (request) =>
              request.header('authorization') == 'Bearer u5-member-token',
        ),
        isTrue,
      );
      expect(
        adapter.requests
            .singleWhere((request) => request.path.endsWith('/copies'))
            .headers['idempotency-key'],
        'copy-key-u5',
      );
      expect(
        adapter.requests
            .where((request) => request.method == 'PATCH')
            .map((request) => request.headers['if-match']),
        ['"v2"', '"v3"'],
      );
      expect(
        adapter.requests
            .singleWhere(
              (request) =>
                  request.method == 'PUT' && request.path.endsWith('/$_assetA'),
            )
            .headers['if-match'],
        '"v4"',
      );
      expect(
        adapter.requests
            .singleWhere(
              (request) =>
                  request.method == 'DELETE' &&
                  request.path.endsWith('/$_assetB'),
            )
            .headers['if-match'],
        '"v5"',
      );
      expect(
        adapter.requests
            .singleWhere(
              (request) =>
                  request.method == 'DELETE' &&
                  request.path == '/v1/circles/$_circleId',
            )
            .headers['if-match'],
        '"v6"',
      );
      final rowanRequest = adapter.requests.singleWhere(
        (request) => request.path == '/v1/rowan/counsel',
      );
      expect(rowanRequest.query, {
        'surface': 'coven',
        'context_code': 'coven',
        'resource_id': _covenId,
      });
    },
  );
}

const _circleId = '00000000-0000-4000-8000-000000000741';
const _templateId = '00000000-0000-4000-8000-000000000742';
const _assetA = '00000000-0000-4000-8000-000000000743';
const _assetB = '00000000-0000-4000-8000-000000000744';
const _grimoireId = '00000000-0000-4000-8000-000000000731';
const _covenId = '00000000-0000-4000-8000-000000000721';

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.headers,
    required this.data,
  });

  final String method;
  final String path;
  final Map<String, dynamic> query;
  final Map<String, dynamic> headers;
  final Object? data;

  Object? header(String name) {
    final lower = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return null;
  }
}

class _U5Adapter implements HttpClientAdapter {
  final List<_CapturedRequest> requests = [];
  bool grimoireSaved = false;
  bool covenSaved = false;
  bool templateSaved = false;
  bool conflictNextPatch = false;
  int circleVersion = 2;
  String circleTitle = 'Private research';
  String circleDescription = 'Only visible to this member.';
  DateTime? archivedAt;
  List<Map<String, Object?>> assets = [
    {'asset_id': _assetA, 'ordinal': 1, 'note': null, 'weight_bps': 6000},
    {'asset_id': _assetB, 'ordinal': 2, 'note': null, 'weight_bps': 4000},
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
      _CapturedRequest(
        method: options.method,
        path: options.path,
        query: Map.of(options.queryParameters),
        headers: Map.of(options.headers),
        data: options.data,
      ),
    );
    final path = options.path;
    final method = options.method;

    if (method == 'GET' && path == '/v1/grimoires/$_grimoireId') {
      return _json({'data': _grimoireJson, 'meta': _meta});
    }
    if (method == 'PUT' && path == '/v1/me/saved-grimoires/$_grimoireId') {
      grimoireSaved = true;
      return _saved();
    }
    if (method == 'GET' && path == '/v1/coven/$_covenId') {
      return _json({'data': _covenJson, 'meta': _meta});
    }
    if (method == 'GET' && path == '/v1/coven/$_covenId/evidence') {
      return _json({
        'data': [_evidenceJson],
        'meta': _meta,
      });
    }
    if (method == 'PUT' && path == '/v1/me/saved-coven/$_covenId') {
      covenSaved = true;
      return _saved();
    }
    if (method == 'GET' && path == '/v1/circle-templates/$_templateId') {
      return _json({'data': _templateJson, 'meta': _meta});
    }
    if (method == 'PUT' &&
        path == '/v1/me/saved-circle-templates/$_templateId') {
      templateSaved = true;
      return _saved();
    }
    if (method == 'POST' &&
        path == '/v1/circle-templates/$_templateId/copies') {
      final copy = {
        ..._circleJson,
        'title': 'My copied research',
        'source_template_id': _templateId,
        'source_revision_id': '00000000-0000-4000-8000-000000000745',
      };
      return _json({'data': copy, 'meta': _meta}, status: 201);
    }
    if (method == 'GET' && path == '/v1/circles') {
      return _json({
        'data': [_circleJson],
        'meta': {..._meta, 'has_more': false, 'next_cursor': null},
      });
    }
    if (method == 'GET' && path == '/v1/circles/$_circleId') {
      return _json({'data': _circleJson, 'meta': _meta});
    }
    if (method == 'PATCH' && path == '/v1/circles/$_circleId') {
      if (conflictNextPatch) {
        conflictNextPatch = false;
        circleVersion = 3;
        circleTitle = 'Changed on another device';
        return _json(const {
          'error': {
            'code': 'version_conflict',
            'message': 'Circle version changed.',
          },
        }, status: 412);
      }
      final body = _body(options.data);
      circleTitle = body['title'] as String;
      circleDescription = body['description'] as String;
      circleVersion += 1;
      return _json({'data': _circleJson, 'meta': _meta});
    }
    if (method == 'PUT' && path == '/v1/circles/$_circleId/assets/$_assetA') {
      final body = _body(options.data);
      assets = [
        {
          'asset_id': _assetA,
          'ordinal': body['ordinal'] as int,
          'note': body['note'],
          'weight_bps': body['weight_bps'],
        },
        assets.singleWhere((asset) => asset['asset_id'] == _assetB),
      ];
      circleVersion += 1;
      return _json({'data': _circleJson, 'meta': _meta});
    }
    if (method == 'DELETE' &&
        path == '/v1/circles/$_circleId/assets/$_assetB') {
      assets = assets.where((asset) => asset['asset_id'] != _assetB).toList();
      circleVersion += 1;
      return _json({'data': _circleJson, 'meta': _meta});
    }
    if (method == 'DELETE' && path == '/v1/circles/$_circleId') {
      circleVersion += 1;
      archivedAt = DateTime.utc(2026, 8, 25, 18);
      return _empty();
    }
    if (method == 'GET' && path == '/v1/rowan/counsel') {
      return _json({
        'data': {
          'body': 'Use dated qualification evidence.',
          'risk_footer': 'Demo only; not investment advice.',
          'script_revision_id': '00000000-0000-4000-8000-000000000799',
          'surface': 'coven',
        },
        'meta': _meta,
      });
    }
    return _json(const {
      'error': {'code': 'resource_not_found', 'message': 'Not found.'},
    }, status: 404);
  }

  Map<String, Object?> get _grimoireJson => {
    'id': _grimoireId,
    'revision_id': '00000000-0000-4000-8000-000000000732',
    'slug': 'patient-compounding',
    'title': 'Patient Compounding',
    'description': 'Fictional read-only research.',
    'theme': 'durability',
    'curator_label': 'Ritual Research Desk',
    'assets': [_assetSummary],
    'saved': grimoireSaved,
    'demo': _demo,
  };

  Map<String, Object?> get _covenJson => {
    'id': _covenId,
    'revision_id': '00000000-0000-4000-8000-000000000722',
    'slug': 'aurora-healthworks',
    'company': 'Aurora Healthworks',
    'symbol': 'AUR',
    'focus': 'Preventive care',
    'summary': 'Fictional provider-free company profile.',
    'inclusion_rationale': 'Dated founder evidence is available.',
    'limitations': 'Demo only; not investment advice.',
    'qualifications': [
      {
        'category': 'founder',
        'effective_date': '2026-08-01T00:00:00.000Z',
        'evidence': [],
        'person_name': 'Avery North',
        'valid_to': null,
        'verified_as_of': '2026-08-25T12:00:00.000Z',
      },
    ],
    'saved': covenSaved,
    'demo': _demo,
  };

  Map<String, Object?> get _templateJson => {
    'id': _templateId,
    'revision_id': '00000000-0000-4000-8000-000000000745',
    'slug': 'soft-power-circle',
    'title': 'Soft Power Circle',
    'description': 'Fictional seeded research.',
    'theme': 'leadership',
    'creator': {
      'id': '00000000-0000-4000-8000-000000000746',
      'slug': 'mira-vale',
      'display_name': 'Mira Vale',
      'bio': 'Fictional Demo creator.',
      'is_fictional': true,
      'demo': _demo,
    },
    'assets': [
      {
        ..._assetSummary,
        'note': 'Research the uncertainty.',
        'ordinal': 1,
        'weight_bps': 10000,
      },
    ],
    'saved': templateSaved,
    'demo': _demo,
  };

  Map<String, Object?> get _circleJson => {
    'id': _circleId,
    'title': circleTitle,
    'description': circleDescription,
    'private': true,
    'version': circleVersion,
    'assets': assets,
    'source_template_id': null,
    'source_revision_id': null,
    'archived_at': archivedAt?.toIso8601String(),
  };

  ResponseBody _saved() => _json({
    'data': {'saved': true, 'saved_at': '2026-08-25T12:31:00.000Z'},
    'meta': _meta,
  });

  ResponseBody _empty() => ResponseBody.fromString('', 204);

  Map<String, dynamic> _body(Object? value) => switch (value) {
    String text => Map<String, dynamic>.from(jsonDecode(text) as Map),
    Map map => Map<String, dynamic>.from(map),
    _ => throw StateError('Unexpected generated request body.'),
  };

  ResponseBody _json(Map<String, Object?> value, {int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode(value),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> get _assetSummary => {
  'id': _assetA,
  'revision_id': '00000000-0000-4000-8000-000000000747',
  'slug': 'quiet-power-etf',
  'symbol': 'QPW',
  'name': 'Quiet Power ETF',
  'asset_type': 'etf',
  'currency': 'USD',
  'appearance_reason': 'Fictional durability scenario.',
  'demo': _demo,
};

Map<String, Object?> get _evidenceJson => {
  'claim_id': '00000000-0000-4000-8000-000000000724',
  'factor_label': 'Founder qualification',
  'observed_at': '2026-08-25T12:00:00.000Z',
  'source': {
    'published_at': '2026-08-24T12:00:00.000Z',
    'publisher': 'Demo Registry',
    'title': 'Aurora founder record',
    'url': 'https://example.invalid/aurora-founder',
  },
  'summary': 'The Demo registry identifies the fictional founder.',
  'uncertainty': 'Seeded content can be revised.',
};

Map<String, Object?> get _demo => {
  'is_demo': true,
  'observed_at': '2026-08-25T12:00:00.000Z',
  'source_label': 'Deterministic U5 fixture',
  'limitations': ['Fictional scenario; no live market provider.'],
};

Map<String, Object?> get _meta => {
  'request_id': '00000000-0000-4000-8000-000000000798',
};

class _TokenProvider implements AccessTokenProvider {
  const _TokenProvider();

  @override
  Future<String?> accessToken() async => 'u5-member-token';
}
