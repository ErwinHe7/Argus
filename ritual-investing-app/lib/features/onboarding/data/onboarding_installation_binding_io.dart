import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'onboarding_draft_store.dart';

/// Binds protected onboarding data to this installation through a non-backed-up
/// app-container cache marker.
///
/// Cache eviction intentionally fails closed: a replacement marker makes an
/// existing protected draft orphaned, and [OnboardingDraftStore.read] purges it.
class AppContainerInstallationBinding implements InstallationBinding {
  AppContainerInstallationBinding({
    required this.cacheDirectoryProvider,
    Random? random,
  }) : _random = random ?? Random.secure();

  static const fileName = '.onboarding-install-v1';
  final Future<Directory> Function() cacheDirectoryProvider;
  final Random _random;
  Future<String>? _resolvedId;

  @override
  Future<String> currentId() => _resolvedId ??= _readOrCreate();

  Future<String> _readOrCreate() async {
    final directory = await cacheDirectoryProvider();
    if (!await directory.exists()) await directory.create(recursive: true);
    final marker = File('${directory.path}${Platform.pathSeparator}$fileName');
    if (await marker.exists()) {
      final existing = (await marker.readAsString()).trim();
      if (_isInstallationId(existing)) return existing;
    }
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    final created = base64Url.encode(bytes).replaceAll('=', '');
    await marker.writeAsString(created, flush: true);
    return created;
  }
}

bool _isInstallationId(String value) =>
    value.length == 32 &&
    value.codeUnits.every(
      (code) =>
          (code >= 48 && code <= 57) ||
          (code >= 65 && code <= 90) ||
          (code >= 97 && code <= 122) ||
          code == 45 ||
          code == 95,
    );
