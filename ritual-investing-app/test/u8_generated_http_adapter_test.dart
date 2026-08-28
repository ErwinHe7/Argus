import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/features/intentions/data/generated_intention_api_service.dart';
import 'package:ritual_investing_app/features/intentions/domain/member_scenario_model.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';

const _intentionId = '00000000-0000-4000-8000-000000000801';
const _runId = '00000000-0000-4000-8000-000000000802';

void main() {
  test(
    'production adapter sends exact provider-neutral scenario input',
    () async {
      final adapter = _ScenarioAdapter();
      final service = GeneratedMemberScenarioApiService(
        RitualInvestingApiClient(
          dio: Dio(BaseOptions(baseUrl: 'https://argus.invalid'))
            ..httpClientAdapter = adapter,
        ),
      );
      final result = await service.createFutureMirror(
        _intentionId,
        HypotheticalScenarioInput(
          name: 'Calm path',
          baseline: const ExactScenarioMoney(
            minorUnits: '9007199254740991',
            currency: 'USD',
          ),
          monthlyContribution: const ExactScenarioMoney(
            minorUnits: '10001',
            currency: 'USD',
          ),
          lowReturnBps: -1000,
          midReturnBps: 400,
          highReturnBps: 2200,
          asOfDate: DateTime.utc(2026, 8, 28),
        ),
        'scenario-key-000001',
      );

      expect(result.points.single.lowMinor, '9007199254750000');
      expect(adapter.lastHeaders['idempotency-key'], 'scenario-key-000001');
      expect(adapter.lastBody, {
        'annual_return_bps': {'high': 2200, 'low': -1000, 'mid': 400},
        'as_of_date': '2026-08-28',
        'baseline': {'currency': 'USD', 'minor_units': '9007199254740991'},
        'monthly_contribution': {'currency': 'USD', 'minor_units': '10001'},
        'name': 'Calm path',
      });
      final serialized = jsonEncode(adapter.lastBody).toLowerCase();
      for (final forbidden in [
        'broker',
        'position',
        'balance',
        'account_id',
        'provider',
        'order',
        'credential',
        'ledger',
      ]) {
        expect(serialized, isNot(contains(forbidden)));
      }
    },
  );

  test('projection points accept one-based ordinals and reject gaps', () async {
    final adapter = _ScenarioAdapter();
    final service = GeneratedMemberScenarioApiService(
      RitualInvestingApiClient(
        dio: Dio(BaseOptions(baseUrl: 'https://argus.invalid'))
          ..httpClientAdapter = adapter,
      ),
    );

    final value = await service.getFutureMirror(_intentionId, _runId);
    expect(value.points.single.date, DateTime.utc(2028, 8, 28));

    adapter.pointOrdinal = 2;
    await expectLater(
      service.getFutureMirror(_intentionId, _runId),
      throwsA(isA<LoadFailure>()),
    );
  });

  test(
    'reviewed monetary input above the exact contract limit fails closed',
    () async {
      final adapter = _ScenarioAdapter();
      final service = GeneratedMemberScenarioApiService(
        RitualInvestingApiClient(
          dio: Dio(BaseOptions(baseUrl: 'https://argus.invalid'))
            ..httpClientAdapter = adapter,
        ),
      );

      await expectLater(
        service.createIntention(
          MemberIntentionInput(
            title: 'Too large',
            target: const ExactScenarioMoney(
              minorUnits: '9007199254740992',
              currency: 'USD',
            ),
            targetDate: DateTime.utc(2028, 8, 28),
          ),
          'scenario-key-000002',
        ),
        throwsA(isA<LoadFailure>()),
      );
      expect(adapter.calls, 0);
    },
  );
}

class _ScenarioAdapter implements HttpClientAdapter {
  int pointOrdinal = 1;
  Map<String, dynamic> lastBody = const {};
  Map<String, dynamic> lastHeaders = const {};
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (options.data case final String body) {
      lastBody = jsonDecode(body) as Map<String, dynamic>;
    }
    lastHeaders = Map.of(options.headers);
    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'annual_return_bps': {'high': 2200, 'low': -1000, 'mid': 400},
          'as_of_date': '2026-08-28',
          'assumption_version': 'member-entered-v1',
          'baseline': {'currency': 'USD', 'minor_units': '9007199254740991'},
          'generated_at': '2026-08-28T12:00:00.000Z',
          'id': _runId,
          'input_hash': 'a' * 64,
          'intention_id': _intentionId,
          'model_version': 'argus-hypothetical-v1',
          'monthly_contribution': {'currency': 'USD', 'minor_units': '10001'},
          'name': 'Calm path',
          'points': [
            {
              'high_amount_minor': '9007199254760000',
              'low_amount_minor': '9007199254750000',
              'mid_amount_minor': '9007199254755000',
              'ordinal': pointOrdinal,
              'projected_date': '2028-08-28',
            },
          ],
          'target_date': '2028-08-28',
          'uncertainty_disclosure': 'Hypothetical member-entered assumptions; not advice, a forecast, or brokerage performance.',
        },
        'meta': {'request_id': 'request-u9b'},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
