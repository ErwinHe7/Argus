import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/creators/application/controller.dart';
import 'package:ritual_investing_app/features/creators/data/repository.dart';
import 'package:ritual_investing_app/features/creators/presentation/creator_detail_screen.dart';
import 'package:ritual_investing_app/features/discover/domain/model.dart';

void main() {
  testWidgets('creator detail is stable-ID hydrated and fictional/read-only', (
    tester,
  ) async {
    final service = _CreatorService();
    final controller = CreatorController(
      creatorId: _creatorId,
      repository: CreatorRepository(service: service, cache: MemoryReadCache()),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CreatorDetailScreen(controller: controller),
      ),
    );

    expect(controller.state.phase, LoadPhase.ready);
    expect(service.requestedIds, [_creatorId]);
    expect(find.text('Mira Vale'), findsOneWidget);
    expect(find.text('Fictional Demo creator'), findsOneWidget);
    expect(find.textContaining('read-only'), findsOneWidget);
    expect(find.textContaining('follow'), findsNothing);
    expect(find.textContaining('message'), findsNothing);
  });
}

const _creatorId = '00000000-0000-4000-8000-000000000746';

class _CreatorService implements CreatorService {
  final List<String> requestedIds = [];

  @override
  Future<SeededCreatorView> fetchById(String creatorId) async {
    requestedIds.add(creatorId);
    return SeededCreatorView(
      id: _creatorId,
      slug: 'mira-vale',
      displayName: 'Mira Vale',
      bio: 'A fictional curator for deterministic research scenarios.',
      isFictional: true,
      demo: ResearchDemoDisclosure(
        isDemo: true,
        observedAt: DateTime.utc(2026, 8, 25, 12),
        sourceLabel: 'Deterministic creator fixture',
        limitations: const ['Fictional identity; no public social profile.'],
      ),
    );
  }
}
