// ignore_for_file: prefer_initializing_formals

import '../domain/member_scenario_model.dart';

abstract interface class MemberScenarioService {
  Future<List<MemberIntentionScenario>> listIntentions();
  Future<MemberIntentionScenario> getIntention(String intentionId);
  Future<MemberIntentionScenario> createIntention(
    MemberIntentionInput input,
    String idempotencyKey,
  );
  Future<MemberIntentionScenario> patchIntention(
    String intentionId,
    MemberIntentionInput input,
    int expectedVersion,
  );
  Future<MemberIntentionScenario> archiveIntention(
    String intentionId,
    int expectedVersion,
  );
  Future<HypotheticalFutureScenario?> getLatestFutureMirror(String intentionId);
  Future<HypotheticalFutureScenario> getFutureMirror(
    String intentionId,
    String runId,
  );
  Future<HypotheticalFutureScenario> createFutureMirror(
    String intentionId,
    HypotheticalScenarioInput input,
    String idempotencyKey,
  );
}

class MemberScenarioRepository {
  const MemberScenarioRepository({required MemberScenarioService service})
    : _service = service;

  final MemberScenarioService _service;

  Future<List<MemberIntentionScenario>> listIntentions() =>
      _service.listIntentions();
  Future<MemberIntentionScenario> getIntention(String id) =>
      _service.getIntention(id);
  Future<MemberIntentionScenario> createIntention(
    MemberIntentionInput input,
    String key,
  ) => _service.createIntention(input, key);
  Future<MemberIntentionScenario> patchIntention(
    String id,
    MemberIntentionInput input,
    int version,
  ) => _service.patchIntention(id, input, version);
  Future<MemberIntentionScenario> archiveIntention(String id, int version) =>
      _service.archiveIntention(id, version);
  Future<HypotheticalFutureScenario?> latest(String intentionId) =>
      _service.getLatestFutureMirror(intentionId);
  Future<HypotheticalFutureScenario> getRun(String intentionId, String runId) =>
      _service.getFutureMirror(intentionId, runId);
  Future<HypotheticalFutureScenario> createMirror(
    String intentionId,
    HypotheticalScenarioInput input,
    String key,
  ) => _service.createFutureMirror(intentionId, input, key);
}
