// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../application/admin_session_controller.dart';
import '../../../domain/admin_models.dart';
import '../data/starpath_admin_gateway.dart';
import '../domain/starpath_editorial_models.dart';

class StarpathWorkspaceController extends ChangeNotifier {
  StarpathWorkspaceController({
    required this.session,
    required StarpathAdminGateway gateway,
  }) : _gateway = gateway;

  final AdminSessionController session;
  final StarpathAdminGateway _gateway;
  List<AdminRecord> _records = const [];
  AdminRecord? _selected;
  StarpathLessonDraft? _lesson;
  bool _loading = false;
  String? _error;

  List<AdminRecord> get records => _records;
  AdminRecord? get selected => _selected;
  StarpathLessonDraft? get lesson => _lesson;
  bool get loading => _loading;
  String? get error => _error;
  bool get canWrite => session.permits(AdminPermission.editorialWrite);
  bool get canReviewFactual =>
      session.permits(AdminPermission.starpathFactualReview);
  bool get canReviewCompliance =>
      session.permits(AdminPermission.starpathComplianceReview);
  bool get canPublish => session.permits(AdminPermission.editorialPublish);

  Future<void> load() async {
    await _run(() async {
      final listed = await _gateway.listStarpathLessons();
      _records = await Future.wait(listed.map(_gateway.loadStarpathRevision));
      if (_selected != null) {
        _selectLocal(_recordWithId(_selected!.id));
      }
    }, reload: false);
  }

  Future<void> select(AdminRecord record) async {
    _selectLocal(record);
    notifyListeners();
  }

  Future<void> createLesson(String slug, StarpathLessonDraft draft) async {
    _requireValid(draft);
    await _run(() => _gateway.createStarpathLesson(slug, draft.toPayload()));
  }

  Future<void> saveDraft(StarpathLessonDraft draft) async {
    final record = _requireSelection();
    _requireValid(draft);
    await _run(() => _gateway.saveStarpathDraft(record, draft.toPayload()));
  }

  Future<void> createCorrection(StarpathLessonDraft draft) async {
    final record = _requireSelection();
    _requireValid(draft);
    await _run(
      () => _gateway.createStarpathCorrection(record, draft.toPayload()),
    );
  }

  Future<void> submit() async {
    final record = _requireSelection();
    final draft = _lesson ?? (throw StateError('No lesson is loaded'));
    _requireValid(draft);
    await _run(
      () => _gateway.submitStarpathRevision(
        revisionId: _revision(record),
        policyVersion: draft.policyVersion,
      ),
    );
  }

  Future<void> review(
    StarpathReviewDiscipline discipline,
    StarpathReviewDecision decision,
    String reason,
  ) async {
    final record = _requireSelection();
    final permitted = switch (discipline) {
      StarpathReviewDiscipline.factual => canReviewFactual,
      StarpathReviewDiscipline.compliance => canReviewCompliance,
    };
    if (!permitted || reason.trim().length < 8) {
      throw StateError(
        'A scoped reviewer and an explicit reason are required.',
      );
    }
    await _run(
      () => _gateway.reviewStarpathRevision(
        revisionId: _revision(record),
        discipline: discipline,
        decision: decision,
        reason: reason.trim(),
      ),
    );
  }

  Future<void> publishManifest(String manifestId, String reason) async {
    if (!canPublish || manifestPublicationIssues.isNotEmpty) {
      throw StateError('The exact eight-node manifest is not publishable.');
    }
    if (manifestId.trim().isEmpty || reason.trim().length < 8) {
      throw StateError(
        'A manifest identity and publication reason are required.',
      );
    }
    await _run(
      () => _gateway.publishStarpathManifest(
        manifestId: manifestId.trim(),
        reason: reason.trim(),
      ),
    );
  }

  List<String> get manifestPublicationIssues {
    final issues = <String>[];
    if (_records.length != 8) {
      issues.add(
        'Publication blocked: ${8 - _records.length} nodes are missing.',
      );
    }
    final lessons = _records
        .map((record) => record.payload)
        .whereType<Map<String, Object?>>()
        .map(StarpathLessonDraft.fromPayload)
        .toList(growable: false);
    if (lessons.length != _records.length ||
        lessons.any((lesson) => lesson.validationIssues.isNotEmpty)) {
      issues.add('Publication blocked: every node needs valid typed content.');
    }
    final positions = lessons
        .map((lesson) => '${lesson.pathwayOrdinal}:${lesson.pathwayPosition}')
        .toSet();
    if (_records.length == 8 && positions.length != 8) {
      issues.add(
        'Publication blocked: pathway positions are incomplete or duplicated.',
      );
    }
    if (_records.any((record) => record.status != 'approved')) {
      issues.add(
        'Publication blocked: every exact revision needs both approvals.',
      );
    }
    return List.unmodifiable(issues);
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool reload = true,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      if (reload) {
        final selectedId = _selected?.id;
        final listed = await _gateway.listStarpathLessons();
        _records = await Future.wait(listed.map(_gateway.loadStarpathRevision));
        _selectLocal(_recordWithId(selectedId));
      }
    } catch (error) {
      _error = error is DioException && error.response?.statusCode == 409
          ? 'This revision changed. Reload before continuing.'
          : 'The Starpath editorial transition could not be applied.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _selectLocal(AdminRecord? record) {
    _selected = record;
    _lesson = record?.payload == null
        ? null
        : StarpathLessonDraft.fromPayload(record!.payload!);
  }

  AdminRecord _requireSelection() =>
      _selected ?? (throw StateError('Select a Starpath revision first.'));
  String _revision(AdminRecord record) =>
      record.revisionId ?? (throw StateError('No revision is available.'));
  void _requireValid(StarpathLessonDraft draft) {
    if (!canWrite || draft.validationIssues.isNotEmpty) {
      throw StateError('The typed lesson is not ready for this transition.');
    }
  }

  AdminRecord? _recordWithId(String? id) {
    if (id == null) return null;
    for (final record in _records) {
      if (record.id == id) return record;
    }
    return null;
  }
}
