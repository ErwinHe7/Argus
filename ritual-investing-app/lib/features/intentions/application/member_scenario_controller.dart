// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../data/member_scenario_repository.dart';
import '../domain/member_scenario_model.dart';

enum MemberScenarioPhase {
  idle,
  loading,
  ready,
  empty,
  reviewRequired,
  saving,
  ambiguous,
  failure,
}

@immutable
class MemberScenarioState {
  const MemberScenarioState({
    this.phase = MemberScenarioPhase.idle,
    this.intentions = const [],
    this.selectedIntention,
    this.futureMirror,
    this.reviewedInput,
    this.message,
  });

  final MemberScenarioPhase phase;
  final List<MemberIntentionScenario> intentions;
  final MemberIntentionScenario? selectedIntention;
  final HypotheticalFutureScenario? futureMirror;
  final HypotheticalScenarioInput? reviewedInput;
  final String? message;

  MemberScenarioState copyWith({
    MemberScenarioPhase? phase,
    List<MemberIntentionScenario>? intentions,
    MemberIntentionScenario? selectedIntention,
    bool clearSelected = false,
    HypotheticalFutureScenario? futureMirror,
    bool clearFutureMirror = false,
    HypotheticalScenarioInput? reviewedInput,
    bool clearReview = false,
    String? message,
    bool clearMessage = false,
  }) => MemberScenarioState(
    phase: phase ?? this.phase,
    intentions: intentions ?? this.intentions,
    selectedIntention: clearSelected
        ? null
        : selectedIntention ?? this.selectedIntention,
    futureMirror: clearFutureMirror ? null : futureMirror ?? this.futureMirror,
    reviewedInput: clearReview ? null : reviewedInput ?? this.reviewedInput,
    message: clearMessage ? null : message ?? this.message,
  );
}

/// Owns authenticated member scenarios without reading brokerage state.
///
/// A Future Mirror command can only be sent from the exact immutable input
/// snapshot held in [MemberScenarioState.reviewedInput]. Transport ambiguity
/// never causes an automatic command retry.
class MemberScenarioController extends ChangeNotifier {
  // Named public dependencies keep composition explicit across libraries.
  MemberScenarioController({
    required MemberScenarioRepository repository,
    required String Function() createKey,
  }) : _repository = repository,
       _createKey = createKey;

  final MemberScenarioRepository _repository;
  final String Function() _createKey;
  MemberScenarioState _state = const MemberScenarioState();
  bool _disposed = false;

  MemberScenarioState get state => _state;

  Future<void> load() async {
    _set(
      _state.copyWith(phase: MemberScenarioPhase.loading, clearMessage: true),
    );
    try {
      final values = await _repository.listIntentions();
      _set(
        MemberScenarioState(
          phase: values.isEmpty
              ? MemberScenarioPhase.empty
              : MemberScenarioPhase.ready,
          intentions: List.unmodifiable(values),
        ),
      );
    } catch (_) {
      _set(
        _state.copyWith(
          phase: MemberScenarioPhase.failure,
          message: 'Intentions could not be loaded.',
        ),
      );
    }
  }

  Future<void> openIntention(String intentionId) async {
    _set(
      _state.copyWith(phase: MemberScenarioPhase.loading, clearMessage: true),
    );
    try {
      final intention = await _repository.getIntention(intentionId);
      final mirror = await _repository.latest(intentionId);
      _set(
        _state.copyWith(
          phase: MemberScenarioPhase.ready,
          selectedIntention: intention,
          futureMirror: mirror,
          clearFutureMirror: mirror == null,
          clearReview: true,
        ),
      );
    } catch (_) {
      _set(
        _state.copyWith(
          phase: MemberScenarioPhase.failure,
          message: 'This Intention could not be loaded.',
        ),
      );
    }
  }

  Future<void> createIntention(MemberIntentionInput input) async {
    _set(
      _state.copyWith(phase: MemberScenarioPhase.saving, clearMessage: true),
    );
    try {
      final value = await _repository.createIntention(input, _createKey());
      _replace(value, select: true);
    } on ScenarioAmbiguousFailure {
      _ambiguous('Creation status is unknown. Refresh before taking action.');
    } catch (_) {
      _failure('The Intention could not be created.');
    }
  }

  Future<void> patchSelected(MemberIntentionInput input) async {
    final selected = _state.selectedIntention;
    if (selected == null) return;
    _set(
      _state.copyWith(phase: MemberScenarioPhase.saving, clearMessage: true),
    );
    try {
      final value = await _repository.patchIntention(
        selected.id,
        input,
        selected.version,
      );
      _replace(value, select: true);
    } on ScenarioAmbiguousFailure {
      _ambiguous('Update status is unknown. Refresh before taking action.');
    } catch (_) {
      _failure('The Intention changed elsewhere or could not be updated.');
    }
  }

  Future<void> archiveSelected() async {
    final selected = _state.selectedIntention;
    if (selected == null) return;
    _set(
      _state.copyWith(phase: MemberScenarioPhase.saving, clearMessage: true),
    );
    try {
      final value = await _repository.archiveIntention(
        selected.id,
        selected.version,
      );
      _replace(value, select: true);
    } on ScenarioAmbiguousFailure {
      _ambiguous('Archive status is unknown. Refresh before taking action.');
    } catch (_) {
      _failure('The Intention changed elsewhere or could not be archived.');
    }
  }

  void reviewFutureMirror(HypotheticalScenarioInput input) {
    final selected = _state.selectedIntention;
    if (selected == null || selected.status != MemberIntentionStatus.active) {
      _failure('Choose an active Intention first.');
      return;
    }
    _set(
      _state.copyWith(
        phase: MemberScenarioPhase.reviewRequired,
        reviewedInput: input,
        clearMessage: true,
      ),
    );
  }

  Future<void> confirmFutureMirror() async {
    final selected = _state.selectedIntention;
    final reviewed = _state.reviewedInput;
    if (selected == null || reviewed == null) return;
    _set(
      _state.copyWith(phase: MemberScenarioPhase.saving, clearMessage: true),
    );
    try {
      final value = await _repository.createMirror(
        selected.id,
        reviewed,
        _createKey(),
      );
      _set(
        _state.copyWith(
          phase: MemberScenarioPhase.ready,
          futureMirror: value,
          clearReview: true,
        ),
      );
    } on ScenarioAmbiguousFailure {
      _set(
        _state.copyWith(
          phase: MemberScenarioPhase.ambiguous,
          clearReview: true,
          message: 'Generation status is unknown. Refresh the latest scenario; do not submit it again.',
        ),
      );
    } catch (_) {
      _failure('The hypothetical scenario could not be generated.');
    }
  }

  Future<void> openRun(String runId) async {
    final selected = _state.selectedIntention;
    if (selected == null) return;
    _set(
      _state.copyWith(phase: MemberScenarioPhase.loading, clearMessage: true),
    );
    try {
      final value = await _repository.getRun(selected.id, runId);
      _set(
        _state.copyWith(
          phase: MemberScenarioPhase.ready,
          futureMirror: value,
          clearReview: true,
        ),
      );
    } catch (_) {
      _failure('This hypothetical scenario could not be loaded.');
    }
  }

  Future<void> refreshSelected() async {
    final id = _state.selectedIntention?.id;
    if (id == null) {
      await load();
    } else {
      await openIntention(id);
    }
  }

  void cancelReview() {
    _set(_state.copyWith(phase: MemberScenarioPhase.ready, clearReview: true));
  }

  void _replace(MemberIntentionScenario value, {required bool select}) {
    final values = [..._state.intentions];
    final index = values.indexWhere((item) => item.id == value.id);
    if (index == -1) {
      values.insert(0, value);
    } else {
      values[index] = value;
    }
    _set(
      _state.copyWith(
        phase: MemberScenarioPhase.ready,
        intentions: List.unmodifiable(values),
        selectedIntention: select ? value : null,
        clearMessage: true,
      ),
    );
  }

  void _ambiguous(String message) => _set(
    _state.copyWith(phase: MemberScenarioPhase.ambiguous, message: message),
  );

  void _failure(String message) => _set(
    _state.copyWith(phase: MemberScenarioPhase.failure, message: message),
  );

  void _set(MemberScenarioState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
