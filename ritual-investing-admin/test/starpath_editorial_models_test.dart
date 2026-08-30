import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_admin/features/starpath/domain/starpath_editorial_models.dart';

import 'support/starpath_fixture.dart';

void main() {
  test('round-trips the complete typed Starpath lesson payload', () {
    final lesson = StarpathLessonDraft.fromPayload(starpathLessonFixture());

    expect(lesson.stableKey, 'share-sigil');
    expect(lesson.sections.single.evidence.single.publisher, 'SEC');
    expect(
      lesson.check.options.where((option) => option.isCorrect),
      hasLength(1),
    );
    expect(lesson.validationIssues, isEmpty);
    expect(lesson.toPayload(), starpathLessonFixture());
  });

  test(
    'rejects advice, incomplete risks, stale evidence, and choice checks',
    () {
      final payload = starpathLessonFixture();
      payload['factual_summary'] = 'You should buy this ETF.';
      payload['material_limitations'] = '';
      final sections = payload['sections']! as List<Object?>;
      final evidence =
          ((sections.single! as Map<String, Object?>)['evidence']!
                      as List<Object?>)
                  .single!
              as Map<String, Object?>;
      evidence.remove('source_observed_at');
      final check = payload['check']! as Map<String, Object?>;
      check['prompt'] = 'Which investment would you choose?';

      final lesson = StarpathLessonDraft.fromPayload(payload);

      expect(
        lesson.validationIssues,
        contains('Subjective investment guidance is prohibited.'),
      );
      expect(
        lesson.validationIssues,
        contains('Material limitations are required.'),
      );
      expect(
        lesson.validationIssues,
        contains('Every source needs an observation date.'),
      );
      expect(
        lesson.validationIssues,
        contains('Checks may assess facts only, never investment preference.'),
      );
    },
  );

  test('requires an exact ordered eight-node manifest', () {
    final complete = StarpathManifestDraft(
      manifestId: '11111111-1111-4111-8111-111111111111',
      manifestVersion: 'starpath-v1',
      policyVersion: 'starpath-no-advice-v1',
      releaseEnvironment: StarpathReleaseEnvironment.beta,
      supportedJurisdiction: 'US',
      themeIds: const ['22222222-2222-4222-8222-222222222222'],
      nodes: List.generate(
        8,
        (index) => StarpathManifestNodeDraft(
          nodeOrdinal: index + 1,
          pathwayOrdinal: (index ~/ 2) + 1,
          pathwayPosition: (index % 2) + 1,
          lessonId: 'lesson-${index + 1}',
          revisionId: 'revision-${index + 1}',
          title: 'Lesson ${index + 1}',
          revisionState: 'approved',
          factualApproved: true,
          complianceApproved: true,
        ),
      ),
    );

    expect(complete.validationIssues, isEmpty);
    expect(
      StarpathManifestDraft(
        manifestId: complete.manifestId,
        manifestVersion: complete.manifestVersion,
        policyVersion: complete.policyVersion,
        releaseEnvironment: complete.releaseEnvironment,
        supportedJurisdiction: complete.supportedJurisdiction,
        themeIds: complete.themeIds,
        nodes: complete.nodes.take(7).toList(),
      ).validationIssues,
      contains('A manifest must contain exactly eight nodes.'),
    );
  });
}
