import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    hide RitualInterest;
import 'package:ritual_investing_app/core/api/date_only_request_interceptor.dart';
import 'package:ritual_investing_app/features/onboarding/data/onboarding_repository.dart';
import 'package:ritual_investing_app/features/onboarding/domain/onboarding_draft.dart';

void main() {
  test(
    'canonical command is stable and changes when reviewed answers change',
    () {
      final first = OnboardingFinalizationCommand.fromDraft(
        _draft(),
        expectedOnboardingVersion: 3,
      );
      final retry = OnboardingFinalizationCommand.fromDraft(
        _draft(),
        expectedOnboardingVersion: 3,
      );
      final edited = OnboardingFinalizationCommand.fromDraft(
        _draft().copyWith(risk: RiskComfort.high),
        expectedOnboardingVersion: 3,
      );

      expect(first.canonicalPayloadHash, hasLength(64));
      expect(first.idempotencyKey, first.canonicalPayloadHash);
      expect(retry.idempotencyKey, first.idempotencyKey);
      expect(edited.idempotencyKey, isNot(first.idempotencyKey));
      expect(first.payload, {
        'schema_version': 2,
        'expected_onboarding_version': 3,
        'investing': {
          'experience': 'new',
          'goal_type': 'long_term_growth',
          'time_horizon': 'long',
          'risk_comfort': 'moderate',
          'contribution_rhythm': 'monthly',
        },
        'ritual': {
          'familiarity': 'new',
          'language_preference': 'practical',
          'interests': ['practical_research'],
        },
        'astrology': {'enabled': false},
        'consents': {
          'terms': {'policy_version': '2026-08', 'decision': 'accepted'},
          'privacy': {'policy_version': '2026-08', 'decision': 'accepted'},
          'demo_disclosure': {
            'policy_version': '2026-08',
            'decision': 'accepted',
          },
          'astrology': {'policy_version': '2026-08', 'decision': 'declined'},
        },
      });
      expect(first.payload.toString(), isNot(contains('religion')));
      expect(first.payload.toString(), isNot(contains('derived_profile')));
      expect(first.payload.toString(), isNot(contains('birth_time')));
      expect(first.payload.toString(), isNot(contains('birth_place')));
    },
  );

  test('astrology payload sends date only after explicit opt-in', () {
    final command = OnboardingFinalizationCommand.fromDraft(
      _draft().copyWith(
        astrologyEnabled: true,
        birthDate: DateTime.utc(1994, 5, 14),
      ),
      expectedOnboardingVersion: 1,
    );

    expect(command.payload['astrology'], {
      'enabled': true,
      'birth_date': '1994-05-14',
    });
    expect((command.payload['consents'] as Map<String, Object?>)['astrology'], {
      'policy_version': '2026-08',
      'decision': 'accepted',
    });
  });

  test(
    'finalization rejects non-calendar, future, and non-date-only values',
    () {
      for (final birthDate in [
        DateTime.utc(2026, 8, 25),
        DateTime.utc(1899, 12, 31),
        DateTime.utc(1994, 5, 14, 12),
        DateTime(1994, 5, 14),
      ]) {
        expect(
          () => OnboardingFinalizationCommand.fromDraft(
            _draft().copyWith(astrologyEnabled: true, birthDate: birthDate),
            expectedOnboardingVersion: 1,
            now: () => DateTime.utc(2026, 8, 24),
          ),
          throwsArgumentError,
          reason: birthDate.toIso8601String(),
        );
      }
    },
  );

  test(
    'generated repository sends the atomic command and maps bootstrap',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requestSeen = Completer<_CapturedRequest>();
      unawaited(() async {
        final request = await server.first;
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        requestSeen.complete(
          _CapturedRequest(
            request.headers.value('idempotency-key'),
            body as Map<String, dynamic>,
          ),
        );
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(_completedBootstrapResponse));
        await request.response.close();
      }());
      final client = RitualInvestingApiClient(
        basePathOverride: 'http://${server.address.address}:${server.port}',
        interceptors: const [],
      );
      final repository = GeneratedOnboardingRepository(client);
      final command = OnboardingFinalizationCommand.fromDraft(
        _draft(),
        expectedOnboardingVersion: 3,
      );

      final result = await repository.finalize(command);
      final captured = await requestSeen.future;

      expect(captured.idempotencyKey, command.idempotencyKey);
      expect(captured.body, command.payload);
      expect(result.accountId, '00000000-0000-4000-8000-000000000001');
      expect(result.onboarding.isComplete, isTrue);
      expect(result.onboarding.version, 4);
      expect(result.canEnterMemberShell, isTrue);
    },
  );

  test(
    'generated opt-in request emits exact date-only JSON on the wire',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requestSeen = Completer<Map<String, dynamic>>();
      unawaited(() async {
        final request = await server.first;
        requestSeen.complete(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(_completedBootstrapResponse));
        await request.response.close();
      }());
      final client = RitualInvestingApiClient(
        basePathOverride: 'http://${server.address.address}:${server.port}',
        interceptors: const [],
      );
      final repository = GeneratedOnboardingRepository(client);
      final command = OnboardingFinalizationCommand.fromDraft(
        _draft().copyWith(
          astrologyEnabled: true,
          birthDate: DateTime.utc(1994, 5, 14),
        ),
        expectedOnboardingVersion: 3,
        now: () => DateTime.utc(2026, 8, 24),
      );

      await repository.finalize(command);

      final astrology = (await requestSeen.future)['astrology'];
      expect(astrology, {'enabled': true, 'birth_date': '1994-05-14'});
    },
  );

  test('generated astrology settings PUT emits date-only JSON', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requestSeen = Completer<Map<String, dynamic>>();
    unawaited(() async {
      final request = await server.first;
      requestSeen.complete(
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>,
      );
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_astrologyProfileResponse));
      await request.response.close();
    }());
    final client = RitualInvestingApiClient(
      basePathOverride: 'http://${server.address.address}:${server.port}',
      interceptors: const [],
    );
    ensureDateOnlyRequestSerialization(client.dio);

    await AccountApi(client.dio).putAstrologyProfile(
      putAstrologyProfileRequest: PutAstrologyProfileRequest(
        birthDate: DateTime.utc(1994, 5, 14),
      ),
    );

    expect(await requestSeen.future, {'birth_date': '1994-05-14'});
  });
}

class _CapturedRequest {
  const _CapturedRequest(this.idempotencyKey, this.body);
  final String? idempotencyKey;
  final Map<String, dynamic> body;
}

const _completedBootstrapResponse = <String, Object?>{
  'data': {
    'account': {
      'id': '00000000-0000-4000-8000-000000000001',
      'status': 'active',
    },
    'astrology_profile': null,
    'contract_version': '1.0.0',
    'default_portfolio': {
      'currency': 'USD',
      'id': '00000000-0000-4000-8000-000000000002',
      'name': 'Demo Portfolio',
      'status': 'active',
      'version': 1,
    },
    'entitlement': {'plan_code': 'demo-free', 'status': 'active'},
    'investor_profile': {
      'contribution_rhythm': 'monthly',
      'experience': 'new',
      'goal_type': 'long_term_growth',
      'is_demo': true,
      'risk_comfort': 'moderate',
      'time_horizon': 'long',
      'version': 1,
    },
    'onboarding': {
      'cohort': 'member_v2',
      'completed_at': '2026-08-24T12:00:00.000Z',
      'completed_steps': ['welcome', 'ritual', 'profile'],
      'current_step': 'complete',
      'schema_version': 2,
      'version': 4,
    },
    'preferences': {
      'locale': 'en-US',
      'ritual_familiarity': 'new',
      'ritual_interests': ['practical_research'],
      'ritual_language': 'practical',
      'ritual_mode': 'tarot',
      'theme_mode': 'system',
      'timezone': 'UTC',
      'version': 1,
    },
    'profile': {'display_name': 'Member', 'locale': 'en-US'},
    'reset_generation': 0,
    'server_time': '2026-08-24T12:00:00.000Z',
  },
  'meta': {'request_id': '00000000-0000-4000-8000-000000000003'},
};

const _astrologyProfileResponse = <String, Object?>{
  'data': {
    'algorithm_version': 'v1',
    'birth_date': '1994-05-14',
    'derived_profile_code': 'lunar_patient',
    'enabled_at': '2026-08-24T12:00:00.000Z',
    'version': 1,
  },
  'meta': {'request_id': '00000000-0000-4000-8000-000000000004'},
};

OnboardingDraft _draft() => const OnboardingDraft(
  experience: InvestingExperience.newToInvesting,
  goal: InvestmentGoal.longTermGrowth,
  horizon: InvestmentHorizon.long,
  risk: RiskComfort.moderate,
  contributionRhythm: ContributionRhythm.monthly,
  ritualLanguage: RitualLanguage.practical,
  ritualFamiliarity: RitualFamiliarity.newToRitual,
  ritualInterests: {RitualInterest.practicalResearch},
  astrologyEnabled: false,
  termsAccepted: true,
  privacyAccepted: true,
  demoAccepted: true,
);
