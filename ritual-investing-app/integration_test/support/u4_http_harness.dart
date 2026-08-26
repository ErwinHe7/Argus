import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    as api;
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/asset_codex/application/controller.dart';
import 'package:ritual_investing_app/features/asset_codex/data/generated_asset_codex_api_service.dart';
import 'package:ritual_investing_app/features/asset_codex/data/repository.dart';
import 'package:ritual_investing_app/features/asset_codex/domain/model.dart';
import 'package:ritual_investing_app/features/ritual/application/daily_ritual_controller.dart';
import 'package:ritual_investing_app/features/ritual/data/daily_ritual_repository.dart';
import 'package:ritual_investing_app/features/rowan/application/controller.dart';
import 'package:ritual_investing_app/features/rowan/data/generated_rowan_api_service.dart';
import 'package:ritual_investing_app/features/rowan/data/repository.dart';
import 'package:ritual_investing_app/features/search/application/controller.dart'
    as member_search;
import 'package:ritual_investing_app/features/search/data/generated_search_api_service.dart';
import 'package:ritual_investing_app/features/search/data/repository.dart';

const u4AssignmentId = '00000000-0000-4000-8000-000000000401';
const u4AssetId = '00000000-0000-4000-8000-000000000402';
const u4PeerId = '00000000-0000-4000-8000-000000000403';
const u4AssetRevisionId = '00000000-0000-4000-8000-000000000404';
const u4PeerRevisionId = '00000000-0000-4000-8000-000000000405';
const u5GrimoireId = '00000000-0000-4000-8000-000000000431';
const u5TemplateId = '00000000-0000-4000-8000-000000000432';
const u5CreatorId = '00000000-0000-4000-8000-000000000433';
const u5CovenId = '00000000-0000-4000-8000-000000000434';
const u5CircleId = '00000000-0000-4000-8000-000000000435';
const _claimId = '00000000-0000-4000-8000-000000000406';
const _requestId = '00000000-0000-4000-8000-000000000407';
const _token = 'u4-local-member-token';

class U4HttpHarness {
  U4HttpHarness._(this._server, this.client);

  final HttpServer _server;
  final api.RitualInvestingApiClient client;
  final List<U4CapturedRequest> requests = [];
  var ritualState = api.DailyRitualDetailStateEnum.assigned;
  var ritualVersion = 1;
  var saved = false;
  var rowanUnavailable = true;
  var grimoireSaved = false;
  var templateSaved = false;
  var covenSaved = false;
  var circleVersion = 2;
  var circleTitle = 'Soft Power Circle';
  var circleDescription = 'Private provider-free research notes.';
  DateTime? circleArchivedAt;
  var conflictNextCirclePatch = true;

  late final DailyRitualController ritualController = DailyRitualController(
    repository: DailyRitualRepository(
      service: GeneratedRitualApiService(client),
      cache: MemoryReadCache(),
    ),
  );
  late final member_search.SearchController searchController =
      member_search.SearchController(
        repository: SearchRepository(service: GeneratedSearchService(client)),
        debounce: const Duration(milliseconds: 25),
      );
  late final RowanController rowanController = RowanController(
    repository: RowanRepository(
      service: GeneratedRowanService(client),
      cache: MemoryReadCache(),
    ),
  );

  static Future<U4HttpHarness> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = api.RitualInvestingApiClient(
      basePathOverride: 'http://${server.address.address}:${server.port}',
      interceptors: [
        RitualAuthInterceptor(tokenProvider: const _TokenProvider()),
      ],
    );
    final harness = U4HttpHarness._(server, client);
    unawaited(harness._serve());
    return harness;
  }

  AssetCodexController assetController({String assetId = u4AssetId}) =>
      AssetCodexController(
        repository: AssetCodexRepository(
          service: GeneratedAssetCodexService(client),
          cache: MemoryReadCache(),
        ),
        assetId: assetId,
        source: const AssetSourceContext(
          kind: AssetSourceKind.ritual,
          resourceId: u4AssignmentId,
        ),
      );

  Future<void> close() async {
    ritualController.dispose();
    searchController.dispose();
    rowanController.dispose();
    client.dio.close(force: true);
    await _server.close(force: true);
  }

  Future<void> _serve() async {
    await for (final request in _server) {
      final body = await utf8.decoder.bind(request).join();
      requests.add(
        U4CapturedRequest(
          method: request.method,
          uri: request.uri,
          authorization: request.headers.value(HttpHeaders.authorizationHeader),
          ifMatch: request.headers.value(HttpHeaders.ifMatchHeader),
          idempotencyKey: request.headers.value('idempotency-key'),
          body: body,
        ),
      );
      request.response.headers.contentType = ContentType.json;
      try {
        await _route(request);
      } on Object catch (error) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write(
          jsonEncode({
            'error': {
              'code': 'service_unavailable',
              'message': 'Fixture failure: $error',
            },
          }),
        );
      }
      await request.response.close();
    }
  }

  Future<void> _route(HttpRequest request) async {
    final path = request.uri.path;
    if (request.method == 'GET' && path == '/v1/discover') {
      _json(request, {
        'data': [
          {'kind': 'grimoire', 'grimoire': _u5GrimoireSummary()},
          {'kind': 'circle_template', 'circle_template': _u5TemplateSummary()},
          {'kind': 'coven', 'coven': _u5CovenSummary()},
          {'kind': 'asset', 'asset': _summary(u4AssetId).toJson()},
        ],
        'meta': _collectionMeta(),
      });
      return;
    }
    if (request.method == 'GET' && path == '/v1/community/creators') {
      _json(request, {
        'data': [_u5Creator()],
        'meta': _collectionMeta(),
      });
      return;
    }
    if (request.method == 'GET' && path == '/v1/grimoires/$u5GrimoireId') {
      _json(request, {
        'data': {
          ..._u5GrimoireSummary(),
          'assets': [_summary(u4AssetId).toJson()],
          'saved': grimoireSaved,
        },
        'meta': _responseMeta().toJson(),
      });
      return;
    }
    if (request.method == 'PUT' &&
        path == '/v1/me/saved-grimoires/$u5GrimoireId') {
      grimoireSaved = true;
      _json(request, _savedReceipt());
      return;
    }
    if (request.method == 'DELETE' &&
        path == '/v1/me/saved-grimoires/$u5GrimoireId') {
      grimoireSaved = false;
      request.response.statusCode = HttpStatus.noContent;
      return;
    }
    if (request.method == 'GET' &&
        path == '/v1/circle-templates/$u5TemplateId') {
      _json(request, {
        'data': {
          ..._u5TemplateSummary(),
          'assets': [
            {
              ..._summary(u4AssetId).toJson(),
              'note': 'Review the fictional evidence.',
              'ordinal': 1,
              'weight_bps': 10000,
            },
          ],
          'saved': templateSaved,
        },
        'meta': _responseMeta().toJson(),
      });
      return;
    }
    if (request.method == 'PUT' &&
        path == '/v1/me/saved-circle-templates/$u5TemplateId') {
      templateSaved = true;
      _json(request, _savedReceipt());
      return;
    }
    if (request.method == 'DELETE' &&
        path == '/v1/me/saved-circle-templates/$u5TemplateId') {
      templateSaved = false;
      request.response.statusCode = HttpStatus.noContent;
      return;
    }
    if (request.method == 'POST' &&
        path == '/v1/circle-templates/$u5TemplateId/copies') {
      request.response.statusCode = HttpStatus.created;
      _json(request, {'data': _u5Circle(), 'meta': _responseMeta().toJson()});
      return;
    }
    if (request.method == 'GET' && path == '/v1/circles') {
      _json(request, {
        'data': [_u5Circle()],
        'meta': _collectionMeta(),
      });
      return;
    }
    if (request.method == 'GET' && path == '/v1/circles/$u5CircleId') {
      _json(request, {'data': _u5Circle(), 'meta': _responseMeta().toJson()});
      return;
    }
    if (request.method == 'PATCH' && path == '/v1/circles/$u5CircleId') {
      if (conflictNextCirclePatch) {
        conflictNextCirclePatch = false;
        circleVersion = 3;
        circleTitle = 'Changed on another device';
        request.response.statusCode = HttpStatus.preconditionFailed;
        _json(request, const {
          'error': {
            'code': 'version_conflict',
            'message': 'Review the authoritative Circle.',
          },
        });
        return;
      }
      final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
      circleTitle = body['title'] as String;
      circleDescription = body['description'] as String;
      circleVersion += 1;
      _json(request, {'data': _u5Circle(), 'meta': _responseMeta().toJson()});
      return;
    }
    if (request.method == 'DELETE' && path == '/v1/circles/$u5CircleId') {
      circleVersion += 1;
      circleArchivedAt = DateTime.utc(2026, 8, 25, 19);
      request.response.statusCode = HttpStatus.noContent;
      return;
    }
    if (request.method == 'GET' && path == '/v1/coven/$u5CovenId') {
      _json(request, {
        'data': {
          'id': u5CovenId,
          'revision_id': '00000000-0000-4000-8000-000000000438',
          'slug': 'aurora-healthworks',
          'company': 'Aurora Healthworks',
          'symbol': 'AUR',
          'focus': 'Preventive care',
          'summary': 'Fictional provider-free company research.',
          'inclusion_rationale': 'Dated founder evidence is present.',
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
          'demo': _demo().toJson(),
        },
        'meta': _responseMeta().toJson(),
      });
      return;
    }
    if (request.method == 'GET' && path == '/v1/coven/$u5CovenId/evidence') {
      _json(request, {
        'data': [_evidenceDetail().toJson()],
        'meta': _responseMeta().toJson(),
      });
      return;
    }
    if (request.method == 'PUT' && path == '/v1/me/saved-coven/$u5CovenId') {
      covenSaved = true;
      _json(request, _savedReceipt());
      return;
    }
    if (request.method == 'GET' && path == '/v1/rituals/daily') {
      _json(request, _dailyResponse());
      return;
    }
    if (request.method == 'GET' && path == '/v1/rituals/$u4AssignmentId') {
      _json(request, _assignmentResponse());
      return;
    }
    if (request.method == 'POST' &&
        path == '/v1/rituals/$u4AssignmentId/reveal') {
      if (request.headers.value(HttpHeaders.ifMatchHeader) != '"v1"') {
        _versionConflict(request);
        return;
      }
      ritualState = api.DailyRitualDetailStateEnum.revealed;
      ritualVersion = 2;
      _json(request, _assignmentResponse());
      return;
    }
    if (request.method == 'POST' &&
        path == '/v1/rituals/$u4AssignmentId/complete') {
      if (request.headers.value(HttpHeaders.ifMatchHeader) != '"v2"') {
        _versionConflict(request);
        return;
      }
      ritualState = api.DailyRitualDetailStateEnum.completed;
      ritualVersion = 3;
      _json(request, _assignmentResponse());
      return;
    }
    if (request.method == 'GET' &&
        path == '/v1/rituals/$u4AssignmentId/evidence') {
      _json(
        request,
        api.RitualEvidenceResponse(
          data: [_evidenceDetail()],
          meta: _responseMeta(),
        ).toJson(),
      );
      return;
    }
    if (request.method == 'GET' && path == '/v1/rituals/history') {
      _json(
        request,
        api.RitualHistoryResponse(
          data: [
            api.RitualHistoryItem(
              assignmentId: u4AssignmentId,
              date: DateTime.utc(2026, 8, 25),
              demo: _demo(),
              mode: api.RitualHistoryItemModeEnum.tarot,
              state: switch (ritualState) {
                api.DailyRitualDetailStateEnum.assigned =>
                  api.RitualHistoryItemStateEnum.assigned,
                api.DailyRitualDetailStateEnum.revealed =>
                  api.RitualHistoryItemStateEnum.revealed,
                _ => api.RitualHistoryItemStateEnum.completed,
              },
              title: 'Direction, not urgency.',
            ),
          ],
          meta: api.CollectionMeta(
            hasMore: false,
            nextCursor: null,
            requestId: _requestId,
          ),
        ).toJson(),
      );
      return;
    }
    if (request.method == 'GET' && path == '/v1/assets/$u4AssetId') {
      _json(request, _assetDetailResponse(u4AssetId, saved: saved));
      return;
    }
    if (request.method == 'GET' && path == '/v1/assets/$u4AssetId/evidence') {
      _json(
        request,
        api.AssetEvidenceResponse(
          data: [_evidenceDetail()],
          meta: _responseMeta(),
        ).toJson(),
      );
      return;
    }
    if (request.method == 'GET' && path == '/v1/assets/$u4AssetId/metrics') {
      _json(
        request,
        api.AssetMetricsResponse(
          data: [_metric()],
          meta: _responseMeta(),
        ).toJson(),
      );
      return;
    }
    if (request.method == 'POST' && path == '/v1/assets/compare') {
      _json(
        request,
        api.AssetComparisonResponse(
          data: api.AssetComparison(
            assets: [
              api.AssetComparisonAssetsInner(
                asset: _summary(u4AssetId),
                latestMetric: _metric(),
                riskCount: 1,
              ),
              api.AssetComparisonAssetsInner(
                asset: _summary(u4PeerId),
                latestMetric: _metric(priceMinor: 9876),
                riskCount: 2,
              ),
            ],
            comparedAt: DateTime.utc(2026, 8, 25, 12, 30),
            demo: _demo(),
          ),
          meta: _responseMeta(),
        ).toJson(),
      );
      return;
    }
    if (request.method == 'PUT' && path == '/v1/me/saved-assets/$u4AssetId') {
      saved = true;
      _json(
        request,
        api.SaveAsset200Response(
          data: api.SavedItemReceipt(
            saved: true,
            savedAt: DateTime.utc(2026, 8, 25, 12, 31),
          ),
          meta: _responseMeta(),
        ).toJson(),
      );
      return;
    }
    if (request.method == 'DELETE' &&
        path == '/v1/me/saved-assets/$u4AssetId') {
      saved = false;
      request.response.statusCode = HttpStatus.noContent;
      return;
    }
    if (request.method == 'GET' && path == '/v1/search') {
      _json(
        request,
        api.SearchResponse(
          data: [
            api.SearchResult(
              kind: api.SearchResultKindEnum.asset,
              asset: _summary(u4PeerId),
            ),
          ],
          meta: api.CollectionMeta(
            hasMore: false,
            nextCursor: null,
            requestId: _requestId,
          ),
        ).toJson(),
      );
      return;
    }
    if (request.method == 'GET' && path == '/v1/rowan/counsel') {
      final requestedSurface = request.uri.queryParameters['surface'];
      if (rowanUnavailable && requestedSurface != 'coven') {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        _json(request, const {
          'error': {
            'code': 'service_unavailable',
            'message': 'Rowan is briefly unavailable.',
          },
        });
      } else {
        _json(
          request,
          api.RowanCounselResponse(
            data: api.RowanCounsel(
              body: requestedSurface == 'coven'
                  ? 'Qualification evidence is dated, not assumed.'
                  : 'Use the published evidence to compare uncertainty.',
              riskFooter: 'Demo counsel; never an instruction to trade.',
              scriptRevisionId: '00000000-0000-4000-8000-000000000408',
              surface: requestedSurface == 'coven'
                  ? api.RowanCounselSurfaceEnum.coven
                  : api.RowanCounselSurfaceEnum.assetCodex,
            ),
            meta: _responseMeta(),
          ).toJson(),
        );
      }
      return;
    }
    request.response.statusCode = HttpStatus.notFound;
    _json(request, const {
      'error': {'code': 'resource_not_found', 'message': 'Not found.'},
    });
  }

  Map<String, dynamic> _u5GrimoireSummary() => {
    'id': u5GrimoireId,
    'revision_id': '00000000-0000-4000-8000-000000000436',
    'slug': 'patient-compounding',
    'title': 'Patient Compounding',
    'description': 'Fictional read-only research.',
    'theme': 'durability',
    'curator_label': 'Ritual Research Desk',
    'demo': _demo().toJson(),
  };

  Map<String, dynamic> _u5Creator() => {
    'id': u5CreatorId,
    'slug': 'mira-vale',
    'display_name': 'Mira Vale',
    'bio': 'Fictional Demo research curator.',
    'is_fictional': true,
    'demo': _demo().toJson(),
  };

  Map<String, dynamic> _u5TemplateSummary() => {
    'id': u5TemplateId,
    'revision_id': '00000000-0000-4000-8000-000000000437',
    'slug': 'soft-power-circle',
    'title': 'Soft Power Circle',
    'description': 'Fictional seeded research to copy privately.',
    'theme': 'leadership',
    'creator': _u5Creator(),
    'demo': _demo().toJson(),
  };

  Map<String, dynamic> _u5CovenSummary() => {
    'id': u5CovenId,
    'revision_id': '00000000-0000-4000-8000-000000000438',
    'slug': 'aurora-healthworks',
    'company': 'Aurora Healthworks',
    'symbol': 'AUR',
    'focus': 'Preventive care',
    'category': 'founder',
    'effective_date': '2026-08-01T00:00:00.000Z',
    'verified_as_of': '2026-08-25T12:00:00.000Z',
    'teaser': 'Dated fictional founder evidence.',
    'demo': _demo().toJson(),
  };

  Map<String, dynamic> _u5Circle() => {
    'id': u5CircleId,
    'title': circleTitle,
    'description': circleDescription,
    'private': true,
    'version': circleVersion,
    'assets': [
      {
        'asset_id': u4AssetId,
        'ordinal': 1,
        'note': 'Private research note.',
        'weight_bps': 10000,
      },
    ],
    'source_template_id': u5TemplateId,
    'source_revision_id': '00000000-0000-4000-8000-000000000437',
    'archived_at': circleArchivedAt?.toIso8601String(),
  };

  Map<String, dynamic> _collectionMeta() => {
    'has_more': false,
    'next_cursor': null,
    'request_id': _requestId,
  };

  Map<String, dynamic> _savedReceipt() => {
    'data': {'saved': true, 'saved_at': '2026-08-25T12:31:00.000Z'},
    'meta': _responseMeta().toJson(),
  };

  Map<String, dynamic> _dailyResponse() => api.DailyRitualResponse(
    data: _dailyDetail(),
    meta: _responseMeta(),
  ).toJson();

  Map<String, dynamic> _assignmentResponse() =>
      api.GetRitualAssignment200Response(
        data: _dailyDetail(),
        meta: _responseMeta(),
      ).toJson();

  api.DailyRitualDetail _dailyDetail() => api.DailyRitualDetail(
    art: api.ArtReference(
      alt: 'The Compass at a celestial crossroads',
      key: api.ArtReferenceKeyEnum.theCompass,
    ),
    assignmentId: u4AssignmentId,
    completedAt: ritualState == api.DailyRitualDetailStateEnum.completed
        ? DateTime.utc(2026, 8, 25, 12, 20)
        : null,
    date: DateTime.utc(2026, 8, 25),
    demo: _demo(),
    evidence: [_evidenceSummary()],
    guidance: 'Inspect sources before choosing what to research.',
    ideas: [
      api.RitualAssetIdea(
        appearanceReason: 'provider-free durability scenario',
        assetId: u4AssetId,
        name: 'Vigilant Demo ETF',
        riskSummary: 'The fictional signal can reverse.',
        symbol: 'VIG',
      ),
    ],
    interpretation: 'Direction is an invitation, not an instruction.',
    marketLabel: 'Market-informed Demo evidence',
    mode: api.DailyRitualDetailModeEnum.tarot,
    revealedAt: ritualState == api.DailyRitualDetailStateEnum.assigned
        ? null
        : DateTime.utc(2026, 8, 25, 12, 10),
    revision: api.DailyRitualDetailRevision(
      id: '00000000-0000-4000-8000-000000000409',
      number: 1,
    ),
    rowan: api.RowanCounsel(
      body: 'Notice what changed without rushing to act.',
      riskFooter: 'Demo counsel; not investment advice.',
      scriptRevisionId: '00000000-0000-4000-8000-000000000410',
      surface: api.RowanCounselSurfaceEnum.dailyRitual,
    ),
    state: ritualState,
    title: 'Direction, not urgency.',
    version: ritualVersion,
  );

  Map<String, dynamic> _assetDetailResponse(
    String assetId, {
    required bool saved,
  }) => api.AssetDetailResponse(
    data: api.AssetCodexDetail(
      appearanceReason: 'A deterministic provider-free scenario.',
      assetType: api.AssetCodexDetailAssetTypeEnum.etf,
      currency: api.AssetCodexDetailCurrencyEnum.USD,
      demo: _demo(),
      evidence: [_evidenceSummary()],
      id: assetId,
      limitations: 'No live price, provider, bank, or brokerage data.',
      metricsAsOf: DateTime.utc(2026, 8, 25, 12),
      name: 'Vigilant Demo ETF',
      revisionId: u4AssetRevisionId,
      risks: [
        api.AssetCodexDetailRisksInner(
          detail: 'The deterministic scenario can reverse.',
          severity: api.AssetCodexDetailRisksInnerSeverityEnum.high,
          title: 'Scenario reversal',
        ),
      ],
      saved: saved,
      slug: 'vigilant-demo-etf',
      symbol: 'VIG',
      thesis: 'A Demo interpretation of published fictional evidence.',
    ),
    meta: _responseMeta(),
  ).toJson();

  api.AssetSummary _summary(String id) => api.AssetSummary(
    appearanceReason: 'A deterministic provider-free comparison.',
    assetType: api.AssetSummaryAssetTypeEnum.etf,
    currency: api.AssetSummaryCurrencyEnum.USD,
    demo: _demo(),
    id: id,
    name: id == u4AssetId ? 'Vigilant Demo ETF' : 'Patient Demo Fund',
    revisionId: id == u4AssetId ? u4AssetRevisionId : u4PeerRevisionId,
    slug: id == u4AssetId ? 'vigilant-demo-etf' : 'patient-demo-fund',
    symbol: id == u4AssetId ? 'VIG' : 'PEER',
  );

  api.EvidenceSummary _evidenceSummary() => api.EvidenceSummary(
    claimId: _claimId,
    factorLabel: 'Provider-free durability',
    observedAt: DateTime.utc(2026, 8, 25, 12),
    summary: 'The deterministic Demo signal remained within its range.',
    uncertainty: 'The fictional pattern can reverse.',
  );

  api.EvidenceDetail _evidenceDetail() => api.EvidenceDetail(
    claimId: _claimId,
    factorLabel: 'Provider-free durability',
    observedAt: DateTime.utc(2026, 8, 25, 12),
    source_: api.EvidenceDetailSource(
      publishedAt: DateTime.utc(2026, 8, 25, 11),
      publisher: 'Demo Research Desk',
      title: 'Provider-free evidence note',
      url: 'https://example.invalid/evidence',
    ),
    summary: 'The deterministic Demo signal remained within its range.',
    uncertainty: 'The fictional pattern can reverse.',
  );

  api.AssetMetric _metric({int priceMinor = 12345}) => api.AssetMetric(
    changeBps: 31,
    demo: _demo(),
    expenseRatioBps: 20,
    observedAt: DateTime.utc(2026, 8, 25, 12),
    priceMinor: priceMinor,
    sourceLabel: 'Deterministic local fixture',
  );

  api.DemoDisclosure _demo() => api.DemoDisclosure(
    isDemo: true,
    limitations: const [
      'Fictional scenario; no external finance or banking provider.',
    ],
    observedAt: DateTime.utc(2026, 8, 25, 12),
    sourceLabel: 'Deterministic local fixture',
  );

  api.ResponseMeta _responseMeta() => api.ResponseMeta(requestId: _requestId);

  void _versionConflict(HttpRequest request) {
    request.response.statusCode = HttpStatus.conflict;
    _json(request, const {
      'error': {'code': 'version_conflict', 'message': 'Version changed.'},
    });
  }

  void _json(HttpRequest request, Map<String, dynamic> value) {
    request.response.write(jsonEncode(value));
  }
}

class U4CapturedRequest {
  const U4CapturedRequest({
    required this.method,
    required this.uri,
    required this.authorization,
    required this.ifMatch,
    required this.idempotencyKey,
    required this.body,
  });

  final String method;
  final Uri uri;
  final String? authorization;
  final String? ifMatch;
  final String? idempotencyKey;
  final String body;
}

class _TokenProvider implements AccessTokenProvider {
  const _TokenProvider();

  @override
  Future<String?> accessToken() async => _token;
}
