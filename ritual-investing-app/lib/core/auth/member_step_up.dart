import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import 'member_auth.dart';

enum SensitiveMemberAction { webullDisconnect, argusDelete }

class StepUpUnavailable implements Exception {
  const StepUpUnavailable();
}

class InvalidStepUpReceipt implements Exception {
  const InvalidStepUpReceipt();
}

/// A server-issued authorization capability. The opaque value is intentionally
/// exposed only through [consumeFor], which makes each in-memory instance
/// single use. The API must also atomically consume its hashed receipt record;
/// this client-side guard is not an authorization boundary.
class SensitiveActionAuthorization {
  SensitiveActionAuthorization({
    required String receiptToken,
    required this.action,
    required this.userId,
    required this.sessionId,
    required this.expiresAt,
  }) : _receiptToken = receiptToken {
    if (receiptToken.isEmpty ||
        receiptToken.contains(RegExp(r'[\x00-\x20\x7F]')) ||
        userId.isEmpty ||
        sessionId.isEmpty) {
      throw const InvalidStepUpReceipt();
    }
  }

  final String _receiptToken;
  final SensitiveMemberAction action;
  final String userId;
  final String sessionId;
  final DateTime expiresAt;
  bool _consumed = false;

  String consumeFor({
    required SensitiveMemberAction action,
    required AuthSession session,
    required DateTime now,
  }) {
    if (_consumed ||
        this.action != action ||
        session.userId != userId ||
        session.sessionId != sessionId ||
        !now.toUtc().isBefore(expiresAt.toUtc())) {
      throw const InvalidStepUpReceipt();
    }
    _consumed = true;
    return _receiptToken;
  }
}

abstract interface class StepUpReceiptRepository {
  Future<SensitiveActionAuthorization> issue({
    required SensitiveMemberAction action,
    required AuthSession session,
  });
}

typedef StepUpIssueCall = Future<Object?> Function(
  SensitiveMemberAction action,
);

/// Calls the generated Argus API and validates the opaque server capability
/// before it reaches [AuthController]. No Supabase or Webull credential is
/// accepted as a substitute for this action-bound receipt.
class ApiStepUpReceiptRepository implements StepUpReceiptRepository {
  // ignore: prefer_initializing_formals
  const ApiStepUpReceiptRepository({required StepUpIssueCall issue})
    : _issue = issue;

  factory ApiStepUpReceiptRepository.fromClientProvider(
    RitualInvestingApiClient Function() client,
  ) => ApiStepUpReceiptRepository(
    issue: (action) async {
      final api = client().getMemberSecurityApi();
      final response = await api.issueMemberStepUp(
        issueMemberStepUpRequest: IssueMemberStepUpRequest(
          action: switch (action) {
            SensitiveMemberAction.webullDisconnect =>
              IssueMemberStepUpRequestActionEnum.webullDisconnect,
            SensitiveMemberAction.argusDelete =>
              IssueMemberStepUpRequestActionEnum.argusDelete,
          },
        ),
      );
      return response.data?.data;
    },
  );

  final StepUpIssueCall _issue;

  @override
  Future<SensitiveActionAuthorization> issue({
    required SensitiveMemberAction action,
    required AuthSession session,
  }) async {
    try {
      final raw = await _issue(action);
      if (raw is! Map) throw const InvalidStepUpReceipt();
      final value = Map<String, Object?>.from(raw);
      final expectedAction = switch (action) {
        SensitiveMemberAction.webullDisconnect => 'webull_disconnect',
        SensitiveMemberAction.argusDelete => 'argus_delete',
      };
      final receipt = value['receipt'];
      final responseAction = value['action'];
      final userId = value['user_id'];
      final sessionId = value['session_id'];
      final expiresAtValue = value['expires_at'];
      final expiresAt = expiresAtValue is String
          ? DateTime.tryParse(expiresAtValue)?.toUtc()
          : null;
      if (receipt is! String ||
          responseAction != expectedAction ||
          userId != session.userId ||
          sessionId != session.sessionId ||
          expiresAt == null ||
          !expiresAt.isAfter(DateTime.now().toUtc())) {
        throw const InvalidStepUpReceipt();
      }
      return SensitiveActionAuthorization(
        receiptToken: receipt,
        action: action,
        userId: userId as String,
        sessionId: sessionId as String,
        expiresAt: expiresAt,
      );
    } on InvalidStepUpReceipt {
      rethrow;
    } on Object {
      throw const StepUpUnavailable();
    }
  }
}

/// U5 supplies the generated API implementation. Until then sensitive actions
/// fail closed instead of treating a fresh client token as a step-up receipt.
class UnavailableStepUpReceiptRepository implements StepUpReceiptRepository {
  const UnavailableStepUpReceiptRepository();

  @override
  Future<SensitiveActionAuthorization> issue({
    required SensitiveMemberAction action,
    required AuthSession session,
  }) async => throw const StepUpUnavailable();
}
