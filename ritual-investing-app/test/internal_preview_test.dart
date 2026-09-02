import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/bootstrap/app_runtime.dart';
import 'package:ritual_investing_app/core/navigation/member_routes.dart';
import 'package:ritual_investing_app/internal_preview/internal_preview.dart';
import 'package:ritual_investing_app/internal_preview/internal_preview_services.dart';

void main() {
  test('preview is explicit, web-only, and ignores lookalike values', () {
    final enabled = Uri.parse('https://leo.example/app/?preview=1#/welcome');
    final disabled = Uri.parse('https://leo.example/app/#/welcome');
    final lookalike = Uri.parse('https://leo.example/app/?preview=true');

    expect(shouldLaunchInternalPreview(enabled, isWebOverride: true), isTrue);
    expect(shouldLaunchInternalPreview(disabled, isWebOverride: true), isFalse);
    expect(
      shouldLaunchInternalPreview(lookalike, isWebOverride: true),
      isFalse,
    );
    expect(shouldLaunchInternalPreview(enabled, isWebOverride: false), isFalse);
  });

  test(
    'preview services stay provider-free and expose every member branch',
    () async {
      final source = File('lib/internal_preview/internal_preview_services.dart')
          .readAsStringSync();
      for (final forbidden in const [
        'supabase_flutter',
        'ritual_investing_api_client',
        'dio',
        '.supabase.co',
        '/functions/v1/',
        'window.localStorage',
        'window.sessionStorage',
        'window.indexedDB',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }

      final container = createInternalPreviewDependencyContainer(
        includeU9: true,
        includeSearch: true,
      );
      addTearDown(container.dispose);
      await container.bootstrap();

      expect(container.entryGate, MemberEntryGate.member);
      expect(
        MemberNavigationPolicy.fromBootstrap(container.memberBootstrap)
            .branches,
        MemberBranch.values,
      );
      expect(container.hasBriefingsAndNotifications, isTrue);
      expect(container.optionalSearchController, isNotNull);
    },
  );

  testWidgets('preview enters the product with a persistent safety label', (
    tester,
  ) async {
    await tester.pumpWidget(createInternalPreviewApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('INTERNAL PREVIEW'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    for (final label in const [
      'Gospel',
      'Starpath',
      'Discover',
      'Coven',
      'You',
    ]) {
      expect(find.text(label), findsWidgets);
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
