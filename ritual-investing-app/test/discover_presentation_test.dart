import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/discover/application/controller.dart';
import 'package:ritual_investing_app/features/discover/data/repository.dart';
import 'package:ritual_investing_app/features/discover/domain/model.dart';
import 'package:ritual_investing_app/features/discover/presentation/discover_screen.dart';

void main() {
  testWidgets('Discover is editorial and non-social at 2x text in dark mode', (
    tester,
  ) async {
    final controller = DiscoverController(
      repository: CachedDiscoverRepository(
        service: _DiscoverService(),
        cache: MemoryReadCache(),
      ),
      personalization: const MemberPersonalization(
        explanationDepth: MemberExplanationDepth.beginner,
        ritualVoice: MemberRitualVoice.practical,
        riskFraming: MemberRiskFraming.low,
      ),
    );
    await controller.load();
    DiscoverItemView? opened;
    SeededCreatorView? creator;
    var privateCirclesOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: DiscoverScreen(
            controller: controller,
            onOpenSearch: () {},
            onOpenItem: (item) => opened = item,
            onOpenCreator: (value) => creator = value,
            onOpenPrivateCircles: () => privateCirclesOpened = true,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('discover-lead')), findsOneWidget);
    expect(find.text('A steadier research lens'), findsOneWidget);
    expect(find.text('Why this appeared'), findsOneWidget);
    expect(find.textContaining('Fictional'), findsWidgets);
    expect(find.textContaining('follow'), findsNothing);
    expect(find.textContaining('comment'), findsNothing);
    expect(find.textContaining('message'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('discover-lead')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('discover-lead')));
    expect(opened?.id, _assetId);

    await tester.scrollUntilVisible(
      find.text('Patient Compounding'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('discover-secondary')), findsWidgets);

    await tester.scrollUntilVisible(
      find.byKey(const Key('discover-creator-$_creatorId')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('discover-creator-$_creatorId')));
    expect(creator?.id, _creatorId);

    await tester.scrollUntilVisible(
      find.byKey(const Key('discover-open-private-circles')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .getSize(find.byKey(const Key('discover-open-private-circles')))
          .height,
      greaterThanOrEqualTo(44),
    );
    await tester.ensureVisible(
      find.byKey(const Key('discover-open-private-circles')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('discover-open-private-circles')));
    expect(privateCirclesOpened, isTrue);
  });
}

const _assetId = '00000000-0000-4000-8000-000000000711';
const _creatorId = '00000000-0000-4000-8000-000000000712';

class _DiscoverService implements DiscoverService {
  @override
  Future<DiscoverModel> fetch() async => DiscoverModel(
    items: [
      _item(DiscoverItemKind.asset, _assetId, 'Quiet Power ETF'),
      _item(
        DiscoverItemKind.grimoire,
        '00000000-0000-4000-8000-000000000713',
        'Patient Compounding',
      ),
      _item(
        DiscoverItemKind.circleTemplate,
        '00000000-0000-4000-8000-000000000714',
        'Soft Power Circle',
        creator: _creator,
      ),
      _item(
        DiscoverItemKind.coven,
        '00000000-0000-4000-8000-000000000715',
        'Aurora Healthworks',
      ),
    ],
    creators: [_creator],
    nextCursor: null,
    hasMore: false,
  );
}

DiscoverItemView _item(
  DiscoverItemKind kind,
  String id,
  String title, {
  SeededCreatorView? creator,
}) => DiscoverItemView(
  id: id,
  revisionId: '00000000-0000-4000-8000-000000000716',
  slug: title.toLowerCase().replaceAll(' ', '-'),
  kind: kind,
  title: title,
  subtitle: 'Fictional provider-free Demo research.',
  appearanceReason: kind == DiscoverItemKind.asset
      ? 'Lower-volatility scenario evidence matched your comfort setting.'
      : null,
  creator: creator,
  demo: _demo,
);

final _creator = SeededCreatorView(
  id: _creatorId,
  slug: 'mira-vale',
  displayName: 'Mira Vale',
  bio: 'Fictional Demo curator.',
  isFictional: true,
  demo: _demo,
);

final _demo = ResearchDemoDisclosure(
  isDemo: true,
  observedAt: DateTime.utc(2026, 8, 25, 12),
  sourceLabel: 'Deterministic research fixture',
  limitations: ['Fictional scenario; no live market provider.'],
);
