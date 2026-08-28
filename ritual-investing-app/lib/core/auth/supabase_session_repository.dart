// ignore_for_file: deprecated_member_use, prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'member_auth.dart';

class MemberSupabaseSession {
  const MemberSupabaseSession({
    required this.accessToken,
    required this.userId,
  });

  final String accessToken;
  final String userId;
}

class MemberSupabaseAuthChange {
  const MemberSupabaseAuthChange({required this.event, this.session});

  final MemberSessionEvent event;
  final MemberSupabaseSession? session;
}

abstract interface class MemberSupabaseAuthClient {
  Stream<MemberSupabaseAuthChange> get events;

  Future<MemberSupabaseSession?> getCurrentSession();

  Future<MemberSupabaseSession> refreshCurrentSession();

  Future<bool> launchOAuth({
    required MemberAuthProvider provider,
    required Uri redirectTo,
    required String scopes,
    required Map<String, String> queryParameters,
  });

  Future<void> signOut(MemberLogoutScope scope);
}

class SupabaseFlutterAuthClient implements MemberSupabaseAuthClient {
  SupabaseFlutterAuthClient(this._client);

  final SupabaseClient _client;

  @override
  Stream<MemberSupabaseAuthChange> get events =>
      _client.auth.onAuthStateChange.map(
        (change) => MemberSupabaseAuthChange(
          event: _event(change.event),
          session: _snapshot(change.session),
        ),
      );

  @override
  Future<MemberSupabaseSession?> getCurrentSession() async =>
      _snapshot(_client.auth.currentSession);

  @override
  Future<MemberSupabaseSession> refreshCurrentSession() async {
    final session = _snapshot((await _client.auth.refreshSession()).session);
    if (session == null) throw const MemberAuthUnavailable('refresh_failed');
    return session;
  }

  @override
  Future<bool> launchOAuth({
    required MemberAuthProvider provider,
    required Uri redirectTo,
    required String scopes,
    required Map<String, String> queryParameters,
  }) => _client.auth.signInWithOAuth(
    switch (provider) {
      MemberAuthProvider.apple => OAuthProvider.apple,
      MemberAuthProvider.google => OAuthProvider.google,
    },
    redirectTo: redirectTo.toString(),
    scopes: scopes,
    queryParams: queryParameters,
    authScreenLaunchMode: LaunchMode.externalApplication,
  );

  @override
  Future<void> signOut(MemberLogoutScope scope) => _client.auth.signOut(
    scope: switch (scope) {
      MemberLogoutScope.local => SignOutScope.local,
      MemberLogoutScope.global => SignOutScope.global,
    },
  );

  static MemberSupabaseSession? _snapshot(Session? session) => session == null
      ? null
      : MemberSupabaseSession(
          accessToken: session.accessToken,
          userId: session.user.id,
        );

  static MemberSessionEvent _event(AuthChangeEvent event) => switch (event) {
    AuthChangeEvent.initialSession => MemberSessionEvent.initialSession,
    AuthChangeEvent.signedIn => MemberSessionEvent.signedIn,
    AuthChangeEvent.signedOut => MemberSessionEvent.signedOut,
    AuthChangeEvent.passwordRecovery => MemberSessionEvent.passwordRecovery,
    AuthChangeEvent.tokenRefreshed => MemberSessionEvent.tokenRefreshed,
    AuthChangeEvent.userUpdated => MemberSessionEvent.userUpdated,
    AuthChangeEvent.userDeleted => MemberSessionEvent.userDeleted,
    AuthChangeEvent.mfaChallengeVerified =>
      MemberSessionEvent.mfaChallengeVerified,
  };
}

class SupabaseSessionRepository
    implements SessionRepository, SessionChangeRepository, ScopedSessionLogout {
  SupabaseSessionRepository({
    required MemberSupabaseAuthClient client,
    required this.provider,
    required this.nativeLinks,
    required Uri supabaseUrl,
    DateTime Function()? now,
    this.oauthCompletionTimeout = const Duration(minutes: 5),
  }) : _client = client,
       _now = now ?? DateTime.now,
       memberClientExpectation = MemberClientExpectation(
         issuer: '${_withoutTrailingSlash(supabaseUrl.toString())}/auth/v1',
         audience: 'authenticated',
       );

  factory SupabaseSessionRepository.production({
    required SupabaseClient client,
    required MemberAuthProvider provider,
    required MemberNativeLinkPolicy nativeLinks,
    required Uri supabaseUrl,
  }) => SupabaseSessionRepository(
    client: SupabaseFlutterAuthClient(client),
    provider: provider,
    nativeLinks: nativeLinks,
    supabaseUrl: supabaseUrl,
  );

  final MemberSupabaseAuthClient _client;
  final DateTime Function() _now;
  final MemberAuthProvider provider;
  final MemberNativeLinkPolicy nativeLinks;
  final Duration oauthCompletionTimeout;

  @override
  final MemberClientExpectation memberClientExpectation;

  @override
  Stream<MemberSessionChange> get sessionChanges => _client.events.asyncMap(
    (change) async => MemberSessionChange(
      event: change.event,
      session: change.session == null ? null : _validated(change.session!),
    ),
  );

  @override
  Stream<AuthSession> get recoveredSessions => sessionChanges
      .where((change) => change.session != null)
      .map((change) => change.session!);

  @override
  Future<AuthSession> authenticate(MemberAuthIntent intent) async {
    AuthSession? existing;
    if (intent.kind == MemberAuthIntentKind.recentAuth) {
      existing = await recover();
      if (existing == null) throw const MemberAuthUnavailable('no_session');
      if (provider != MemberAuthProvider.google) {
        throw const MemberAuthUnavailable(
          'recent_auth_not_supported_by_provider',
        );
      }
    }

    final completion = Completer<MemberSupabaseAuthChange>();
    final subscription = _client.events.listen(
      (change) {
        if (!completion.isCompleted &&
            change.event == MemberSessionEvent.signedIn &&
            change.session != null) {
          completion.complete(change);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completion.isCompleted) {
          completion.completeError(error, stackTrace);
        }
      },
    );
    try {
      final launched = await _client.launchOAuth(
        provider: provider,
        redirectTo: nativeLinks.preferredArgusAuthRedirect,
        scopes: _scopes(provider),
        queryParameters: _queryParameters(intent),
      );
      if (!launched) throw const MemberAuthCancelled();

      late final MemberSupabaseAuthChange change;
      try {
        change = await completion.future.timeout(oauthCompletionTimeout);
      } on TimeoutException {
        throw const MemberAuthCancelled();
      }
      final session = _validated(change.session!);
      if (existing != null) {
        if (existing.userId != session.userId) {
          throw const MemberAccountMismatch();
        }
        final authenticatedAt = session.authenticatedAt;
        final maximumAge = intent.maxAge!;
        if (authenticatedAt == null ||
            authenticatedAt.isAfter(
              _now().toUtc().add(const Duration(seconds: 30)),
            ) ||
            _now().toUtc().difference(authenticatedAt) > maximumAge) {
          throw const MemberAuthUnavailable('recent_auth_not_proven');
        }
      }
      return session;
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<AuthSession?> recover() async {
    final session = await _client.getCurrentSession();
    if (session == null) return null;
    final restored = _validated(session, allowExpired: true);
    if (!restored.expiresAt!.isAfter(
      _now().toUtc().add(const Duration(minutes: 1)),
    )) {
      return _validated(await _client.refreshCurrentSession());
    }
    return restored;
  }

  @override
  Future<void> logout() => logoutWithScope(MemberLogoutScope.local);

  @override
  Future<void> logoutWithScope(MemberLogoutScope scope) =>
      _client.signOut(scope);

  AuthSession _validated(
    MemberSupabaseSession session, {
    bool allowExpired = false,
  }) {
    final claims = _jwtPayload(session.accessToken);
    final subject = claims['sub'];
    final sessionId = claims['session_id'];
    final issuer = claims['iss'];
    final expiresAtSeconds = _integerClaim(claims['exp']);
    final audiences = switch (claims['aud']) {
      final String audience => {audience},
      final List<dynamic> audiences => audiences.whereType<String>().toSet(),
      _ => const <String>{},
    };
    if (subject != session.userId ||
        subject is! String ||
        sessionId is! String ||
        !_uuid.hasMatch(subject) ||
        !_uuid.hasMatch(sessionId) ||
        issuer != memberClientExpectation.issuer ||
        !audiences.contains(memberClientExpectation.audience) ||
        expiresAtSeconds == null) {
      throw const MemberAuthUnavailable('invalid_session_claims');
    }
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      expiresAtSeconds * 1000,
      isUtc: true,
    );
    if (!allowExpired && !expiresAt.isAfter(_now().toUtc())) {
      throw const MemberAuthUnavailable('expired_session');
    }
    return AuthSession(
      accessToken: session.accessToken,
      userId: subject,
      sessionId: sessionId,
      authenticatedAt: _authenticationTime(claims['amr']),
      expiresAt: expiresAt,
    );
  }

  Map<String, String> _queryParameters(MemberAuthIntent intent) {
    if (intent.kind != MemberAuthIntentKind.recentAuth) return const {};
    return {
      'prompt': 'select_account',
      'max_age': intent.maxAge!.inSeconds.toString(),
      'claims': jsonEncode({
        'id_token': {
          'auth_time': {'essential': true},
        },
      }),
    };
  }

  static String _scopes(MemberAuthProvider provider) => switch (provider) {
    MemberAuthProvider.apple => 'email name',
    MemberAuthProvider.google => 'openid email profile',
  };

  static DateTime? _authenticationTime(Object? raw) {
    if (raw is! List<dynamic>) return null;
    int? latest;
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      final timestamp = _integerClaim(entry['timestamp']);
      if (timestamp != null && (latest == null || timestamp > latest)) {
        latest = timestamp;
      }
    }
    return latest == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(latest * 1000, isUtc: true);
  }

  static Map<String, dynamic> _jwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3 || parts.any((part) => part.isEmpty)) {
      throw const MemberAuthUnavailable('malformed_session_token');
    }
    try {
      final decoded = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final payload = jsonDecode(decoded);
      if (payload is! Map<String, dynamic>) {
        throw const FormatException('JWT payload is not an object.');
      }
      return payload;
    } on Object {
      throw const MemberAuthUnavailable('malformed_session_token');
    }
  }

  static int? _integerClaim(Object? value) => switch (value) {
    final int value => value,
    final num value when value.isFinite && value == value.roundToDouble() =>
      value.toInt(),
    _ => null,
  };

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static String _withoutTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}

abstract interface class MemberAuthSecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterMemberAuthSecureStorage implements MemberAuthSecureStorage {
  FlutterMemberAuthSecureStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              storageNamespace: 'ritual_member_protected_v1',
              migrateWithBackup: false,
            ),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
              synchronizable: false,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class SecureSupabaseLocalStorage extends LocalStorage {
  SecureSupabaseLocalStorage(this._storage);

  static const _sessionKey = 'supabase-member-session-v1';
  final MemberAuthSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      (await _storage.read(_sessionKey)) != null;

  @override
  Future<String?> accessToken() => _storage.read(_sessionKey);

  @override
  Future<void> removePersistedSession() => _storage.delete(_sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) async {
    final value = jsonDecode(persistSessionString);
    if (value is! Map<String, dynamic> ||
        value['access_token'] is! String ||
        value['refresh_token'] is! String ||
        value['user'] is! Map<String, dynamic>) {
      throw const FormatException('Refusing to persist an invalid session.');
    }
    value.remove('provider_token');
    value.remove('provider_refresh_token');
    await _storage.write(_sessionKey, jsonEncode(value));
  }
}

class SecureSupabasePkceStorage extends GotrueAsyncStorage {
  SecureSupabasePkceStorage(this._storage);

  static const _prefix = 'supabase-member-pkce-v1:';
  final MemberAuthSecureStorage _storage;

  String _key(String key) {
    if (key.isEmpty ||
        key.length > 256 ||
        key.contains(RegExp(r'[\x00-\x20\x7F]'))) {
      throw const FormatException('Invalid PKCE storage key.');
    }
    return '$_prefix$key';
  }

  @override
  Future<String?> getItem({required String key}) => _storage.read(_key(key));

  @override
  Future<void> removeItem({required String key}) => _storage.delete(_key(key));

  @override
  Future<void> setItem({required String key, required String value}) {
    if (value.isEmpty || value.length > 4096) {
      throw const FormatException('Invalid PKCE storage value.');
    }
    return _storage.write(_key(key), value);
  }
}

Future<SupabaseClient> initializeMemberSupabase({
  required Uri url,
  required String publishableKey,
  required MemberNativeLinkPolicy nativeLinks,
  MemberAuthSecureStorage? secureStorage,
}) async {
  final storage = secureStorage ?? FlutterMemberAuthSecureStorage();
  final instance = await Supabase.initialize(
    url: url.toString(),
    publishableKey: publishableKey,
    debug: false,
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
      persistSession: true,
      localStorage: SecureSupabaseLocalStorage(storage),
      pkceAsyncStorage: SecureSupabasePkceStorage(storage),
      detectSessionInUri: true,
      detectSessionInUriPredicate: nativeLinks.acceptsArgusAuthCallback,
    ),
  );
  return instance.client;
}
