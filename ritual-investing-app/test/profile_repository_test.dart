import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/features/onboarding/domain/onboarding_draft.dart'
    hide RitualInterest;
import 'package:ritual_investing_app/features/profile/domain/model.dart';

void main() {
  test('generated profile service reads the authoritative settings aggregate', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(_serveProfileReads(server));
    final service = GeneratedProfileApiService(
      RitualInvestingApiClient(basePathOverride: _basePath(server)),
    );

    final profile = await service.fetch();

    expect(profile.displayName, 'Ritual Member');
    expect(profile.profileVersion, 2);
    expect(profile.preferences.theme, ProfileTheme.dark);
    expect(profile.preferences.ritualLanguage, RitualLanguage.practical);
    expect(profile.investor?.experience, InvestingExperience.newToInvesting);
    expect(profile.investor?.goal, InvestmentGoal.longTermGrowth);
    expect(profile.investor?.isDemo, isTrue);
    expect(profile.astrology?.serverDerivedProfile, 'solar_builder');
    expect(profile.astrology?.birthDate, ProfileDate(1994, 5, 14));
  });

  test('optional 404 settings resources map to absence', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(_serveProfileReads(server, optionalResourcesAbsent: true));
    final service = GeneratedProfileApiService(
      RitualInvestingApiClient(basePathOverride: _basePath(server)),
    );

    final profile = await service.fetch();

    expect(profile.investor, isNull);
    expect(profile.astrology, isNull);
    expect(profile.astrologyDecision, ProfileConsentDecision.unknown);
  });

  test('unknown generated settings enums are rejected safely', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(_serveProfileReads(server, unknownTheme: true));
    final service = GeneratedProfileApiService(
      RitualInvestingApiClient(basePathOverride: _basePath(server)),
    );

    await expectLater(
      service.fetch(),
      throwsA(
        isA<LoadFailure>().having(
          (failure) => failure.phase,
          'phase',
          LoadPhase.terminalFailure,
        ),
      ),
    );
  });

  test(
    'production adapter PUT emits date only and records astrology acceptance',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final captured = <_CapturedRequest>[];
      unawaited(() async {
        await for (final request in server) {
          captured.add(
            _CapturedRequest(
              method: request.method,
              path: request.uri.path,
              ifMatch: request.headers.value('if-match'),
              body: jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>,
            ),
          );
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(
              request.uri.path.endsWith('consents')
                  ? _consentResponse('accepted')
                  : _astrologyResponse,
            ),
          );
          await request.response.close();
          if (captured.length == 2) break;
        }
      }());
      final service = GeneratedProfileApiService(
        RitualInvestingApiClient(basePathOverride: _basePath(server)),
      );

      final receipt = await service.putAstrology(
        ProfileAstrologyUpdate(
          birthDate: ProfileDate(1994, 5, 14),
          expectedVersion: 4,
        ),
      );

      final put = captured.singleWhere((request) => request.method == 'PUT');
      final consent = captured.singleWhere(
        (request) => request.path.endsWith('consents'),
      );
      expect(put.path, '/v1/me/astrology-profile');
      expect(put.ifMatch, '4');
      expect(put.body, {'birth_date': '1994-05-14'});
      expect(consent.body, {
        'decision': 'accepted',
        'policy_code': 'astrology',
        'policy_version': '2026-08',
      });
      expect(receipt.decision, ProfileConsentDecision.accepted);
    },
  );

  test('generated settings mutations send versions and withdrawal consent', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final captured = <_CapturedRequest>[];
    unawaited(() async {
      await for (final request in server) {
        final encoded = await utf8.decoder.bind(request).join();
        captured.add(
          _CapturedRequest(
            method: request.method,
            path: request.uri.path,
            ifMatch: request.headers.value('if-match'),
            body: encoded.isEmpty
                ? const {}
                : jsonDecode(encoded) as Map<String, dynamic>,
          ),
        );
        request.response.headers.contentType = ContentType.json;
        if (request.method == 'DELETE') {
          request.response.statusCode = HttpStatus.noContent;
        } else if (request.uri.path.endsWith('preferences')) {
          request.response.write(jsonEncode(_preferencesResponse(theme: 'dark')));
        } else if (request.uri.path.endsWith('investor-profile')) {
          request.response.write(jsonEncode(_investorResponse));
        } else {
          request.response.write(jsonEncode(_consentResponse('withdrawn')));
        }
        await request.response.close();
        if (captured.length == 4) break;
      }
    }());
    final service = GeneratedProfileApiService(
      RitualInvestingApiClient(basePathOverride: _basePath(server)),
    );

    await service.patchPreferences(
      const ProfilePreferencesUpdate(
        expectedVersion: 3,
        theme: ProfileTheme.dark,
      ),
    );
    await service.putInvestor(
      const ProfileInvestorUpdate(
        expectedVersion: 5,
        experience: InvestingExperience.newToInvesting,
        goal: InvestmentGoal.longTermGrowth,
        horizon: InvestmentHorizon.long,
        risk: RiskComfort.moderate,
        contributionRhythm: ContributionRhythm.monthly,
      ),
    );
    final receipt = await service.deleteAstrology(expectedVersion: 4);

    expect(captured[0].method, 'PATCH');
    expect(captured[0].ifMatch, '3');
    expect(captured[0].body, {'theme_mode': 'dark'});
    expect(captured[1].method, 'PUT');
    expect(captured[1].ifMatch, '5');
    expect(captured[1].body, {
      'contribution_rhythm': 'monthly',
      'goal_type': 'long_term_growth',
      'investing_experience': 'new',
      'risk_comfort': 'moderate',
      'time_horizon': 'long',
    });
    expect(captured[2].method, 'DELETE');
    expect(captured[2].ifMatch, '4');
    expect(captured[3].body, {
      'decision': 'withdrawn',
      'policy_code': 'astrology',
      'policy_version': '2026-08',
    });
    expect(receipt.decision, ProfileConsentDecision.withdrawn);
  });
}

Future<void> _serveProfileReads(
  HttpServer server, {
  bool optionalResourcesAbsent = false,
  bool unknownTheme = false,
}) async {
  var served = 0;
  await for (final request in server) {
    request.response.headers.contentType = ContentType.json;
    final payload = switch (request.uri.path) {
      '/v1/me' => _accountResponse,
      '/v1/me/preferences' => _preferencesResponse(
        theme: unknownTheme ? 'future_theme' : 'dark',
      ),
      '/v1/me/investor-profile' => optionalResourcesAbsent
          ? null
          : _investorResponse,
      '/v1/me/astrology-profile' => optionalResourcesAbsent
          ? null
          : _astrologyResponse,
      _ => throw StateError('Unexpected request ${request.uri.path}'),
    };
    if (payload == null) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write(
        jsonEncode({
          'error': {'code': 'resource_not_found', 'message': 'Not found'},
        }),
      );
    } else {
      request.response.write(jsonEncode(payload));
    }
    await request.response.close();
    served += 1;
    if (served == 4) break;
  }
}

String _basePath(HttpServer server) =>
    'http://${server.address.address}:${server.port}';

const _meta = <String, Object?>{
  'request_id': '00000000-0000-4000-8000-000000000099',
  'server_time': '2026-08-25T12:00:00.000Z',
};

const _accountResponse = <String, Object?>{
  'data': {
    'account': {
      'id': '00000000-0000-4000-8000-000000000001',
      'status': 'active',
    },
    'profile': {
      'display_name': 'Ritual Member',
      'locale': 'en-US',
      'version': 2,
    },
  },
  'meta': _meta,
};

Map<String, Object?> _preferencesResponse({required String theme}) => {
  'data': {
    'locale': 'en-US',
    'ritual_familiarity': 'new',
    'ritual_interests': ['practical_research', 'reflection'],
    'ritual_language': 'practical',
    'ritual_mode': 'tarot',
    'theme_mode': theme,
    'timezone': 'America/New_York',
    'version': 3,
  },
  'meta': _meta,
};

const _investorResponse = <String, Object?>{
  'data': {
    'contribution_rhythm': 'monthly',
    'goal_type': 'long_term_growth',
    'investing_experience': 'new',
    'is_demo': true,
    'risk_comfort': 'moderate',
    'time_horizon': 'long',
    'version': 5,
  },
  'meta': _meta,
};

const _astrologyResponse = <String, Object?>{
  'data': {
    'algorithm_version': 'v1',
    'birth_date': '1994-05-14',
    'derived_profile_code': 'solar_builder',
    'enabled_at': '2026-08-24T12:00:00.000Z',
    'version': 4,
  },
  'meta': _meta,
};

Map<String, Object?> _consentResponse(String decision) => {
  'data': {
    'decision': decision,
    'id': '00000000-0000-4000-8000-000000000088',
    'policy_code': 'astrology',
    'policy_version': '2026-08',
    'recorded_at': '2026-08-25T12:00:00.000Z',
  },
  'meta': _meta,
};

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.path,
    required this.ifMatch,
    required this.body,
  });

  final String method;
  final String path;
  final String? ifMatch;
  final Map<String, dynamic> body;
}
