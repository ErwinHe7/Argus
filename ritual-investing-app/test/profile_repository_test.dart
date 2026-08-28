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
  test('generated profile service reads the account aggregate', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(_serveAccount(server));
    final service = GeneratedProfileApiService(
      RitualInvestingApiClient(basePathOverride: _basePath(server)),
    );

    final profile = await service.fetch();

    expect(profile.displayName, 'Ritual Member');
    expect(profile.profileVersion, 3);
    expect(profile.preferences.theme, ProfileTheme.dark);
    expect(profile.investor?.experience, isNull);
    expect(profile.investor?.goal, InvestmentGoal.longTermGrowth);
    expect(profile.investor?.isDemo, isFalse);
    expect(profile.astrology?.serverDerivedProfile, 'solar_builder');
    expect(profile.astrology?.birthDate, ProfileDate(1994, 5, 14));
  });

  test('nullable aggregate resources map to absence', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(_serveAccount(server, optionalResourcesAbsent: true));
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
    unawaited(_serveAccount(server, unknownTheme: true));
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

  test('astrology write is date-only and consent-first', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final captured = <_CapturedRequest>[];
    unawaited(_serveMutations(server, captured, limit: 2));
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
      (request) => request.path == '/v1/consents',
    );
    expect(captured.first.path, '/v1/consents');
    expect(put.path, '/v1/astrology-profile');
    expect(put.ifMatch, '"v4"');
    expect(put.body, {'birthDate': '1994-05-14'});
    expect(consent.body, {
      'decision': 'accepted',
      'policyCode': 'astrology',
      'policyVersion': '2026-08',
    });
    expect(receipt.decision, ProfileConsentDecision.accepted);
  });

  test('settings mutations send typed bodies and quoted ETags', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final captured = <_CapturedRequest>[];
    unawaited(_serveMutations(server, captured, limit: 4));
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
        goal: InvestmentGoal.longTermGrowth,
        horizon: InvestmentHorizon.long,
        risk: RiskComfort.moderate,
      ),
    );
    final receipt = await service.deleteAstrology(expectedVersion: 4);

    expect(captured[0].path, '/v1/preferences');
    expect(captured[0].ifMatch, '"v3"');
    expect(captured[0].body, {'themeMode': 'dark'});
    expect(captured[1].path, '/v1/investor-profile');
    expect(captured[1].ifMatch, '"v5"');
    expect(captured[1].body, {
      'goalType': 'long_term_growth',
      'riskComfort': 'moderate',
      'timeHorizon': 'long',
    });
    expect(captured[2].method, 'DELETE');
    expect(captured[2].path, '/v1/astrology-profile');
    expect(captured[2].ifMatch, '"v4"');
    expect(captured[3].body, {
      'decision': 'withdrawn',
      'policyCode': 'astrology',
      'policyVersion': '2026-08',
    });
    expect(receipt.decision, ProfileConsentDecision.withdrawn);
  });
}

Future<void> _serveAccount(
  HttpServer server, {
  bool optionalResourcesAbsent = false,
  bool unknownTheme = false,
}) async {
  await for (final request in server) {
    if (request.uri.path != '/v1/account') {
      throw StateError('Unexpected request ${request.uri.path}');
    }
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(
        _accountResponse(
          optionalResourcesAbsent: optionalResourcesAbsent,
          theme: unknownTheme ? 'future_theme' : 'dark',
        ),
      ),
    );
    await request.response.close();
    break;
  }
}

Future<void> _serveMutations(
  HttpServer server,
  List<_CapturedRequest> captured, {
  required int limit,
}) async {
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
    final response = switch (request.uri.path) {
      '/v1/preferences' => _preferencesResponse,
      '/v1/investor-profile' => _investorResponse,
      '/v1/astrology-profile' when request.method == 'DELETE' =>
        _deleteAstrologyResponse,
      '/v1/astrology-profile' => _astrologyResponse,
      '/v1/consents' => _consentResponse(
        (jsonDecode(encoded) as Map<String, dynamic>)['decision']! as String,
      ),
      _ => throw StateError('Unexpected request ${request.uri.path}'),
    };
    request.response.write(jsonEncode(response));
    await request.response.close();
    if (captured.length == limit) break;
  }
}

String _basePath(HttpServer server) =>
    'http://${server.address.address}:${server.port}';

Map<String, Object?> _accountResponse({
  required bool optionalResourcesAbsent,
  required String theme,
}) => {
  'data': {
    'status': 'active',
    'deletion_epoch': 0,
    'profile': _profile,
    'preferences': _preferences(theme),
    'onboarding': _onboarding,
    'investor_profile': optionalResourcesAbsent ? null : _investor,
    'astrology_profile': optionalResourcesAbsent ? null : _astrology,
  },
  'meta': _meta,
};

const _profile = <String, Object?>{
  'user_id': _userId,
  'deletion_epoch': 0,
  'display_name': 'Ritual Member',
  'locale': 'en-US',
  'avatar_media_id': null,
  'updated_at': '2026-08-25T12:00:00.000Z',
};

Map<String, Object?> _preferences(String theme) => {
  'user_id': _userId,
  'deletion_epoch': 0,
  'locale': 'en-US',
  'ritual_mode': 'tarot',
  'theme_mode': theme,
  'timezone': 'America/New_York',
  'version': 3,
};

const _onboarding = <String, Object?>{
  'user_id': _userId,
  'deletion_epoch': 0,
  'current_step': 'complete',
  'completed_steps': ['profile'],
  'completed_at': '2026-08-24T12:00:00.000Z',
  'version': 1,
};

const _investor = <String, Object?>{
  'user_id': _userId,
  'deletion_epoch': 0,
  'goal_type': 'long_term_growth',
  'time_horizon': 'long',
  'risk_comfort': 'moderate',
  'version': 5,
};

const _astrology = <String, Object?>{
  'user_id': _userId,
  'deletion_epoch': 0,
  'birth_date': '1994-05-14',
  'derived_profile_code': 'solar_builder',
  'algorithm_version': 'v1',
  'enabled_at': '2026-08-24T12:00:00.000Z',
  'version': 4,
};

const _preferencesResponse = <String, Object?>{
  'data': {
    'user_id': _userId,
    'deletion_epoch': 0,
    'locale': 'en-US',
    'ritual_mode': 'tarot',
    'theme_mode': 'dark',
    'timezone': 'America/New_York',
    'version': 4,
  },
  'meta': _meta,
};
const _investorResponse = <String, Object?>{'data': _investor, 'meta': _meta};
const _astrologyResponse = <String, Object?>{'data': _astrology, 'meta': _meta};
const _deleteAstrologyResponse = <String, Object?>{
  'data': {'removed': true},
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

const _userId = '00000000-0000-4000-8000-000000000001';
const _meta = <String, Object?>{
  'request_id': '00000000-0000-4000-8000-000000000099',
  'server_time': '2026-08-25T12:00:00.000Z',
};
