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
