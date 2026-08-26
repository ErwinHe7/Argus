// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    as api;

import '../../../core/api/api_failure_mapper.dart';
import '../../../core/api/view_state.dart';
import '../domain/model.dart';
import 'repository.dart';

class GeneratedEntitlementService implements EntitlementService {
  GeneratedEntitlementService(api.RitualInvestingApiClient client)
    : _api = api.DemoEntitlementsApi(client.dio);

  final api.DemoEntitlementsApi _api;

  @override
  Future<List<DemoPlan>> listPlans() async {
    try {
      final values = (await _api.listDemoPlans()).data!.data;
      final plans = values.map(_plan).toList(growable: false);
      if (plans.length != DemoPlanCode.values.length ||
          plans.map((plan) => plan.code).toSet().length != plans.length ||
          !DemoPlanCode.values.every(
            (code) => plans.any((plan) => plan.code == code),
          )) {
        _terminal();
      }
      return plans;
    } on DioException catch (error) {
      _throwReadFailure(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      _terminal();
    }
  }

  @override
  Future<DemoEntitlement> getEntitlement() async {
    try {
      return _entitlement((await _api.getDemoEntitlement()).data!.data);
    } on DioException catch (error) {
      _throwReadFailure(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      _terminal();
    }
  }

  @override
  Future<DemoCheckout> getCheckout(String sessionId) async {
    _requireUuid(sessionId);
    try {
      final result = _checkout(
        (await _api.getDemoCheckout(sessionId: sessionId)).data!.data,
      );
      if (result.id != sessionId) _terminal();
      return result;
    } on DioException catch (error) {
      _throwReadFailure(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      _terminal();
    }
  }

  @override
  Future<DemoCheckout> createCheckout(String planCode, String key) async {
    if (planCode != DemoPlanCode.premiumDemo.wireValue || !_validKey(key)) {
      _terminal();
    }
    try {
      return _checkout(
        (await _api.createDemoCheckout(
          idempotencyKey: key,
          createDemoCheckoutRequest: api.CreateDemoCheckoutRequest(
            planCode: api.CreateDemoCheckoutRequestPlanCodeEnum.premiumDemo,
          ),
        )).data!.data,
      );
    } on DioException catch (error) {
      _throwMutationFailure(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      _terminal();
    }
  }

  @override
  Future<DemoEntitlement> confirmCheckout(
    String sessionId,
    int expectedVersion,
    String key,
  ) async {
    _requireUuid(sessionId);
    if (expectedVersion <= 0 || !_validKey(key)) _terminal();
    try {
      return _entitlement(
        (await _api.confirmDemoCheckout(
          sessionId: sessionId,
          idempotencyKey: key,
          ifMatch: '"v$expectedVersion"',
          body: const <String, Object?>{},
        )).data!.data,
      );
    } on DioException catch (error) {
      _throwMutationFailure(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      _terminal();
    }
  }

  @override
  Future<DemoEntitlement> restore(String key) async {
    if (!_validKey(key)) _terminal();
    try {
      return _entitlement(
        (await _api.restoreDemoEntitlement(
          idempotencyKey: key,
          body: const <String, Object?>{},
        )).data!.data,
      );
    } on DioException catch (error) {
      _throwMutationFailure(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      _terminal();
    }
  }

  @override
  Future<DemoEntitlement> downgrade(int expectedVersion, String key) async {
    if (expectedVersion <= 0 || !_validKey(key)) _terminal();
    try {
      return _entitlement(
        (await _api.downgradeDemoEntitlement(
          idempotencyKey: key,
          ifMatch: '"v$expectedVersion"',
          body: const <String, Object?>{},
        )).data!.data,
      );
    } on DioException catch (error) {
      _throwMutationFailure(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      _terminal();
    }
  }
}

DemoPlan _plan(api.DemoPlan value) {
  final code = switch (value.code) {
    api.DemoPlanCodeEnum.free => DemoPlanCode.free,
    api.DemoPlanCodeEnum.premiumDemo => DemoPlanCode.premiumDemo,
    api.DemoPlanCodeEnum.unknownDefaultOpenApi => _terminal(),
  };
  final capabilities = value.featureCodes.toSet();
  if (value.displayName.trim().isEmpty ||
      value.displayName.length > 120 ||
      value.priceCopy.trim().isEmpty ||
      value.priceCopy.length > 160 ||
      !value.priceCopy.toLowerCase().contains('no charge') ||
      capabilities.length != value.featureCodes.length ||
      !capabilities.every((code) => DemoCapability.fromCode(code) != null)) {
    _terminal();
  }
  return DemoPlan(
    code: code,
    displayName: value.displayName.trim(),
    priceCopy: value.priceCopy.trim(),
    capabilityCodes: Set.unmodifiable(capabilities),
    disclosure: _disclosure(value.demo),
  );
}

DemoEntitlement _entitlement(api.DemoEntitlement value) {
  _requireUuid(value.id);
  final result = DemoEntitlement(
    id: value.id,
    planCode: switch (value.planCode) {
      api.DemoEntitlementPlanCodeEnum.free => DemoPlanCode.free,
      api.DemoEntitlementPlanCodeEnum.premiumDemo => DemoPlanCode.premiumDemo,
      api.DemoEntitlementPlanCodeEnum.unknownDefaultOpenApi => _terminal(),
    },
    status: switch (value.status) {
      api.DemoEntitlementStatusEnum.active => DemoEntitlementStatus.active,
      api.DemoEntitlementStatusEnum.expired => DemoEntitlementStatus.expired,
      api.DemoEntitlementStatusEnum.revoked => DemoEntitlementStatus.revoked,
      api.DemoEntitlementStatusEnum.unknownDefaultOpenApi => _terminal(),
    },
    startsAt: value.startsAt.toUtc(),
    endsAt: value.endsAt?.toUtc(),
    version: value.version,
    disclosure: _disclosure(value.demo),
  );
  if (value.source_ != api.DemoEntitlementSource_Enum.demo ||
      result.version <= 0 ||
      (result.endsAt != null && result.endsAt!.isBefore(result.startsAt)) ||
      (result.status == DemoEntitlementStatus.active &&
          result.endsAt != null)) {
    _terminal();
  }
  return result;
}

DemoCheckout _checkout(api.DemoCheckoutSession value) {
  _requireUuid(value.id);
  final result = DemoCheckout(
    id: value.id,
    planCode: switch (value.planCode) {
      api.DemoCheckoutSessionPlanCodeEnum.premiumDemo =>
        DemoPlanCode.premiumDemo,
      api.DemoCheckoutSessionPlanCodeEnum.unknownDefaultOpenApi => _terminal(),
    },
    status: switch (value.status) {
      api.DemoCheckoutSessionStatusEnum.open => DemoCheckoutStatus.open,
      api.DemoCheckoutSessionStatusEnum.completed =>
        DemoCheckoutStatus.completed,
      api.DemoCheckoutSessionStatusEnum.expired => DemoCheckoutStatus.expired,
      api.DemoCheckoutSessionStatusEnum.cancelled =>
        DemoCheckoutStatus.cancelled,
      api.DemoCheckoutSessionStatusEnum.unknownDefaultOpenApi => _terminal(),
    },
    expiresAt: value.expiresAt.toUtc(),
    version: value.version,
    disclosure: _disclosure(value.demo),
  );
  if (result.version <= 0) _terminal();
  return result;
}

DemoDisclosure _disclosure(api.SimulationDemoDisclosure value) {
  final source = value.sourceLabel.trim();
  final limitations = value.limitations
      .map((item) => item.trim())
      .toList(growable: false);
  if (!value.isDemo ||
      source.isEmpty ||
      source.length > 120 ||
      limitations.isEmpty ||
      limitations.length > 8 ||
      limitations.any((item) => item.isEmpty || item.length > 240) ||
      !limitations.any(
        (item) =>
            item.toLowerCase().contains('no money') ||
            item.toLowerCase().contains('no real') ||
            item.toLowerCase().contains('no charge'),
      )) {
    _terminal();
  }
  return DemoDisclosure(
    isDemo: true,
    observedAt: value.observedAt.toUtc(),
    sourceLabel: source,
    limitations: List.unmodifiable(limitations),
  );
}

bool _validKey(String value) =>
    value.length >= 16 &&
    value.length <= 64 &&
    value.codeUnits.every((unit) => unit >= 0x21 && unit <= 0x7e);

void _requireUuid(String value) {
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value)) {
    _terminal();
  }
}

Never _terminal() => throw const LoadFailure(LoadPhase.terminalFailure);

Never _throwReadFailure(DioException error) {
  if (_ambiguous(error)) throw const OfflineException();
  throw ApiFailureMapper.map(error);
}

Never _throwMutationFailure(DioException error) {
  if (_ambiguous(error)) throw const AmbiguousEntitlementMutation();
  throw ApiFailureMapper.map(error);
}

bool _ambiguous(DioException error) =>
    error.type == DioExceptionType.connectionError ||
    error.type == DioExceptionType.connectionTimeout ||
    error.type == DioExceptionType.receiveTimeout ||
    error.type == DioExceptionType.sendTimeout;
