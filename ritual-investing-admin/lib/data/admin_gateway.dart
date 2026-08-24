import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/generated/api.dart';

import '../domain/admin_models.dart';

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

abstract interface class AdminGateway {
  Future<AdminStaffSession> loadSession();
  Future<List<AdminRecord>> list(AdminDestination destination);
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
    String decision,
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

  @override
  Future<AdminStaffSession> loadSession() async {
    final data = (await _client.getAdminSessionApi().getAdminMe()).data?.data;
    if (data == null) throw const FormatException('Missing admin session');
    return AdminStaffSession(
      staffId: data.staffId,
      displayLabel: data.displayLabel,
      permissions: data.permissions.toSet(),
      revocationEpoch: data.revocationEpoch,
    );
  }

  @override
  Future<List<AdminRecord>> list(AdminDestination destination) async {
    final now = DateTime.now().toUtc();
    final response = await _client.dio.get<Map<String, Object?>>(
      destination.apiPath,
      queryParameters: destination.apiPath.endsWith('ritual-schedules')
          ? <String, Object?>{
              'from': DateTime.utc(
                now.year,
                1,
                1,
              ).toIso8601String().substring(0, 10),
              'to': DateTime.utc(
                now.year + 1,
                1,
                1,
              ).toIso8601String().substring(0, 10),
              'limit': 20,
            }
          : <String, Object?>{'limit': 20},
    );
    final values = response.data?['data'];
    if (values is! List) {
      throw const FormatException('Invalid admin collection envelope');
    }
    return values.map(_decodeRecord).toList(growable: false);
  }

  AdminRecord _decodeRecord(Object? value) {
    if (value is! Map) throw const FormatException('Invalid admin record');
    final item = Map<String, Object?>.from(value);
    final id = item['id'];
    if (id is! String) {
      throw const FormatException('Admin record identity is missing');
    }
    final revision = item['revision'] is Map
        ? Map<String, Object?>.from(item['revision']! as Map)
        : const <String, Object?>{};
    final versionValue = revision['version'] ?? item['version'];
    final etagValue = revision['etag'] ?? item['etag'];
    return AdminRecord(
      id: id,
      title:
          (item['title'] ??
                  item['name'] ??
                  item['slug'] ??
                  item['action'] ??
                  id)
              .toString(),
      status:
          (revision['state'] ??
                  item['status'] ??
                  item['state'] ??
                  item['outcome'] ??
                  'unknown')
              .toString(),
      version: versionValue is int ? versionValue : 1,
      revisionId: revision['id']?.toString(),
      etag: etagValue is String ? etagValue : '"v1"',
    );
  }

  @override
  Future<void> createDraft(
    AdminDestination destination,
    String slug,
    Map<String, Object?> payload,
  ) async => _client.dio.post<void>(
    destination.apiPath,
    data: <String, Object?>{'slug': slug, ...payload},
    options: _idempotent('draft', slug),
  );
  @override
  Future<void> createRevision(
    AdminDestination destination,
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => _client.dio.post<void>(
    '${destination.apiPath}/${record.id}/revisions',
    data: {'source_revision_id': _revision(record), 'payload': payload},
    options: _idempotent('revision', record.id),
  );
  @override
  Future<void> patchRevision(
    AdminDestination destination,
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => _client.dio.patch<void>(
    '${destination.apiPath}/${record.id}/revisions/${_revision(record)}',
    data: {'payload': payload},
    options: _conditional(record),
  );
  @override
  Future<void> preview(
    AdminDestination destination,
    AdminRecord record,
  ) async => _client.dio.get<void>(
    '${destination.apiPath}/${record.id}/revisions/${_revision(record)}/preview',
  );
  @override
  Future<void> requestReview(
    AdminDestination destination,
    AdminRecord record,
  ) async => _client.dio.post<void>(
    '${destination.apiPath}/${record.id}/revisions/${_revision(record)}/review-requests',
    data: const {'note': 'Submitted from the reviewed staff dashboard.'},
    options: _idempotent('review', _revision(record)),
  );
  @override
  Future<void> decideReview(
    AdminDestination destination,
    AdminRecord record,
    String decision,
  ) async => _client.dio.post<void>(
    '${destination.apiPath}/${record.id}/revisions/${_revision(record)}/review-decisions',
    data: {
      'decision': decision,
      'reason': 'Recorded from the reviewed staff dashboard.',
    },
    options: _idempotent('decision-$decision', _revision(record)),
  );
  @override
  Future<void> publish(
    AdminDestination destination,
    AdminRecord record,
  ) async => _client.dio.post<void>(
    '${destination.apiPath}/${record.id}/revisions/${_revision(record)}/publications',
    data: {
      'effective_at': DateTime.now().toUtc().toIso8601String(),
      'reason': 'Published from the reviewed staff dashboard.',
    },
    options: _idempotent('publish', _revision(record)),
  );
  @override
  Future<void> withdraw(
    AdminDestination destination,
    AdminRecord record,
  ) async => _client.dio.post<void>(
    '${destination.apiPath}/${record.id}/withdrawals',
    data: const {'reason': 'Withdrawn from the reviewed staff dashboard.'},
    options: _idempotent('withdraw', record.id),
  );
  @override
  Future<void> createCatalog(
    AdminDestination destination,
    Map<String, Object?> payload,
  ) async => _client.dio.post<void>(
    destination.apiPath,
    data: payload,
    options: _idempotent('catalog-create', destination.apiPath),
  );
  @override
  Future<void> patchCatalog(
    AdminDestination destination,
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => _client.dio.patch<void>(
    '${destination.apiPath}/${record.id}',
    data: payload,
    options: _conditional(record),
  );
  @override
  Future<void> appendAssetMetric(
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => _client.dio.post<void>(
    '/v1/admin/assets/${record.id}/metric-snapshots',
    data: payload,
    options: _idempotent('asset-metric', record.id),
  );
  @override
  Future<void> createSchedule(Map<String, Object?> payload) async =>
      _client.dio.post<void>(
        '/v1/admin/ritual-schedules',
        data: payload,
        options: _idempotent('schedule-create', jsonEncode(payload)),
      );
  @override
  Future<void> patchSchedule(
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => _client.dio.patch<void>(
    '/v1/admin/ritual-schedules/${record.id}',
    data: payload,
    options: _conditional(record),
  );
  @override
  Future<void> withdrawSchedule(AdminRecord record) async =>
      _client.dio.delete<void>(
        '/v1/admin/ritual-schedules/${record.id}',
        data: const {'reason': 'Withdrawn from the staff dashboard.'},
        options: _conditional(record),
      );
  @override
  Future<void> verifyCovenQualification(
    String qualificationId,
    Map<String, Object?> payload,
  ) async => _client.dio.post<void>(
    '/v1/admin/coven-qualifications/$qualificationId/verifications',
    data: payload,
    options: _idempotent('coven-verify', qualificationId),
  );
  @override
  Future<void> createMediaUpload(Map<String, Object?> payload) async =>
      _client.dio.post<void>(
        '/v1/admin/media/upload-requests',
        data: payload,
        options: _idempotent('media-upload', jsonEncode(payload)),
      );
  @override
  Future<void> completeMedia(
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => _client.dio.post<void>(
    '/v1/admin/media/${record.id}/complete',
    data: payload,
    options: _idempotent('media-complete', record.id),
  );
  @override
  Future<void> retireMedia(AdminRecord record) async =>
      _client.dio.delete<void>(
        '/v1/admin/media/${record.id}',
        data: const {'reason': 'Retired from the staff dashboard.'},
        options: _conditional(record),
      );
  @override
  Future<void> openModerationCase(
    AdminRecord report,
    Map<String, Object?> payload,
  ) async => _client.dio.post<void>(
    '/v1/admin/moderation/reports/${report.id}/cases',
    data: payload,
    options: _idempotent('moderation-open', report.id),
  );
  @override
  Future<void> decideModerationCase(
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => _client.dio.patch<void>(
    '/v1/admin/moderation/cases/${record.id}',
    data: payload,
    options: _conditional(record),
  );
  @override
  Future<void> retryPrivacy(AdminRecord record) async => _client.dio.post<void>(
    '/v1/admin/privacy/requests/${record.id}/retry',
    data: const {'reason': 'Reviewed retry from the staff dashboard.'},
    options: _idempotent('privacy-retry', record.id),
  );
  @override
  Future<void> retryJob(AdminRecord record) async => _client.dio.post<void>(
    '/v1/admin/jobs/${record.id}/retry',
    data: const {'reason': 'Reviewed retry from the staff dashboard.'},
    options: _idempotent('job-retry', record.id),
  );

  String _revision(AdminRecord record) =>
      record.revisionId ?? (throw StateError('No revision is available'));
  Options _conditional(AdminRecord record) =>
      Options(headers: {'if-match': record.etag});
  Options _idempotent(String action, String identity) =>
      Options(headers: {'idempotency-key': commandKeys.next(action, identity)});
}

class FixtureAdminGateway implements AdminGateway {
  FixtureAdminGateway({this.records = const []});
  final List<AdminRecord> records;
  final List<String> transitions = [];
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
  Future<void> createDraft(
    AdminDestination destination,
    String slug,
    Map<String, Object?> payload,
  ) async => transitions.add('draft:$slug');
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
  ) async => transitions.add('edit:${record.id}');
  @override
  Future<void> preview(
    AdminDestination destination,
    AdminRecord record,
  ) async => transitions.add('preview:${record.id}');
  @override
  Future<void> requestReview(
    AdminDestination destination,
    AdminRecord record,
  ) async => transitions.add('review:${record.id}:${record.revisionId}');
  @override
  Future<void> decideReview(
    AdminDestination destination,
    AdminRecord record,
    String decision,
  ) async => transitions.add('$decision:${record.id}');
  @override
  Future<void> publish(
    AdminDestination destination,
    AdminRecord record,
  ) async => transitions.add('publish:${record.id}:${record.revisionId}');
  @override
  Future<void> withdraw(
    AdminDestination destination,
    AdminRecord record,
  ) async => transitions.add('withdraw:${record.id}');
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
}
