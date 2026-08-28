import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/features/intentions/application/member_scenario_controller.dart';
import 'package:ritual_investing_app/features/intentions/data/member_scenario_repository.dart';
import 'package:ritual_investing_app/features/intentions/domain/member_scenario_model.dart';

void main() {
  test(
    'generation requires confirmation of the exact reviewed input',
    () async {
      final service = _ScenarioService();
      final controller = MemberScenarioController(
        repository: MemberScenarioRepository(service: service),
        createKey: () => 'stable-key-000001',
      );
      addTearDown(controller.dispose);
      await controller.openIntention(_intention.id);

      controller.reviewFutureMirror(_input);
      expect(controller.state.phase, MemberScenarioPhase.reviewRequired);
      expect(controller.state.reviewedInput, same(_input));
      expect(service.createCalls, 0);

      await controller.confirmFutureMirror();

      expect(service.createCalls, 1);
      expect(service.lastInput, same(_input));
      expect(service.lastKey, 'stable-key-000001');
      expect(controller.state.futureMirror?.input, same(_input));
      expect(controller.state.reviewedInput, isNull);
    },
  );

  test('ambiguous generation is not automatically retried', () async {
    final service = _ScenarioService(ambiguous: true);
    final controller = MemberScenarioController(
      repository: MemberScenarioRepository(service: service),
      createKey: () => 'stable-key-000002',
    );
    addTearDown(controller.dispose);
    await controller.openIntention(_intention.id);
    controller.reviewFutureMirror(_input);

    await controller.confirmFutureMirror();

    expect(service.createCalls, 1);
    expect(controller.state.phase, MemberScenarioPhase.ambiguous);
    expect(controller.state.reviewedInput, isNull);
    expect(controller.state.message, contains('do not submit it again'));
  });
}

class _ScenarioService implements MemberScenarioService {
  _ScenarioService({this.ambiguous = false});

  final bool ambiguous;
  int createCalls = 0;
  HypotheticalScenarioInput? lastInput;
  String? lastKey;

  @override
  Future<HypotheticalFutureScenario> createFutureMirror(
    String intentionId,
    HypotheticalScenarioInput input,
    String idempotencyKey,
  ) async {
    createCalls++;
    lastInput = input;
    lastKey = idempotencyKey;
    if (ambiguous) throw const ScenarioAmbiguousFailure();
    return _mirror;
  }

  @override
  Future<MemberIntentionScenario> getIntention(String intentionId) async =>
      _intention;

  @override
  Future<HypotheticalFutureScenario?> getLatestFutureMirror(
    String intentionId,
  ) async => null;

  @override
  Future<List<MemberIntentionScenario>> listIntentions() async => [_intention];

  @override
  Future<MemberIntentionScenario> archiveIntention(
    String intentionId,
    int expectedVersion,
  ) => throw UnimplementedError();

  @override
  Future<MemberIntentionScenario> createIntention(
    MemberIntentionInput input,
    String idempotencyKey,
  ) => throw UnimplementedError();

  @override
  Future<HypotheticalFutureScenario> getFutureMirror(
    String intentionId,
    String runId,
  ) => throw UnimplementedError();

  @override
  Future<MemberIntentionScenario> patchIntention(
    String intentionId,
    MemberIntentionInput input,
    int expectedVersion,
  ) => throw UnimplementedError();
}

final _intention = MemberIntentionScenario(
  id: '00000000-0000-4000-8000-000000000801',
  title: 'Moonlit reserve',
  target: const ExactScenarioMoney(minorUnits: '250000', currency: 'USD'),
  targetDate: DateTime.utc(2028, 8, 28),
  status: MemberIntentionStatus.active,
  version: 1,
  createdAt: DateTime.utc(2026, 8, 28),
);

final _input = HypotheticalScenarioInput(
  name: 'Calm path',
  baseline: const ExactScenarioMoney(minorUnits: '100000', currency: 'USD'),
  monthlyContribution: const ExactScenarioMoney(
    minorUnits: '10001',
    currency: 'USD',
  ),
  lowReturnBps: -1000,
  midReturnBps: 400,
  highReturnBps: 2200,
  asOfDate: DateTime.utc(2026, 8, 28),
);

final _mirror = HypotheticalFutureScenario(
  id: '00000000-0000-4000-8000-000000000802',
  intentionId: _intention.id,
  input: _input,
  targetDate: _intention.targetDate,
  points: [
    HypotheticalScenarioPoint(
      date: DateTime.utc(2028, 8, 28),
      lowMinor: '110000',
      midMinor: '120000',
      highMinor: '130000',
    ),
  ],
  modelVersion: 'argus-hypothetical-v1',
  assumptionVersion: 'member-entered-v1',
  generatedAt: DateTime.utc(2026, 8, 28, 12),
  uncertaintyDisclosure:
      'Hypothetical member-entered assumptions; not a brokerage view.',
);
