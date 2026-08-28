import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android has exact distinct Argus Auth and Webull links with protected storage', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final backup = File('android/app/src/main/res/xml/backup_rules.xml')
        .readAsStringSync();
    final extraction = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();
    final protectedStorage = File('lib/core/api/flutter_protected_storage.dart')
        .readAsStringSync();

    expect(gradle, contains('ritualLinkHost'));
    expect(gradle, contains('just-build-this.app'));
    expect(gradle, isNot(contains(r'$applicationId')));
    expect(gradle, isNot(contains('.invalid')));
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('@xml/backup_rules'));
    expect(manifest.toLowerCase(), isNot(contains('auth0')));
    expect(gradle.toLowerCase(), isNot(contains('auth0')));
    expect(manifest, contains('android:path="/mobile/argus-auth/callback"'));
    expect(manifest, contains('android:path="/mobile/webull/complete"'));
    expect(
      manifest,
      contains(
        'android:scheme="com.ritualinvesting.ritual-investing-app.auth"',
      ),
    );
    expect(
      manifest,
      contains(
        'android:scheme="com.ritualinvesting.ritual-investing-app.webull"',
      ),
    );
    expect(
      RegExp(r'android:path="/mobile/argus-auth/callback"')
          .allMatches(manifest),
      hasLength(1),
    );
    expect(
      RegExp(r'android:path="/mobile/webull/complete"').allMatches(manifest),
      hasLength(1),
    );
    expect(
      protectedStorage,
      contains("storageNamespace: 'ritual_member_protected_v1'"),
    );
    for (final preferenceBaseName in const [
      'ritual_member_protected_v1',
      'FlutterSecureKeyStorage:ritual_member_protected_v1',
      'FlutterSecureStorageConfiguration:ritual_member_protected_v1',
    ]) {
      final preferenceFile = '$preferenceBaseName.xml';
      final exclusion = 'path="$preferenceFile"';
      expect(backup, contains(exclusion));
      expect(extraction.split(exclusion), hasLength(3));
      expect(backup, isNot(contains('path="$preferenceBaseName"')));
      expect(extraction, isNot(contains('path="$preferenceBaseName"')));
    }
    expect(backup, isNot(contains('path="FlutterSecureStorage"')));
  });

  test('iOS has claimed links and distinct Supabase/Webull custom schemes', () {
    final entitlements = File('ios/Runner/Runner.entitlements')
        .readAsStringSync();
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    final project = File('ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();
    final debugConfig = File('ios/Flutter/Debug.xcconfig').readAsStringSync();
    final releaseConfig = File('ios/Flutter/Release.xcconfig')
        .readAsStringSync();
    final nativeLinksExample = File('ios/Flutter/NativeLinks.xcconfig.example')
        .readAsStringSync();

    expect(entitlements, contains('com.apple.developer.associated-domains'));
    expect(entitlements, contains(r'applinks:$(RITUAL_LINK_HOST)'));
    expect(entitlements.toLowerCase(), isNot(contains('auth0')));
    expect(info, contains(r'$(PRODUCT_BUNDLE_IDENTIFIER)'));
    expect(info, contains('com.ritualinvesting.ritual-investing-app.auth'));
    expect(info, contains('com.ritualinvesting.ritual-investing-app.webull'));
    expect(
      project,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements'),
    );
    expect(project.toLowerCase(), isNot(contains('auth0')));
    expect(debugConfig.toLowerCase(), isNot(contains('auth0')));
    expect(releaseConfig.toLowerCase(), isNot(contains('auth0')));
    expect(debugConfig, contains('#include? "NativeLinks.xcconfig"'));
    expect(releaseConfig, contains('#include? "NativeLinks.xcconfig"'));
    expect(
      nativeLinksExample,
      contains('RITUAL_LINK_HOST = just-build-this.app'),
    );
  });
}
