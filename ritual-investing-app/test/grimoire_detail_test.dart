import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    show RitualInvestingApiClient;
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/discover/domain/model.dart';
import 'package:ritual_investing_app/features/grimoires/application/controller.dart';
import 'package:ritual_investing_app/features/grimoires/data/generated_grimoire_api_service.dart';
import 'package:ritual_investing_app/features/grimoires/data/repository.dart';
import 'package:ritual_investing_app/features/grimoires/domain/model.dart';
import 'package:ritual_investing_app/features/grimoires/presentation/grimoire_detail_screen.dart';

void main() {
  test('Grimoire save hydrates from server in another app session', () async {
    final server = _GrimoireService();
    final first = GrimoireController(
      grimoireId: _grimoireId,
      repository: GrimoireRepository(service: server, cache: MemoryReadCache()),
    );
    await first.load();
    await first.toggleSaved();

    final anotherSession = GrimoireController(
      grimoireId: _grimoireId,
      repository: GrimoireRepository(service: server, cache: MemoryReadCache()),
    );
    await anotherSession.load();

    expect(first.state.value!.saved, isTrue);
    expect(anotherSession.state.value!.saved, isTrue);
    expect(anotherSession.state.value!.revisionId, _revisionId);
    expect(
      anotherSession.state.value!.demo.observedAt,
      DateTime.utc(2026, 8, 25, 12),
    );
  });

  test(
    'ambiguous Grimoire save reconciles authoritative server state',
    () async {
      final server = _GrimoireService(loseFirstSaveResponse: true);
      final controller = GrimoireController(
        grimoireId: _grimoireId,
        repository: GrimoireRepository(
          service: server,
          cache: MemoryReadCache(),
        ),
      );
      await controller.load();

      await controller.toggleSaved();

      expect(server.saved, isTrue);
      expect(controller.state.value!.saved, isTrue);
      expect(controller.savePhase, GrimoireSavePhase.reconciled);
    },
  );

  test(
    'generated Grimoire rejects unknown asset type/currency unions',
    () async {
      final client = RitualInvestingApiClient(
        basePathOverride: 'https://api.ritual-investing.invalid',
      );
      client.dio.httpClientAdapter = _UnknownAssetAdapter();

      await expectLater(
        GeneratedGrimoireService(client).fetchDetail(_grimoireId),
        throwsA(
          isA<LoadFailure>().having(
            (failure) => failure.phase,
            'phase',
            LoadPhase.terminalFailure,
          ),
        ),
      );
    },
  );

  testWidgets('Grimoire assets open the one shared Asset Codex route', (
    tester,
  ) async {
    final controller = GrimoireController(
      grimoireId: _grimoireId,
      repository: GrimoireRepository(
        service: _GrimoireService(),
        cache: MemoryReadCache(),
      ),
    );
    await controller.load();
    String? openedAsset;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: GrimoireDetailScreen(
          controller: controller,
          onOpenAsset: (id) => openedAsset = id,
        ),
      ),
    );

    expect(controller.state.phase, LoadPhase.ready);
    expect(find.text('Patient Compounding'), findsOneWidget);
    expect(find.textContaining('read-only'), findsWidgets);
    expect(find.textContaining('Fictional scenario'), findsOneWidget);
    await tester.tap(find.byKey(const Key('grimoire-asset-$_assetId')));
    expect(openedAsset, _assetId);
  });
}

const _grimoireId = '00000000-0000-4000-8000-000000000731';
const _revisionId = '00000000-0000-4000-8000-000000000732';
const _assetId = '00000000-0000-4000-8000-000000000733';

class _GrimoireService implements GrimoireService {
  _GrimoireService({this.loseFirstSaveResponse = false});

  final bool loseFirstSaveResponse;
  bool saved = false;
  bool _saveResponseLost = false;

  @override
  Future<GrimoireDetail> fetchDetail(String grimoireId) async => GrimoireDetail(
    id: _grimoireId,
    revisionId: _revisionId,
    slug: 'patient-compounding',
    title: 'Patient Compounding',
    description: 'A read-only curated Demo research path.',
    theme: 'durability',
    curatorLabel: 'Ritual Research Desk',
    assets: [
      GrimoireAssetReference(
        id: _assetId,
        revisionId: '00000000-0000-4000-8000-000000000734',
        slug: 'quiet-power-etf',
        symbol: 'QPW',
        name: 'Quiet Power ETF',
        appearanceReason: 'Durability evidence in a fictional scenario.',
        demo: _demo,
      ),
    ],
    saved: saved,
    demo: _demo,
  );

  @override
  Future<void> save(String grimoireId) async {
    saved = true;
    if (loseFirstSaveResponse && !_saveResponseLost) {
      _saveResponseLost = true;
      throw const GrimoireAmbiguousMutation();
    }
  }

  @override
  Future<void> unsave(String grimoireId) async => saved = false;
}

final _demo = ResearchDemoDisclosure(
  isDemo: true,
  observedAt: DateTime.utc(2026, 8, 25, 12),
  sourceLabel: 'Deterministic Grimoire fixture',
  limitations: const ['Fictional scenario; no live market provider.'],
);

class _UnknownAssetAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'data': {
        'id': _grimoireId,
        'revision_id': _revisionId,
        'slug': 'patient-compounding',
        'title': 'Patient Compounding',
        'description': 'Generated detail.',
        'theme': 'durability',
        'curator_label': 'Ritual Research Desk',
        'assets': [
          {
            'id': _assetId,
            'revision_id': '00000000-0000-4000-8000-000000000734',
            'slug': 'quiet-power-etf',
            'symbol': 'QPW',
            'name': 'Quiet Power ETF',
            'asset_type': 'future-provider-kind',
            'currency': 'XYZ',
            'appearance_reason': 'Unknown generated union.',
            'demo': _demoJson,
          },
        ],
        'saved': false,
        'demo': _demoJson,
      },
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> get _demoJson => {
  'is_demo': true,
  'observed_at': '2026-08-25T12:00:00.000Z',
  'source_label': 'Deterministic Grimoire fixture',
  'limitations': ['Fictional scenario; no live market provider.'],
};
