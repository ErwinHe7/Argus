// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

enum MemberLogoutScope { local, global }

enum MemberSessionEvent {
  initialSession,
  signedIn,
  signedOut,
  passwordRecovery,
  tokenRefreshed,
  userUpdated,
  userDeleted,
  mfaChallengeVerified,
}

enum MemberNativeLinkKind { argusAuth, webullCompletion }

/// Exact native-link routing policy shared by SDK callback detection and the
/// future Webull completion handler. It intentionally accepts no wildcards.
@immutable
class MemberNativeLinkPolicy {
  MemberNativeLinkPolicy({
    required Iterable<Uri> argusAuthTargets,
    required Iterable<Uri> webullCompletionTargets,
  }) : argusAuthTargets = List.unmodifiable(argusAuthTargets),
       webullCompletionTargets = List.unmodifiable(webullCompletionTargets) {
    _validateTargets(
      this.argusAuthTargets,
      'Argus Auth',
      customScheme: 'com.ritualinvesting.ritual-investing-app.auth',
    );
    _validateTargets(
      this.webullCompletionTargets,
      'Webull completion',
      customScheme: 'com.ritualinvesting.ritual-investing-app.webull',
    );
    final all = <String>{};
    for (final target in [
      ...this.argusAuthTargets,
      ...this.webullCompletionTargets,
    ]) {
      if (!all.add(_targetKey(target))) {
        throw const FormatException(
          'Argus Auth and Webull completion targets must be distinct.',
        );
      }
    }
    if (this.argusAuthTargets.first.scheme != 'https') {
      throw const FormatException(
        'The preferred Argus Auth redirect must be claimed HTTPS.',
      );
    }
  }

  factory MemberNativeLinkPolicy.parse({
    required String argusAuthAllowlist,
    required String webullCompletionAllowlist,
  }) => MemberNativeLinkPolicy(
    argusAuthTargets: _parseTargets(argusAuthAllowlist),
    webullCompletionTargets: _parseTargets(webullCompletionAllowlist),
  );

  final List<Uri> argusAuthTargets;
  final List<Uri> webullCompletionTargets;

  Uri get preferredArgusAuthRedirect => argusAuthTargets.first;

  bool acceptsArgusAuthCallback(Uri uri) {
    if (!_matchesAnyTarget(uri, argusAuthTargets) || uri.hasFragment) {
      return false;
    }
    final parameters = _strictQuery(uri);
    if (parameters == null || parameters.isEmpty) return false;
    final code = parameters['code'];
    if (parameters.keys.length == 1 && code != null) {
      return _safeOpaqueValue(code, minimumLength: 8);
    }
    final tokenHash = parameters['token_hash'];
    if (parameters.keys.length == 2 &&
        parameters['type'] == 'recovery' &&
        tokenHash != null) {
      return _safeOpaqueValue(tokenHash, minimumLength: 16);
    }
    const errorKeys = {'error', 'error_code', 'error_description'};
    if (!parameters.keys.every(errorKeys.contains) ||
        !parameters.containsKey('error')) {
      return false;
    }
    return parameters.values.every(
      (value) => _safeOpaqueValue(value, minimumLength: 1),
    );
  }

  String? recoveryTokenHash(Uri uri) {
    if (!_matchesAnyTarget(uri, argusAuthTargets) || uri.hasFragment) {
      return null;
    }
    final parameters = _strictQuery(uri);
    if (parameters == null ||
        parameters.keys.length != 2 ||
        parameters['type'] != 'recovery') {
      return null;
    }
    final tokenHash = parameters['token_hash'];
    return tokenHash != null && _safeOpaqueValue(tokenHash, minimumLength: 16)
        ? tokenHash
        : null;
  }

  bool acceptsWebullCompletion(Uri uri) {
    if (!_matchesAnyTarget(uri, webullCompletionTargets) || uri.hasFragment) {
      return false;
    }
    final parameters = _strictQuery(uri);
    if (parameters == null || parameters.keys.length != 1) return false;
    final completion = parameters['completion'];
    return completion != null &&
        _safeOpaqueValue(completion, minimumLength: 16);
  }

  MemberNativeLinkKind? classify(Uri uri) {
    if (acceptsArgusAuthCallback(uri)) return MemberNativeLinkKind.argusAuth;
    if (acceptsWebullCompletion(uri)) {
      return MemberNativeLinkKind.webullCompletion;
    }
    return null;
  }

  static List<Uri> _parseTargets(String raw) {
    final entries = raw.split(',').map((entry) => entry.trim()).toList();
    if (entries.isEmpty || entries.any((entry) => entry.isEmpty)) {
      throw const FormatException('A native-link allowlist is empty.');
    }
    return entries
        .map((entry) {
          final uri = Uri.tryParse(entry);
          if (uri == null) {
            throw const FormatException('Invalid native-link URI.');
          }
          return uri;
        })
        .toList(growable: false);
  }

  static void _validateTargets(
    List<Uri> targets,
    String label, {
    required String customScheme,
  }) {
    if (targets.isEmpty) throw FormatException('$label allowlist is empty.');
    final unique = <String>{};
    for (final target in targets) {
      final isHttps = target.scheme == 'https';
      final isPrivateScheme = target.scheme == customScheme;
      if ((!isHttps && !isPrivateScheme) ||
          target.host.isEmpty ||
          target.path.isEmpty ||
          target.userInfo.isNotEmpty ||
          target.hasQuery ||
          target.hasFragment ||
          target.hasPort) {
        throw FormatException('$label contains an unsafe target.');
      }
      if (!unique.add(_targetKey(target))) {
        throw FormatException('$label contains a duplicate target.');
      }
    }
  }

  static bool _matchesAnyTarget(Uri candidate, List<Uri> targets) {
    if (candidate.userInfo.isNotEmpty || candidate.hasPort) return false;
    return targets.any(
      (target) =>
          candidate.scheme == target.scheme &&
          candidate.host == target.host &&
          candidate.port == target.port &&
          candidate.path == target.path,
    );
  }

  static Map<String, String>? _strictQuery(Uri uri) {
    if (!uri.hasQuery || uri.query.isEmpty) return const {};
    final values = <String, String>{};
    for (final segment in uri.query.split('&')) {
      final separator = segment.indexOf('=');
      if (separator <= 0 || separator != segment.lastIndexOf('=')) return null;
      final rawKey = segment.substring(0, separator);
      if (!RegExp(r'^[a-z_]+$').hasMatch(rawKey) ||
          values.containsKey(rawKey)) {
        return null;
      }
      try {
        final value = Uri.decodeQueryComponent(
          segment.substring(separator + 1),
        );
        values[rawKey] = value;
      } on FormatException {
        return null;
      }
    }
    return values;
  }

  static bool _safeOpaqueValue(String value, {required int minimumLength}) =>
      value.length >= minimumLength &&
      value.length <= 2048 &&
      !value.contains(RegExp(r'[\x00-\x1F\x7F]'));

  static String _targetKey(Uri uri) =>
      '${uri.scheme}://${uri.host}:${uri.port}${uri.path}';
}

class MemberAuthCancelled implements Exception {
  const MemberAuthCancelled();
}

class MemberAuthUnavailable implements Exception {
  const MemberAuthUnavailable([this.reason = 'member_auth_unavailable']);

  final String reason;
}

class MemberAccountMismatch implements Exception {
  const MemberAccountMismatch();
}

@immutable
class MemberClientExpectation {
  const MemberClientExpectation({
    required this.issuer,
    this.audience = 'authenticated',
  }) : assert(issuer != '');

  final String issuer;
  final String audience;
}

@immutable
class AuthSession {
  const AuthSession({
    required this.accessToken,
    this.userId,
    this.sessionId,
    this.authenticatedAt,
    this.expiresAt,
  });

  final String accessToken;
  final String? userId;
  final String? sessionId;
  final DateTime? authenticatedAt;
  final DateTime? expiresAt;
}

@immutable
class MemberSessionChange {
  const MemberSessionChange({required this.event, this.session});

  final MemberSessionEvent event;
  final AuthSession? session;
}

abstract interface class SessionRepository {
  MemberClientExpectation get memberClientExpectation;
  Stream<AuthSession> get recoveredSessions;
  Future<AuthSession?> recover();
  Future<void> logout();
}

/// Direct email/password authentication. Production repositories must never
/// launch a hosted provider or external browser from these methods.
abstract interface class PasswordSessionRepository {
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  });

  Future<AuthSession> signUpWithPassword({
    required String email,
    required String password,
  });
}

abstract interface class PasswordRecoverySessionRepository {
  Future<void> requestPasswordRecovery({required String email});
  Future<void> updatePassword({required String password});
}

abstract interface class InitialPasswordRecoveryRepository {
  bool consumeInitialPasswordRecovery();
}

/// Optional richer session stream implemented by providers that expose
/// refresh, recovery, sign-out, and auth-stream failures.
abstract interface class SessionChangeRepository {
  Stream<MemberSessionChange> get sessionChanges;
}

/// Optional scoped logout implemented by providers with server-side session
/// revocation. Callers still clear local member state even if revocation fails.
abstract interface class ScopedSessionLogout {
  Future<void> logoutWithScope(MemberLogoutScope scope);
}
