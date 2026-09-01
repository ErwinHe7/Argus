import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/starpath/application/starpath_controller.dart';
import 'package:ritual_investing_app/features/starpath/data/starpath_repository.dart';
import 'package:ritual_investing_app/features/starpath/domain/starpath.dart';

StarpathController starpathFixtureController({
  int version = 2,
  int currentOrdinal = 3,
  bool recall = false,
  StarpathAnswerFeedback? answer,
  bool offline = false,
  bool draftPreview = false,
}) {
  final snapshot = starpathFixtureSnapshot(
    version: version,
    currentOrdinal: currentOrdinal,
    recall: recall,
    answer: answer,
    draftPreview: draftPreview,
  );
  return StarpathController(
    repository: StarpathRepository(
      service: StarpathFixtureService(snapshot: snapshot, offline: offline),
      cache: MemoryReadCache(),
    ),
    createKey: () => 'fixture-command-key',
  );
}

class StarpathFixtureService implements StarpathService {
  StarpathFixtureService({required this.snapshot, this.offline = false});

  StarpathSnapshot snapshot;
  bool offline;

  @override
  Future<StarpathSnapshot> fetch() async {
    if (offline) throw const OfflineException();
    return snapshot;
  }

  @override
  Future<StarpathSnapshot> start({required String idempotencyKey}) async =>
      snapshot;

  @override
  Future<StarpathSnapshot> answer({
    required String idempotencyKey,
    required int version,
    required StarpathAnswerCommand command,
  }) async => snapshot;

  @override
  Future<StarpathSnapshot> skipRecall({
    required String idempotencyKey,
    required int version,
    required String sessionId,
  }) async => snapshot;
}

StarpathSnapshot starpathFixtureSnapshot({
  int version = 2,
  int currentOrdinal = 3,
  bool recall = false,
  StarpathAnswerFeedback? answer,
  bool draftPreview = false,
}) => StarpathSnapshot(
  availability: StarpathAvailability.available,
  version: version,
  authority: StarpathAuthority(
    environment: StarpathEnvironment.beta,
    jurisdiction: 'US',
    capabilityVersion: 4,
    policyVersion: draftPreview
        ? 'starpath-no-advice-v1-draft'
        : 'starpath-no-advice-v1',
    manifestId: 'manifest-1',
    manifestVersion: draftPreview ? draftPreviewStarpathManifestVersion : '1',
  ),
  nodes: List.generate(8, (index) {
    final ordinal = index + 1;
    return StarpathNode(
      lessonId: 'lesson-$ordinal',
      revisionId: 'revision-$ordinal',
      nodeOrdinal: ordinal,
      pathwayOrdinal: (index ~/ 2) + 1,
      pathwayPosition: (index % 2) + 1,
      title: [
        'The Share Sigil',
        'The Market Lantern',
        'The Many-Star Shield',
        'The Fee Eclipse',
        'The Filing Grimoire',
        'The Fund and Bond Map',
        'The False Sun',
        'The Verification Compass',
      ][index],
      mythicMnemonic: 'Picture a steady star marking the definition, never predicting an outcome.',
      factualSummary:
          'A share generally represents an ownership interest in an issuer.',
      materialLimitations: 'Rights vary by security, share class, issuer, and governing documents.',
      riskContext:
          'A security’s market value can rise or fall, including to zero.',
      recallPrompt: 'What does a share generally represent?',
      rowanExplanation: 'The star is only a memory marker. The reviewed fact is the ownership definition and its limits.',
      guide: const StarpathGuide(
        tarotKey: 'the-star',
        accessibleLabel: 'The Star, used only as a memory aid.',
      ),
      factualSections: [
        StarpathFactualSection(
          ordinal: 1,
          kind: StarpathFactualSectionKind.fact,
          heading: 'Ownership units',
          body: 'Common stock generally represents an ownership interest in an issuer.',
          observedAt: DateTime.utc(2026, 8, 29),
          uncertainty: 'Specific contractual rights can differ.',
          evidence: [
            StarpathEvidence(
              ordinal: 1,
              publisher: 'Investor.gov',
              sourceTitle: 'Stocks',
              canonicalUrl: Uri.parse(
                'https://www.investor.gov/introduction-investing/investing-basics/investment-products/stocks',
              ),
              claimSummary: 'A stock is a security that can give holders an ownership interest.',
              retrievedAt: DateTime.utc(2026, 8, 29),
              sourceObservedAt: DateTime.utc(2026, 8, 29),
              currentUntil: DateTime.utc(2027, 8, 29),
            ),
          ],
        ),
      ],
      knowledgeCheck: StarpathKnowledgeCheck(
        id: 'question-$ordinal',
        prompt: 'Which statement is factual?',
        options: [
          StarpathKnowledgeCheckOption(
            id: 'option-$ordinal-a',
            ordinal: 1,
            label: 'A share can represent an ownership interest.',
          ),
          StarpathKnowledgeCheckOption(
            id: 'option-$ordinal-b',
            ordinal: 2,
            label: 'A share guarantees a positive return.',
          ),
        ],
      ),
      state: ordinal < currentOrdinal
          ? StarpathNodeState.completed
          : ordinal == currentOrdinal
          ? StarpathNodeState.current
          : StarpathNodeState.locked,
    );
  }),
  session: StarpathSession(
    id: 'session-1',
    explicitStart: true,
    startedAt: DateTime.utc(2026, 8, 29),
    lastActionAt: DateTime.utc(2026, 8, 30),
    state: StarpathSessionState.active,
  ),
  progress: StarpathProgress(
    currentNodeOrdinal: currentOrdinal,
    version: version,
    updatedAt: DateTime.utc(2026, 8, 30),
  ),
  theme: const StarpathTheme(
    id: 'theme-1',
    key: 'walk-the-stars',
    title: 'Walk the Stars',
    horoscopeFrame: 'Virgo season asks for clear definitions—used here only as a memory frame.',
    factualFocus: 'Learn how investment terms and records work.',
    accessibleLabel: 'A constellation-shaped factual learning path.',
  ),
  recall: recall
      ? StarpathRecall(
          id: 'recall-1',
          lessonId: 'lesson-1',
          revisionId: 'revision-1',
          questionId: 'recall-question-1',
          prompt: 'Before the next star, recall the ownership definition.',
          knowledgeCheck: StarpathKnowledgeCheck(
            id: 'recall-question-1',
            prompt: 'What can common stock represent?',
            options: const [
              StarpathKnowledgeCheckOption(
                id: 'recall-a',
                ordinal: 1,
                label: 'An ownership interest',
              ),
              StarpathKnowledgeCheckOption(
                id: 'recall-b',
                ordinal: 2,
                label: 'A guaranteed return',
              ),
            ],
          ),
        )
      : null,
  answer: answer,
);
