import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import '../domain/admin_models.dart';
import '../features/starpath/data/starpath_admin_gateway.dart';
import '../features/starpath/domain/starpath_editorial_models.dart';

class AdminIdempotencyRetryInterceptor extends Interceptor {
  AdminIdempotencyRetryInterceptor(this._dio);
  final Dio _dio;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    final hasKey = request.headers['idempotency-key'] is String;
    final alreadyRetried = request.extra['admin_network_retry'] == true;
    if (err.response != null || !hasKey || alreadyRetried) {
      handler.next(err);
      return;
    }
    request.extra['admin_network_retry'] = true;
    try {
      handler.resolve(await _dio.fetch<Object?>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}

class AdminAuthorizationFailureInterceptor extends Interceptor {
  AdminAuthorizationFailureInterceptor(this.onDenied);
  final void Function(int statusCode) onDenied;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;
    if (statusCode == 401 || statusCode == 403) onDenied(statusCode!);
    handler.next(err);
  }
}

class AdminCommandKeyFactory {
  const AdminCommandKeyFactory();

  String next(String action, String identity) {
    final random = Random.secure();
    final bytes = List<int>.generate(12, (_) => random.nextInt(256));
    final nonce = base64Url.encode(bytes).replaceAll('=', '');
    final scope = base64Url
        .encode(utf8.encode('$action:$identity'))
        .replaceAll('=', '')
        .substring(0, 8);
    return 'cmd-$scope-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-$nonce';
  }
}

abstract interface class AdminGateway implements StarpathAdminGateway {
  Future<AdminStaffSession> loadSession();
  Future<List<AdminRecord>> list(AdminDestination destination);
  Future<AdminRecord> getEditorial(AdminRecord record);
  Future<void> createDraft(
    AdminDestination destination,
    String slug,
    Map<String, Object?> payload,
  );
  Future<void> createRevision(
    AdminDestination destination,
    AdminRecord record,
    Map<String, Object?> payload,
  );
  Future<void> patchRevision(
    AdminDestination destination,
    AdminRecord record,
    Map<String, Object?> payload,
  );
  Future<void> preview(AdminDestination destination, AdminRecord record);
  Future<void> requestReview(AdminDestination destination, AdminRecord record);
  Future<void> decideReview(
    AdminDestination destination,
    AdminRecord record,
    AdminReviewDecision decision,
  );
  Future<void> publish(AdminDestination destination, AdminRecord record);
  Future<void> withdraw(AdminDestination destination, AdminRecord record);
  Future<void> createCatalog(
    AdminDestination destination,
    Map<String, Object?> payload,
  );
  Future<void> patchCatalog(
    AdminDestination destination,
    AdminRecord record,
    Map<String, Object?> payload,
  );
  Future<void> appendAssetMetric(
    AdminRecord record,
    Map<String, Object?> payload,
  );
  Future<void> createSchedule(Map<String, Object?> payload);
  Future<void> patchSchedule(AdminRecord record, Map<String, Object?> payload);
  Future<void> withdrawSchedule(AdminRecord record);
  Future<void> verifyCovenQualification(
    String qualificationId,
    Map<String, Object?> payload,
  );
  Future<void> createMediaUpload(Map<String, Object?> payload);
  Future<void> completeMedia(AdminRecord record, Map<String, Object?> payload);
  Future<void> retireMedia(AdminRecord record);
  Future<void> openModerationCase(
    AdminRecord report,
    Map<String, Object?> payload,
  );
  Future<void> decideModerationCase(
    AdminRecord record,
    Map<String, Object?> payload,
  );
  Future<void> retryPrivacy(AdminRecord record);
  Future<void> retryJob(AdminRecord record);
}

class OpenApiAdminGateway implements AdminGateway {
  OpenApiAdminGateway(
    this._client, {
    this.commandKeys = const AdminCommandKeyFactory(),
  });
  final RitualInvestingApiClient _client;
  final AdminCommandKeyFactory commandKeys;

  static const _secure = <String, Object?>{
    'secure': [
      {'type': 'http', 'scheme': 'bearer', 'name': 'SupabaseBearer'},
    ],
  };

  AdminDestination get _starpathDestination => adminDestinations.firstWhere(
    (destination) => destination.editorialKind == 'starpath_lesson',
  );

  @override
  Future<List<AdminRecord>> listStarpathLessons() => list(_starpathDestination);

  @override
  Future<AdminRecord> loadStarpathRevision(AdminRecord record) async {
    final detail = await getEditorial(record);
    final revisionId = detail.revisionId;
    if (revisionId == null) return detail;
    final authority = await AdminStarpathApi(_client.dio)
        .getAdminStarpathRevision(revisionId: revisionId);
    final authorityData = authority.data?.data;
    return AdminRecord(
      id: detail.id,
      title: detail.title,
      status: detail.status,
      version: detail.version,
      revisionId: detail.revisionId,
      etag: detail.etag,
      payload: {
        ...?detail.payload,
        if (authorityData is Map)
          '_authority': Map<String, Object?>.from(authorityData),
      },
    );
  }

  @override
  Future<void> createStarpathLesson(
    String slug,
    Map<String, Object?> payload,
  ) => createDraft(_starpathDestination, slug, payload);

  @override
  Future<void> createStarpathCorrection(
    AdminRecord record,
    Map<String, Object?> payload,
  ) => createRevision(_starpathDestination, record, payload);

  @override
  Future<void> saveStarpathDraft(
    AdminRecord record,
    Map<String, Object?> payload,
  ) => patchRevision(_starpathDestination, record, payload);

  @override
  Future<void> submitStarpathRevision({
    required String revisionId,
    required String policyVersion,
  }) async {
    await AdminStarpathApi(_client.dio).submitAdminStarpathRevision(
      revisionId: revisionId,
      submitAdminStarpathRevisionRequest: SubmitAdminStarpathRevisionRequest(
        policyVersion: policyVersion,
      ),
    );
  }

  @override
  Future<void> reviewStarpathRevision({
    required String revisionId,
    required StarpathReviewDiscipline discipline,
    required StarpathReviewDecision decision,
    required String reason,
  }) async {
    final generatedDiscipline = switch (discipline) {
      StarpathReviewDiscipline.factual =>
        ReviewAdminStarpathRevisionRequestDisciplineEnum.factual,
      StarpathReviewDiscipline.compliance =>
        ReviewAdminStarpathRevisionRequestDisciplineEnum.compliance,
    };
    final generatedDecision = switch (decision) {
      StarpathReviewDecision.approved =>
        ReviewAdminStarpathRevisionRequestDecisionEnum.approved,
      StarpathReviewDecision.changesRequested =>
        ReviewAdminStarpathRevisionRequestDecisionEnum.changesRequested,
      StarpathReviewDecision.rejected =>
        ReviewAdminStarpathRevisionRequestDecisionEnum.rejected,
    };
    await AdminStarpathApi(_client.dio).reviewAdminStarpathRevision(
      revisionId: revisionId,
      reviewAdminStarpathRevisionRequest: ReviewAdminStarpathRevisionRequest(
        discipline: generatedDiscipline,
        decision: generatedDecision,
        reason: reason,
      ),
    );
  }

  @override
  Future<void> publishStarpathManifest({
    required String manifestId,
    required String reason,
  }) async {
    await AdminStarpathApi(_client.dio).publishAdminStarpathManifest(
      manifestId: manifestId,
      publishAdminStarpathManifestRequest: PublishAdminStarpathManifestRequest(
        reason: reason,
      ),
    );
  }

  @override
  Future<AdminStaffSession> loadSession() async {
    final response = await _client.dio.get<Object?>(
      '/v1/admin/session',
      options: Options(extra: _secure),
    );
    final data = _data(response.data);
    final permissions = data['permissions'];
    final revocationEpoch = data['revocation_epoch'];
    if (data['user_id'] is! String ||
        data['display_label'] is! String ||
        permissions is! List ||
        revocationEpoch is! num ||
        revocationEpoch.toInt() != revocationEpoch) {
      throw const FormatException('Invalid Supabase staff session');
    }
    return AdminStaffSession(
      staffId: data['user_id']! as String,
      displayLabel: data['display_label']! as String,
      permissions: permissions.whereType<String>().toSet(),
      revocationEpoch: revocationEpoch.toInt(),
    );
  }

  @override
  Future<List<AdminRecord>> list(AdminDestination destination) async {
    final query = <String, Object?>{'limit': 20};
    if (destination.editorialKind != null) {
      query['kind'] = destination.editorialKind;
    }
    final response = await _client.dio.get<Object?>(
      destination.apiPath,
      queryParameters: query,
      options: Options(extra: _secure),
    );
    final values = _dataValue(response.data);
    if (values is! List) {
      throw const FormatException('Invalid admin collection envelope');
    }
    return values.map(_decodeRecord).toList(growable: false);
  }

  @override
  Future<AdminRecord> getEditorial(AdminRecord record) async {
    final response = await _client.dio.get<Object?>(
      '/v1/admin/editorial/${record.id}',
      options: Options(extra: _secure),
    );
    final detail = _data(response.data);
    final revision = detail['revision'];
    if (revision is! Map) {
      throw const FormatException('Editorial revision is missing');
    }
    final revisionData = Map<String, Object?>.from(revision);
    return _decodeRecord({
      ...detail,
      'revision_id': revisionData['id'] ?? detail['revision_id'],
      'revision_number': revisionData['revision_number'],
      'version': revisionData['version'],
      'revision_state': revisionData['state'],
      'etag': revisionData['etag'],
      'payload': revisionData['payload'],
    });
  }

  @override
  Future<void> createDraft(
    AdminDestination destination,
    String slug,
    Map<String, Object?> payload,
  ) async {
    final kind = destination.editorialKind;
    if (kind == null) throw UnsupportedError('Not an editorial workspace');
    await _client.dio.post<Object?>(
      '/v1/admin/editorial',
      data: {'kind': kind, 'slug': slug, 'payload': payload},
      options: Options(extra: _secure),
    );
  }

  @override
  Future<void> createRevision(
    AdminDestination destination,
    AdminRecord record,
    Map<String, Object?> payload,
  ) =>
      _post('/v1/admin/editorial/${record.id}/revisions', {'payload': payload});

  @override
  Future<void> patchRevision(
    AdminDestination destination,
    AdminRecord record,
    Map<String, Object?> payload,
  ) async {
    final revision = _revision(record);
    await _client.dio.patch<Object?>(
      '/v1/admin/editorial/${record.id}/revisions/$revision',
      data: {'payload': payload},
      options: Options(headers: {'if-match': record.etag}, extra: _secure),
    );
  }

  @override
  Future<void> preview(AdminDestination destination, AdminRecord record) async {
    await _client.dio.get<Object?>(
      '/v1/admin/editorial/${record.id}',
      options: Options(extra: _secure),
    );
  }

  @override
  Future<void> requestReview(
    AdminDestination destination,
    AdminRecord record,
  ) => _editorialCommand(destination, record, 'request_review');
  @override
  Future<void> decideReview(
    AdminDestination destination,
    AdminRecord record,
    AdminReviewDecision decision,
  ) => _editorialCommand(destination, record, decision.wireValue);
  @override
  Future<void> publish(AdminDestination destination, AdminRecord record) =>
      _editorialCommand(destination, record, 'publish');
  @override
  Future<void> withdraw(AdminDestination destination, AdminRecord record) =>
      _editorialCommand(destination, record, 'withdraw');

  Future<void> _editorialCommand(
    AdminDestination destination,
    AdminRecord record,
    String action,
  ) => _post('/v1/admin/editorial/${record.id}/commands', {
    'action': action,
    'revision_id': action == 'withdraw' ? null : _revision(record),
    'reason': 'Reviewed staff editorial transition.',
    'high_trust': destination.highTrust,
  });

  Future<void> _post(String path, Map<String, Object?> data) async {
    await _client.dio.post<Object?>(
      path,
      data: data,
      options: Options(extra: _secure),
    );
  }

  @override
  Future<void> retryPrivacy(AdminRecord record) => _retryOperation(
    record,
    action: 'admin_privacy_retry',
    path: '/v1/admin/operations/privacy/${record.id}/retry',
  );
  @override
  Future<void> retryJob(AdminRecord record) => _retryOperation(
    record,
    action: 'admin_job_retry',
    path: '/v1/admin/operations/jobs/${record.id}/retry',
  );

  Future<void> _retryOperation(
    AdminRecord record, {
    required String action,
    required String path,
  }) async {
    final stepUp = await _client.dio.post<Object?>(
      '/v1/admin/step-up',
      data: {'action': action, 'target_id': record.id},
      options: Options(extra: _secure),
    );
    final receipt = _data(stepUp.data)['receipt'];
    if (receipt is! String) {
      throw const FormatException('Missing action-bound staff receipt');
    }
    await _client.dio.post<Object?>(
      path,
      data: {'step_up_receipt': receipt},
      options: Options(
        headers: {'idempotency-key': commandKeys.next(action, record.id)},
        extra: _secure,
      ),
    );
  }

  Map<String, Object?> _data(Object? envelope) {
    final value = _dataValue(envelope);
    if (value is! Map) throw const FormatException('Invalid admin envelope');
    return Map<String, Object?>.from(value);
  }

  Object? _dataValue(Object? envelope) {
    if (envelope is Map) return envelope['data'];
    final json = (envelope as dynamic)?.toJson();
    return json is Map ? json['data'] : null;
  }

  AdminRecord _decodeRecord(Object? value) {
    if (value is! Map) throw const FormatException('Invalid admin record');
    final item = Map<String, Object?>.from(value);
    final id = item['id'] ?? item['correlation_id'];
    if (id is! String) {
      throw const FormatException('Admin record identity is missing');
    }
    final numericVersion = item['version'] ?? item['revision_number'] ?? 1;
    final version =
        numericVersion is num &&
            numericVersion.isFinite &&
            numericVersion.toInt() == numericVersion
        ? numericVersion.toInt()
        : 1;
    return AdminRecord(
      id: id,
      title:
          (item['slug'] ??
                  item['job_type'] ??
                  item['request_type'] ??
                  item['kind'] ??
                  item['action'] ??
                  'Redacted operation')
              .toString(),
      status:
          (item['revision_state'] ??
                  item['status'] ??
                  item['outcome'] ??
                  'unknown')
              .toString(),
      version: version,
      revisionId: item['revision_id'] as String?,
      etag: item['etag'] is String ? item['etag']! as String : '"v$version"',
      payload: item['payload'] is Map
          ? Map<String, Object?>.from(item['payload']! as Map)
          : null,
    );
  }

  String _revision(AdminRecord record) =>
      record.revisionId ?? (throw StateError('No revision is available'));
  Never _unsupported() => throw UnsupportedError(
    'This retained Supabase admin exposes editorial and redacted operations only.',
  );

  @override
  Future<void> createCatalog(
    AdminDestination destination,
    Map<String, Object?> payload,
  ) async => _unsupported();
  @override
  Future<void> patchCatalog(
    AdminDestination destination,
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => _unsupported();
  @override
  Future<void> appendAssetMetric(
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => _unsupported();
  @override
  Future<void> createSchedule(Map<String, Object?> payload) async =>
      _unsupported();
  @override
  Future<void> patchSchedule(
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => _unsupported();
  @override
  Future<void> withdrawSchedule(AdminRecord record) async => _unsupported();
  @override
  Future<void> verifyCovenQualification(
    String qualificationId,
    Map<String, Object?> payload,
  ) async => _unsupported();
  @override
  Future<void> createMediaUpload(Map<String, Object?> payload) async =>
      _unsupported();
  @override
  Future<void> completeMedia(
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => _unsupported();
  @override
  Future<void> retireMedia(AdminRecord record) async => _unsupported();
  @override
  Future<void> openModerationCase(
    AdminRecord report,
    Map<String, Object?> payload,
  ) async => _unsupported();
  @override
  Future<void> decideModerationCase(
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => _unsupported();
}

class FixtureAdminGateway implements AdminGateway {
  FixtureAdminGateway({List<AdminRecord> records = const []})
    : records = List.of(records);
  final List<AdminRecord> records;
  final List<String> transitions = [];
  Map<String, Object?>? lastPatchedPayload;
  Map<String, Object?>? lastDraftPayload;

  @override
  Future<List<AdminRecord>> listStarpathLessons() async => records;

  @override
  Future<AdminRecord> loadStarpathRevision(AdminRecord record) async => record;

  @override
  Future<void> createStarpathLesson(
    String slug,
    Map<String, Object?> payload,
  ) async {
    lastDraftPayload = payload;
    transitions.add('starpath-draft:$slug');
  }

  @override
  Future<void> createStarpathCorrection(
    AdminRecord record,
    Map<String, Object?> payload,
  ) async {
    lastDraftPayload = payload;
    transitions.add('starpath-correction:${record.id}');
  }

  @override
  Future<void> saveStarpathDraft(
    AdminRecord record,
    Map<String, Object?> payload,
  ) async {
    lastPatchedPayload = payload;
    transitions.add('starpath-save:${record.id}');
  }

  @override
  Future<void> submitStarpathRevision({
    required String revisionId,
    required String policyVersion,
  }) async => transitions.add('starpath-submit:$revisionId:$policyVersion');

  @override
  Future<void> reviewStarpathRevision({
    required String revisionId,
    required StarpathReviewDiscipline discipline,
    required StarpathReviewDecision decision,
    required String reason,
  }) async => transitions.add(
    'starpath-review:${discipline.wireValue}:${decision.wireValue}:$revisionId',
  );

  @override
  Future<void> publishStarpathManifest({
    required String manifestId,
    required String reason,
  }) async => transitions.add('starpath-publish:$manifestId');
  @override
  Future<AdminStaffSession> loadSession() async => const AdminStaffSession(
    staffId: 'fixture-staff',
    displayLabel: 'Fixture operator',
    permissions: AdminPermission.all,
    revocationEpoch: 0,
  );
  @override
  Future<List<AdminRecord>> list(AdminDestination destination) async => records;
  @override
  Future<AdminRecord> getEditorial(AdminRecord record) async => record;
  @override
  Future<void> createDraft(
    AdminDestination destination,
    String slug,
    Map<String, Object?> payload,
  ) async {
    lastDraftPayload = payload;
    transitions.add('draft:$slug');
  }

  @override
  Future<void> createRevision(
    AdminDestination destination,
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => transitions.add('revision:${record.id}');
  @override
  Future<void> patchRevision(
    AdminDestination destination,
    AdminRecord record,
    Map<String, Object?> payload,
  ) async {
    lastPatchedPayload = payload;
    transitions.add('edit:${record.id}');
  }

  @override
  Future<void> preview(
    AdminDestination destination,
    AdminRecord record,
  ) async => transitions.add('preview:${record.id}');
  @override
  Future<void> requestReview(
    AdminDestination destination,
    AdminRecord record,
  ) async {
    transitions.add('review:${record.id}:${record.revisionId}');
    _updateStatus(record.id, 'in_review');
  }

  @override
  Future<void> decideReview(
    AdminDestination destination,
    AdminRecord record,
    AdminReviewDecision decision,
  ) async {
    transitions.add('${decision.wireValue}:${record.id}');
    _updateStatus(record.id, decision.wireValue);
  }

  @override
  Future<void> publish(AdminDestination destination, AdminRecord record) async {
    transitions.add('publish:${record.id}:${record.revisionId}');
    _updateStatus(record.id, 'published');
  }

  @override
  Future<void> withdraw(
    AdminDestination destination,
    AdminRecord record,
  ) async {
    transitions.add('withdraw:${record.id}');
    _updateStatus(record.id, 'withdrawn');
  }

  @override
  Future<void> createCatalog(
    AdminDestination destination,
    Map<String, Object?> payload,
  ) async => transitions.add('catalog-create:${destination.route}');
  @override
  Future<void> patchCatalog(
    AdminDestination destination,
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => transitions.add('catalog-patch:${record.id}');
  @override
  Future<void> appendAssetMetric(
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => transitions.add('asset-metric:${record.id}');
  @override
  Future<void> createSchedule(Map<String, Object?> payload) async =>
      transitions.add('schedule-create');
  @override
  Future<void> patchSchedule(
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => transitions.add('schedule-patch:${record.id}');
  @override
  Future<void> withdrawSchedule(AdminRecord record) async =>
      transitions.add('schedule-withdraw:${record.id}');
  @override
  Future<void> verifyCovenQualification(
    String qualificationId,
    Map<String, Object?> payload,
  ) async => transitions.add('coven-verify:$qualificationId');
  @override
  Future<void> createMediaUpload(Map<String, Object?> payload) async =>
      transitions.add('media-upload');
  @override
  Future<void> completeMedia(
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => transitions.add('media-complete:${record.id}');
  @override
  Future<void> retireMedia(AdminRecord record) async =>
      transitions.add('media-retire:${record.id}');
  @override
  Future<void> openModerationCase(
    AdminRecord report,
    Map<String, Object?> payload,
  ) async => transitions.add('moderation-open:${report.id}');
  @override
  Future<void> decideModerationCase(
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => transitions.add('moderation-decide:${record.id}');
  @override
  Future<void> retryPrivacy(AdminRecord record) async =>
      transitions.add('privacy-retry:${record.id}');
  @override
  Future<void> retryJob(AdminRecord record) async =>
      transitions.add('job-retry:${record.id}');

  void _updateStatus(String id, String status) {
    final index = records.indexWhere((record) => record.id == id);
    if (index < 0) return;
    final record = records[index];
    records[index] = AdminRecord(
      id: record.id,
      title: record.title,
      status: status,
      version: record.version + 1,
      revisionId: record.revisionId,
      etag: '"v${record.version + 1}"',
      payload: record.payload,
    );
  }
}
