import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

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
    final response = await switch (destination.apiPath) {
      '/v1/admin/ritual-scenarios' =>
        _client.getAdminRitualScenarioApi().listAdminRitualScenario(limit: 20),
      '/v1/admin/asset-codex' =>
        _client.getAdminAssetCodexApi().listAdminAssetCodex(limit: 20),
      '/v1/admin/coven-entries' =>
        _client.getAdminCovenEntryApi().listAdminCovenEntry(limit: 20),
      '/v1/admin/grimoires' => _client.getAdminGrimoireApi().listAdminGrimoire(
        limit: 20,
      ),
      '/v1/admin/circle-templates' =>
        _client.getAdminCircleTemplateApi().listAdminCircleTemplate(limit: 20),
      '/v1/admin/rowan-scripts' =>
        _client.getAdminRowanScriptApi().listAdminRowanScript(limit: 20),
      '/v1/admin/briefing-templates' =>
        _client.getAdminBriefingTemplateApi().listAdminBriefingTemplate(
          limit: 20,
        ),
      '/v1/admin/assets' => _client.getAdminAssetsApi().listAdminAssets(
        limit: 20,
      ),
      '/v1/admin/evidence-sources' =>
        _client.getAdminEvidenceApi().listAdminEvidenceSources(limit: 20),
      '/v1/admin/evidence-claims' =>
        _client.getAdminEvidenceApi().listAdminEvidenceClaims(limit: 20),
      '/v1/admin/ritual-schedules' =>
        _client.getAdminSchedulingApi().listAdminRitualSchedules(
          from: DateTime.utc(now.year, 1, 1),
          to: DateTime.utc(now.year + 1, 1, 1),
          limit: 20,
        ),
      '/v1/admin/seeded-creators' =>
        _client.getAdminSeededCommunityApi().listAdminSeededCreators(limit: 20),
      '/v1/admin/moderation/reports' =>
        _client.getAdminModerationApi().listAdminModerationReports(limit: 20),
      '/v1/admin/media' => _client.getAdminMediaApi().listAdminMedia(limit: 20),
      '/v1/admin/privacy/requests' =>
        _client.getAdminPrivacyApi().listAdminPrivacyRequests(limit: 20),
      '/v1/admin/jobs' => _client.getAdminOperationsApi().listAdminJobs(
        limit: 20,
      ),
      '/v1/admin/audit-events' =>
        _client.getAdminAuditApi().listAdminAuditEvents(limit: 20),
      _ => throw StateError(
        'No generated collection method for ${destination.apiPath}',
      ),
    };
    final values = _dtoJson(response.data)['data'];
    if (values is! List) {
      throw const FormatException('Invalid admin collection envelope');
    }
    return values.map(_decodeRecord).toList(growable: false);
  }

  Map<String, Object?> _dtoJson(Object? value) {
    if (value == null) throw const FormatException('Missing API response');
    final json = (value as dynamic).toJson();
    if (json is! Map) throw const FormatException('Invalid API response');
    return Map<String, Object?>.from(json);
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
  ) async {
    final key = _commandKey('draft', slug);
    final body = <String, dynamic>{'slug': slug, ...payload};
    await switch (destination.apiPath) {
      '/v1/admin/ritual-scenarios' =>
        _client.getAdminRitualScenarioApi().createAdminRitualScenario(
          idempotencyKey: key,
          createRitualScenarioRequest: CreateRitualScenarioRequest.fromJson(
            body,
          ),
        ),
      '/v1/admin/asset-codex' =>
        _client.getAdminAssetCodexApi().createAdminAssetCodex(
          idempotencyKey: key,
          createAssetCodexRequest: CreateAssetCodexRequest.fromJson(body),
        ),
      '/v1/admin/coven-entries' =>
        _client.getAdminCovenEntryApi().createAdminCovenEntry(
          idempotencyKey: key,
          createCovenEntryRequest: CreateCovenEntryRequest.fromJson(body),
        ),
      '/v1/admin/grimoires' =>
        _client.getAdminGrimoireApi().createAdminGrimoire(
          idempotencyKey: key,
          createGrimoireRequest: CreateGrimoireRequest.fromJson(body),
        ),
      '/v1/admin/circle-templates' =>
        _client.getAdminCircleTemplateApi().createAdminCircleTemplate(
          idempotencyKey: key,
          createCircleTemplateRequest: CreateCircleTemplateRequest.fromJson(
            body,
          ),
        ),
      '/v1/admin/rowan-scripts' =>
        _client.getAdminRowanScriptApi().createAdminRowanScript(
          idempotencyKey: key,
          createRowanScriptRequest: CreateRowanScriptRequest.fromJson(body),
        ),
      '/v1/admin/briefing-templates' =>
        _client.getAdminBriefingTemplateApi().createAdminBriefingTemplate(
          idempotencyKey: key,
          createBriefingTemplateRequest: CreateBriefingTemplateRequest.fromJson(
            body,
          ),
        ),
      _ => throw StateError(
        'No generated editorial method for ${destination.apiPath}',
      ),
    };
  }

  @override
  Future<void> createRevision(
    AdminDestination destination,
    AdminRecord record,
    Map<String, Object?> payload,
  ) async {
    final revision = _revision(record);
    final key = _commandKey('revision', record.id);
    final body = <String, dynamic>{
      'source_revision_id': revision,
      'payload': payload,
    };
    await switch (destination.apiPath) {
      '/v1/admin/ritual-scenarios' =>
        _client.getAdminRitualScenarioApi().createAdminRitualScenarioRevision(
          itemId: record.id,
          idempotencyKey: key,
          createRitualScenarioRevisionRequest:
              CreateRitualScenarioRevisionRequest.fromJson(body),
        ),
      '/v1/admin/asset-codex' =>
        _client.getAdminAssetCodexApi().createAdminAssetCodexRevision(
          itemId: record.id,
          idempotencyKey: key,
          createAssetCodexRevisionRequest:
              CreateAssetCodexRevisionRequest.fromJson(body),
        ),
      '/v1/admin/coven-entries' =>
        _client.getAdminCovenEntryApi().createAdminCovenEntryRevision(
          itemId: record.id,
          idempotencyKey: key,
          createCovenEntryRevisionRequest:
              CreateCovenEntryRevisionRequest.fromJson(body),
        ),
      '/v1/admin/grimoires' =>
        _client.getAdminGrimoireApi().createAdminGrimoireRevision(
          itemId: record.id,
          idempotencyKey: key,
          createGrimoireRevisionRequest: CreateGrimoireRevisionRequest.fromJson(
            body,
          ),
        ),
      '/v1/admin/circle-templates' =>
        _client.getAdminCircleTemplateApi().createAdminCircleTemplateRevision(
          itemId: record.id,
          idempotencyKey: key,
          createCircleTemplateRevisionRequest:
              CreateCircleTemplateRevisionRequest.fromJson(body),
        ),
      '/v1/admin/rowan-scripts' =>
        _client.getAdminRowanScriptApi().createAdminRowanScriptRevision(
          itemId: record.id,
          idempotencyKey: key,
          createRowanScriptRevisionRequest:
              CreateRowanScriptRevisionRequest.fromJson(body),
        ),
      '/v1/admin/briefing-templates' =>
        _client
            .getAdminBriefingTemplateApi()
            .createAdminBriefingTemplateRevision(
              itemId: record.id,
              idempotencyKey: key,
              createBriefingTemplateRevisionRequest:
                  CreateBriefingTemplateRevisionRequest.fromJson(body),
            ),
      _ => throw StateError(
        'No generated editorial method for ${destination.apiPath}',
      ),
    };
  }

  @override
  Future<void> patchRevision(
    AdminDestination destination,
    AdminRecord record,
    Map<String, Object?> payload,
  ) async {
    final revision = _revision(record);
    final body = <String, dynamic>{'payload': payload};
    await switch (destination.apiPath) {
      '/v1/admin/ritual-scenarios' =>
        _client.getAdminRitualScenarioApi().patchAdminRitualScenarioRevision(
          itemId: record.id,
          revisionId: revision,
          ifMatch: record.etag,
          patchRitualScenarioRevisionRequest:
              PatchRitualScenarioRevisionRequest.fromJson(body),
        ),
      '/v1/admin/asset-codex' =>
        _client.getAdminAssetCodexApi().patchAdminAssetCodexRevision(
          itemId: record.id,
          revisionId: revision,
          ifMatch: record.etag,
          patchAssetCodexRevisionRequest:
              PatchAssetCodexRevisionRequest.fromJson(body),
        ),
      '/v1/admin/coven-entries' =>
        _client.getAdminCovenEntryApi().patchAdminCovenEntryRevision(
          itemId: record.id,
          revisionId: revision,
          ifMatch: record.etag,
          patchCovenEntryRevisionRequest:
              PatchCovenEntryRevisionRequest.fromJson(body),
        ),
      '/v1/admin/grimoires' =>
        _client.getAdminGrimoireApi().patchAdminGrimoireRevision(
          itemId: record.id,
          revisionId: revision,
          ifMatch: record.etag,
          patchGrimoireRevisionRequest: PatchGrimoireRevisionRequest.fromJson(
            body,
          ),
        ),
      '/v1/admin/circle-templates' =>
        _client.getAdminCircleTemplateApi().patchAdminCircleTemplateRevision(
          itemId: record.id,
          revisionId: revision,
          ifMatch: record.etag,
          patchCircleTemplateRevisionRequest:
              PatchCircleTemplateRevisionRequest.fromJson(body),
        ),
      '/v1/admin/rowan-scripts' =>
        _client.getAdminRowanScriptApi().patchAdminRowanScriptRevision(
          itemId: record.id,
          revisionId: revision,
          ifMatch: record.etag,
          patchRowanScriptRevisionRequest:
              PatchRowanScriptRevisionRequest.fromJson(body),
        ),
      '/v1/admin/briefing-templates' =>
        _client
            .getAdminBriefingTemplateApi()
            .patchAdminBriefingTemplateRevision(
              itemId: record.id,
              revisionId: revision,
              ifMatch: record.etag,
              patchBriefingTemplateRevisionRequest:
                  PatchBriefingTemplateRevisionRequest.fromJson(body),
            ),
      _ => throw StateError(
        'No generated editorial method for ${destination.apiPath}',
      ),
    };
  }

  @override
  Future<void> preview(AdminDestination destination, AdminRecord record) async {
    final revision = _revision(record);
    await switch (destination.apiPath) {
      '/v1/admin/ritual-scenarios' =>
        _client.getAdminRitualScenarioApi().previewAdminRitualScenarioRevision(
          itemId: record.id,
          revisionId: revision,
        ),
      '/v1/admin/asset-codex' =>
        _client.getAdminAssetCodexApi().previewAdminAssetCodexRevision(
          itemId: record.id,
          revisionId: revision,
        ),
      '/v1/admin/coven-entries' =>
        _client.getAdminCovenEntryApi().previewAdminCovenEntryRevision(
          itemId: record.id,
          revisionId: revision,
        ),
      '/v1/admin/grimoires' =>
        _client.getAdminGrimoireApi().previewAdminGrimoireRevision(
          itemId: record.id,
          revisionId: revision,
        ),
      '/v1/admin/circle-templates' =>
        _client.getAdminCircleTemplateApi().previewAdminCircleTemplateRevision(
          itemId: record.id,
          revisionId: revision,
        ),
      '/v1/admin/rowan-scripts' =>
        _client.getAdminRowanScriptApi().previewAdminRowanScriptRevision(
          itemId: record.id,
          revisionId: revision,
        ),
      '/v1/admin/briefing-templates' =>
        _client
            .getAdminBriefingTemplateApi()
            .previewAdminBriefingTemplateRevision(
              itemId: record.id,
              revisionId: revision,
            ),
      _ => throw StateError(
        'No generated editorial method for ${destination.apiPath}',
      ),
    };
  }

  @override
  Future<void> requestReview(
    AdminDestination destination,
    AdminRecord record,
  ) async {
    final revision = _revision(record);
    final key = _commandKey('review', revision);
    final request = RequestAdminAssetCodexReviewRequest.fromJson(const {
      'note': 'Submitted from the reviewed staff dashboard.',
    });
    await switch (destination.apiPath) {
      '/v1/admin/ritual-scenarios' =>
        _client.getAdminRitualScenarioApi().requestAdminRitualScenarioReview(
          itemId: record.id,
          revisionId: revision,
          idempotencyKey: key,
          requestAdminAssetCodexReviewRequest: request,
        ),
      '/v1/admin/asset-codex' =>
        _client.getAdminAssetCodexApi().requestAdminAssetCodexReview(
          itemId: record.id,
          revisionId: revision,
          idempotencyKey: key,
          requestAdminAssetCodexReviewRequest: request,
        ),
      '/v1/admin/coven-entries' =>
        _client.getAdminCovenEntryApi().requestAdminCovenEntryReview(
          itemId: record.id,
          revisionId: revision,
          idempotencyKey: key,
          requestAdminAssetCodexReviewRequest: request,
        ),
      '/v1/admin/grimoires' =>
        _client.getAdminGrimoireApi().requestAdminGrimoireReview(
          itemId: record.id,
          revisionId: revision,
          idempotencyKey: key,
          requestAdminAssetCodexReviewRequest: request,
        ),
      '/v1/admin/circle-templates' =>
        _client.getAdminCircleTemplateApi().requestAdminCircleTemplateReview(
          itemId: record.id,
          revisionId: revision,
          idempotencyKey: key,
          requestAdminAssetCodexReviewRequest: request,
        ),
      '/v1/admin/rowan-scripts' =>
        _client.getAdminRowanScriptApi().requestAdminRowanScriptReview(
          itemId: record.id,
          revisionId: revision,
          idempotencyKey: key,
          requestAdminAssetCodexReviewRequest: request,
        ),
      '/v1/admin/briefing-templates' =>
        _client
            .getAdminBriefingTemplateApi()
            .requestAdminBriefingTemplateReview(
              itemId: record.id,
              revisionId: revision,
              idempotencyKey: key,
              requestAdminAssetCodexReviewRequest: request,
            ),
      _ => throw StateError(
        'No generated editorial method for ${destination.apiPath}',
      ),
    };
  }

  @override
  Future<void> decideReview(
    AdminDestination destination,
    AdminRecord record,
    AdminReviewDecision decision,
  ) async {
    final revision = _revision(record);
    final key = _commandKey('decision-${decision.wireValue}', revision);
    final request = DecideAdminAssetCodexReviewRequest(
      decision: switch (decision) {
        AdminReviewDecision.approved =>
          DecideAdminAssetCodexReviewRequestDecisionEnum.approved,
        AdminReviewDecision.changesRequested =>
          DecideAdminAssetCodexReviewRequestDecisionEnum.changesRequested,
      },
      reason: 'Recorded from the reviewed staff dashboard.',
    );
    await switch (destination.apiPath) {
      '/v1/admin/ritual-scenarios' =>
        _client.getAdminRitualScenarioApi().decideAdminRitualScenarioReview(
          itemId: record.id,
          revisionId: revision,
          idempotencyKey: key,
          decideAdminAssetCodexReviewRequest: request,
        ),
      '/v1/admin/asset-codex' =>
        _client.getAdminAssetCodexApi().decideAdminAssetCodexReview(
          itemId: record.id,
          revisionId: revision,
          idempotencyKey: key,
          decideAdminAssetCodexReviewRequest: request,
        ),
      '/v1/admin/coven-entries' =>
        _client.getAdminCovenEntryApi().decideAdminCovenEntryReview(
          itemId: record.id,
          revisionId: revision,
          idempotencyKey: key,
          decideAdminAssetCodexReviewRequest: request,
        ),
      '/v1/admin/grimoires' =>
        _client.getAdminGrimoireApi().decideAdminGrimoireReview(
          itemId: record.id,
          revisionId: revision,
          idempotencyKey: key,
          decideAdminAssetCodexReviewRequest: request,
        ),
      '/v1/admin/circle-templates' =>
        _client.getAdminCircleTemplateApi().decideAdminCircleTemplateReview(
          itemId: record.id,
          revisionId: revision,
          idempotencyKey: key,
          decideAdminAssetCodexReviewRequest: request,
        ),
      '/v1/admin/rowan-scripts' =>
        _client.getAdminRowanScriptApi().decideAdminRowanScriptReview(
          itemId: record.id,
          revisionId: revision,
          idempotencyKey: key,
          decideAdminAssetCodexReviewRequest: request,
        ),
      '/v1/admin/briefing-templates' =>
        _client.getAdminBriefingTemplateApi().decideAdminBriefingTemplateReview(
          itemId: record.id,
          revisionId: revision,
          idempotencyKey: key,
          decideAdminAssetCodexReviewRequest: request,
        ),
      _ => throw StateError(
        'No generated editorial method for ${destination.apiPath}',
      ),
    };
  }

  @override
  Future<void> publish(AdminDestination destination, AdminRecord record) async {
    final revision = _revision(record);
    final key = _commandKey('publish', revision);
    final request = PublishAdminAssetCodexRevisionRequest.fromJson({
      'effective_at': DateTime.now().toUtc().toIso8601String(),
      'reason': 'Published from the reviewed staff dashboard.',
    });
    await switch (destination.apiPath) {
      '/v1/admin/ritual-scenarios' =>
        _client.getAdminRitualScenarioApi().publishAdminRitualScenarioRevision(
          itemId: record.id,
          revisionId: revision,
          idempotencyKey: key,
          publishAdminAssetCodexRevisionRequest: request,
        ),
      '/v1/admin/asset-codex' =>
        _client.getAdminAssetCodexApi().publishAdminAssetCodexRevision(
          itemId: record.id,
          revisionId: revision,
          idempotencyKey: key,
          publishAdminAssetCodexRevisionRequest: request,
        ),
      '/v1/admin/coven-entries' =>
        _client.getAdminCovenEntryApi().publishAdminCovenEntryRevision(
          itemId: record.id,
          revisionId: revision,
          idempotencyKey: key,
          publishAdminAssetCodexRevisionRequest: request,
        ),
      '/v1/admin/grimoires' =>
        _client.getAdminGrimoireApi().publishAdminGrimoireRevision(
          itemId: record.id,
          revisionId: revision,
          idempotencyKey: key,
          publishAdminAssetCodexRevisionRequest: request,
        ),
      '/v1/admin/circle-templates' =>
        _client.getAdminCircleTemplateApi().publishAdminCircleTemplateRevision(
          itemId: record.id,
          revisionId: revision,
          idempotencyKey: key,
          publishAdminAssetCodexRevisionRequest: request,
        ),
      '/v1/admin/rowan-scripts' =>
        _client.getAdminRowanScriptApi().publishAdminRowanScriptRevision(
          itemId: record.id,
          revisionId: revision,
          idempotencyKey: key,
          publishAdminAssetCodexRevisionRequest: request,
        ),
      '/v1/admin/briefing-templates' =>
        _client
            .getAdminBriefingTemplateApi()
            .publishAdminBriefingTemplateRevision(
              itemId: record.id,
              revisionId: revision,
              idempotencyKey: key,
              publishAdminAssetCodexRevisionRequest: request,
            ),
      _ => throw StateError(
        'No generated editorial method for ${destination.apiPath}',
      ),
    };
  }

  @override
  Future<void> withdraw(
    AdminDestination destination,
    AdminRecord record,
  ) async {
    final key = _commandKey('withdraw', record.id);
    final request = WithdrawAdminAssetCodexRequest.fromJson(const {
      'reason': 'Withdrawn from the reviewed staff dashboard.',
    });
    await switch (destination.apiPath) {
      '/v1/admin/ritual-scenarios' =>
        _client.getAdminRitualScenarioApi().withdrawAdminRitualScenario(
          itemId: record.id,
          idempotencyKey: key,
          withdrawAdminAssetCodexRequest: request,
        ),
      '/v1/admin/asset-codex' =>
        _client.getAdminAssetCodexApi().withdrawAdminAssetCodex(
          itemId: record.id,
          idempotencyKey: key,
          withdrawAdminAssetCodexRequest: request,
        ),
      '/v1/admin/coven-entries' =>
        _client.getAdminCovenEntryApi().withdrawAdminCovenEntry(
          itemId: record.id,
          idempotencyKey: key,
          withdrawAdminAssetCodexRequest: request,
        ),
      '/v1/admin/grimoires' =>
        _client.getAdminGrimoireApi().withdrawAdminGrimoire(
          itemId: record.id,
          idempotencyKey: key,
          withdrawAdminAssetCodexRequest: request,
        ),
      '/v1/admin/circle-templates' =>
        _client.getAdminCircleTemplateApi().withdrawAdminCircleTemplate(
          itemId: record.id,
          idempotencyKey: key,
          withdrawAdminAssetCodexRequest: request,
        ),
      '/v1/admin/rowan-scripts' =>
        _client.getAdminRowanScriptApi().withdrawAdminRowanScript(
          itemId: record.id,
          idempotencyKey: key,
          withdrawAdminAssetCodexRequest: request,
        ),
      '/v1/admin/briefing-templates' =>
        _client.getAdminBriefingTemplateApi().withdrawAdminBriefingTemplate(
          itemId: record.id,
          idempotencyKey: key,
          withdrawAdminAssetCodexRequest: request,
        ),
      _ => throw StateError(
        'No generated editorial method for ${destination.apiPath}',
      ),
    };
  }

  @override
  Future<void> createCatalog(
    AdminDestination destination,
    Map<String, Object?> payload,
  ) async {
    final key = _commandKey('catalog-create', destination.apiPath);
    final body = Map<String, dynamic>.from(payload);
    await switch (destination.apiPath) {
      '/v1/admin/assets' => _client.getAdminAssetsApi().createAdminAsset(
        idempotencyKey: key,
        createAdminAssetRequest: CreateAdminAssetRequest.fromJson(body),
      ),
      '/v1/admin/evidence-sources' =>
        _client.getAdminEvidenceApi().createAdminEvidenceSource(
          idempotencyKey: key,
          createAdminEvidenceSourceRequest:
              CreateAdminEvidenceSourceRequest.fromJson(body),
        ),
      '/v1/admin/evidence-claims' =>
        _client.getAdminEvidenceApi().createAdminEvidenceClaim(
          idempotencyKey: key,
          createAdminEvidenceClaimRequest:
              CreateAdminEvidenceClaimRequest.fromJson(body),
        ),
      '/v1/admin/seeded-creators' =>
        _client.getAdminSeededCommunityApi().createAdminSeededCreator(
          idempotencyKey: key,
          createAdminSeededCreatorRequest:
              CreateAdminSeededCreatorRequest.fromJson(body),
        ),
      _ => throw StateError(
        'No generated catalog create method for ${destination.apiPath}',
      ),
    };
  }

  @override
  Future<void> patchCatalog(
    AdminDestination destination,
    AdminRecord record,
    Map<String, Object?> payload,
  ) async {
    final body = Map<String, dynamic>.from(payload);
    await switch (destination.apiPath) {
      '/v1/admin/assets' => _client.getAdminAssetsApi().patchAdminAsset(
        assetId: record.id,
        ifMatch: record.etag,
        patchAdminAssetRequest: PatchAdminAssetRequest.fromJson(body),
      ),
      '/v1/admin/evidence-sources' =>
        _client.getAdminEvidenceApi().patchAdminEvidenceSource(
          sourceId: record.id,
          ifMatch: record.etag,
          patchAdminEvidenceSourceRequest:
              PatchAdminEvidenceSourceRequest.fromJson(body),
        ),
      '/v1/admin/seeded-creators' =>
        _client.getAdminSeededCommunityApi().patchAdminSeededCreator(
          creatorId: record.id,
          ifMatch: record.etag,
          patchAdminSeededCreatorRequest:
              PatchAdminSeededCreatorRequest.fromJson(body),
        ),
      _ => throw StateError(
        'No generated catalog patch method for ${destination.apiPath}',
      ),
    };
  }

  @override
  Future<void> appendAssetMetric(
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => _client.getAdminCatalogApi().createAdminAssetMetricSnapshot(
    assetId: record.id,
    idempotencyKey: _commandKey('asset-metric', record.id),
    createAdminAssetMetricSnapshotRequest:
        CreateAdminAssetMetricSnapshotRequest.fromJson(
          Map<String, dynamic>.from(payload),
        ),
  );
  @override
  Future<void> createSchedule(Map<String, Object?> payload) async =>
      _client.getAdminSchedulingApi().createAdminRitualSchedule(
        idempotencyKey: _commandKey('schedule-create', jsonEncode(payload)),
        createAdminRitualScheduleRequest:
            CreateAdminRitualScheduleRequest.fromJson(
              Map<String, dynamic>.from(payload),
            ),
      );
  @override
  Future<void> patchSchedule(
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => _client.getAdminSchedulingApi().patchAdminRitualSchedule(
    scheduleId: record.id,
    ifMatch: record.etag,
    patchAdminRitualScheduleRequest: PatchAdminRitualScheduleRequest.fromJson(
      Map<String, dynamic>.from(payload),
    ),
  );
  @override
  Future<void> withdrawSchedule(AdminRecord record) async =>
      _client.getAdminSchedulingApi().withdrawAdminRitualSchedule(
        scheduleId: record.id,
        ifMatch: record.etag,
        withdrawAdminAssetCodexRequest: WithdrawAdminAssetCodexRequest.fromJson(
          const {'reason': 'Withdrawn from the staff dashboard.'},
        ),
      );
  @override
  Future<void> verifyCovenQualification(
    String qualificationId,
    Map<String, Object?> payload,
  ) async => _client.getAdminCatalogApi().verifyAdminCovenQualification(
    qualificationId: qualificationId,
    idempotencyKey: _commandKey('coven-verify', qualificationId),
    verifyAdminCovenQualificationRequest:
        VerifyAdminCovenQualificationRequest.fromJson(
          Map<String, dynamic>.from(payload),
        ),
  );
  @override
  Future<void> createMediaUpload(Map<String, Object?> payload) async =>
      _client.getAdminMediaApi().requestMediaUpload(
        idempotencyKey: _commandKey('media-upload', jsonEncode(payload)),
        requestMediaUploadRequest: RequestMediaUploadRequest.fromJson(
          Map<String, dynamic>.from(payload),
        ),
      );
  @override
  Future<void> completeMedia(
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => _client.getAdminMediaApi().completeMediaUpload(
    mediaId: record.id,
    idempotencyKey: _commandKey('media-complete', record.id),
    completeMediaUploadRequest: CompleteMediaUploadRequest.fromJson(
      Map<String, dynamic>.from(payload),
    ),
  );
  @override
  Future<void> retireMedia(AdminRecord record) async =>
      _client.getAdminMediaApi().deleteAdminMedia(
        mediaId: record.id,
        ifMatch: record.etag,
        retryAdminJobRequest: RetryAdminJobRequest.fromJson(const {
          'reason': 'Retired from the staff dashboard.',
        }),
      );
  @override
  Future<void> openModerationCase(
    AdminRecord report,
    Map<String, Object?> payload,
  ) async => _client.getAdminModerationApi().createAdminModerationCase(
    reportId: report.id,
    idempotencyKey: _commandKey('moderation-open', report.id),
    createAdminModerationCaseRequest: CreateAdminModerationCaseRequest.fromJson(
      Map<String, dynamic>.from(payload),
    ),
  );
  @override
  Future<void> decideModerationCase(
    AdminRecord record,
    Map<String, Object?> payload,
  ) async => _client.getAdminModerationApi().patchAdminModerationCase(
    caseId: record.id,
    ifMatch: record.etag,
    patchAdminModerationCaseRequest: PatchAdminModerationCaseRequest.fromJson(
      Map<String, dynamic>.from(payload),
    ),
  );
  @override
  Future<void> retryPrivacy(AdminRecord record) async =>
      _client.getAdminPrivacyApi().retryAdminPrivacyRequest(
        requestId: record.id,
        idempotencyKey: _commandKey('privacy-retry', record.id),
        retryAdminJobRequest: RetryAdminJobRequest.fromJson(const {
          'reason': 'Reviewed retry from the staff dashboard.',
        }),
      );
  @override
  Future<void> retryJob(AdminRecord record) async =>
      _client.getAdminOperationsApi().retryAdminJob(
        jobId: record.id,
        idempotencyKey: _commandKey('job-retry', record.id),
        retryAdminJobRequest: RetryAdminJobRequest.fromJson(const {
          'reason': 'Reviewed retry from the staff dashboard.',
        }),
      );

  String _revision(AdminRecord record) =>
      record.revisionId ?? (throw StateError('No revision is available'));
  String _commandKey(String action, String identity) =>
      commandKeys.next(action, identity);
}

class FixtureAdminGateway implements AdminGateway {
  FixtureAdminGateway({List<AdminRecord> records = const []})
    : records = List.of(records);
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
    );
  }
}
