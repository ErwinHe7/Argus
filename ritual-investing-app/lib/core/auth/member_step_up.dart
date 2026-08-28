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

typedef StepUpIssueCall = Future<MemberStepUpReceipt?> Function(
  SensitiveMemberAction action,
);

/// Calls the generated Argus API and validates the opaque server capability
/// before it reaches [AuthController]. No Supabase or Webull credential is
/// accepted as a substitute for this action-bound receipt.
class ApiStepUpReceiptRepository implements StepUpReceiptRepository {
  const ApiStepUpReceiptRepository({required this.issueCall});

  factory ApiStepUpReceiptRepository.fromClientProvider(
    RitualInvestingApiClient Function() client,
  ) => ApiStepUpReceiptRepository(
    issueCall: (action) async {
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

  final StepUpIssueCall issueCall;

  @override
  Future<SensitiveActionAuthorization> issue({
    required SensitiveMemberAction action,
    required AuthSession session,
  }) async {
    try {
      final value = await issueCall(action);
      if (value == null) throw const InvalidStepUpReceipt();
      final expectedAction = switch (action) {
        SensitiveMemberAction.webullDisconnect =>
          MemberStepUpReceiptActionEnum.webullDisconnect,
        SensitiveMemberAction.argusDelete =>
          MemberStepUpReceiptActionEnum.argusDelete,
      };
      final expiresAt = value.expiresAt.toUtc();
      if (value.receipt.isEmpty ||
          value.action != expectedAction ||
          value.userId != session.userId ||
          value.sessionId != session.sessionId ||
          !expiresAt.isAfter(DateTime.now().toUtc())) {
        throw const InvalidStepUpReceipt();
      }
      return SensitiveActionAuthorization(
        receiptToken: value.receipt,
        action: action,
        userId: value.userId,
        sessionId: value.sessionId,
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
