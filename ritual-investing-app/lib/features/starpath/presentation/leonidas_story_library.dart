import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_theme.dart';
import '../application/starpath_controller.dart';
import '../application/starpath_narration_controller.dart';
import '../domain/leonidas_story.dart';
import 'leonidas_story_screen.dart';

// A local script namespace, independent of any hosted curriculum revision.
const _practiceRevision = 'leonidas-supplementary-v1';
const _practiceNotice =
    'Supplementary practice. No recorded progress or knowledge checks.';

/// A separate practice collection. It never binds scripts to hosted lessons
/// or sends learning commands through the controller.
class LeonidasStoryLibrary extends StatelessWidget {
  const LeonidasStoryLibrary({
    super.key,
    required this.controller,
    required this.narrationPreference,
    this.narrationEngineFactory = createStarpathNarrationEngine,
  });

  final StarpathController controller;
  final StarpathNarrationPreference narrationPreference;
  final StarpathNarrationEngineFactory narrationEngineFactory;

  @override
  Widget build(BuildContext context) => _PracticeAccess(
    controller: controller,
    builder: (context) => Scaffold(
      appBar: AppBar(title: const Text('Stories with Leonidas')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              key: const Key('leonidas-story-library'),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              children: [
                Text(
                  'The Observatory’s First Light',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Help Leonidas restore four pages of the market atlas. '
                  'Choose any chapter; each takes about 3–5 minutes.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                const Text(_practiceNotice),
                const SizedBox(height: 28),
                for (
                  var index = 0;
                  index < leonidasStories.length;
                  index++
                ) ...[
                  ListTile(
                    key: Key('leonidas-library-chapter-${index + 1}'),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    leading: Text(
                      '${index + 1}',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: context.ritualColors.gold),
                    ),
                    title: Text(leonidasStories[index].title),
                    subtitle: Text(leonidasStories[index].lessonTitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => _PracticeStoryRoute(
                          controller: controller,
                          story: leonidasStories[index],
                          narrationPreference: narrationPreference,
                          narrationEngineFactory: narrationEngineFactory,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PracticeStoryRoute extends StatelessWidget {
  const _PracticeStoryRoute({
    required this.controller,
    required this.story,
    required this.narrationPreference,
    required this.narrationEngineFactory,
  });

  final StarpathController controller;
  final LeonidasStory story;
  final StarpathNarrationPreference narrationPreference;
  final StarpathNarrationEngineFactory narrationEngineFactory;

  @override
  Widget build(BuildContext context) => _PracticeAccess(
    controller: controller,
    builder: (context) => LeonidasStoryScreen(
      playback: controller.storyVisit.open(_practiceRevision, story),
      narrationPreference: narrationPreference,
      narrationEngineFactory: narrationEngineFactory,
      onNotes: () async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => _PracticeAccess(
              controller: controller,
              builder: (_) => _StoryNotesScreen(story: story),
            ),
          ),
        );
      },
      onContinue: () async => Navigator.of(context).pop(),
      continueLabel: 'Back to stories',
    ),
  );
}

/// Every pushed practice route follows the current access read. Removing the
/// player also disposes its voice when Starpath is no longer available.
class _PracticeAccess extends StatelessWidget {
  const _PracticeAccess({required this.controller, required this.builder});

  final StarpathController controller;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.dark,
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.state.phase == StarpathViewPhase.ready &&
            controller.state.snapshot != null) {
          return builder(context);
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Stories with Leonidas')),
          body: const SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Stories are unavailable while Starpath reloads. '
                  'Return to Starpath to check your connection and access.',
                  key: Key('leonidas-practice-unavailable'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _StoryNotesScreen extends StatelessWidget {
  const _StoryNotesScreen({required this.story});
  final LeonidasStory story;

  @override
  Widget build(BuildContext context) {
    final notes = _notes[story.id]!;
    return Scaffold(
      appBar: AppBar(title: const Text('Lesson notes')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              key: const Key('leonidas-practice-notes'),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              children: [
                Text(
                  story.lessonTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text(_practiceNotice),
                const SizedBox(height: 24),
                _NoteSection(title: 'The idea', body: notes.body),
                _NoteSection(title: 'Uncertainty', body: notes.uncertainty),
                _NoteSection(title: 'Limitations', body: notes.limitations),
                _NoteSection(title: 'Risk context', body: notes.risk),
                const _NoteSection(
                  title: 'About the examples',
                  body:
                      'The story, characters, company examples, and quote '
                      'values are illustrative. They are not observed market '
                      'data, predictions, or investment recommendations.',
                ),
                Text('Source', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Investor.gov · ${notes.sourceTitle}'),
                const SizedBox(height: 8),
                const Text(
                  'Notes adapted from the lesson material dated August 31, '
                  '2026. These references support the factual concepts; the '
                  'fictional story is a memory aid.',
                ),
                const SizedBox(height: 8),
                SelectableText(notes.sourceUrl),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('leonidas-practice-source'),
                    onPressed: () => _openSource(context, notes.sourceUrl),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Read on Investor.gov'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSource(BuildContext context, String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      // Keep the selectable canonical URL available if the platform cannot open it.
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the source. Copy the link above to read it.',
          ),
        ),
      );
    }
  }
}

class _NoteSection extends StatelessWidget {
  const _NoteSection({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}

class _StoryNotes {
  const _StoryNotes({
    required this.body,
    required this.uncertainty,
    required this.limitations,
    required this.risk,
    required this.sourceTitle,
    required this.sourceUrl,
  });
  final String body;
  final String uncertainty;
  final String limitations;
  final String risk;
  final String sourceTitle;
  final String sourceUrl;
}

// Copied from the first four internal-preview factual sections and their
// owning parts. Kept feature-owned so member builds never import preview data.
const _notes = <String, _StoryNotes>{
  'garden-v1': _StoryNotes(
    body: 'Investing means putting capital into an asset because you expect it to create or preserve value over time. It usually involves longer-term ownership. Trading is different: it focuses on trying to profit from shorter-term price moves. Both involve risk, and neither promises a profit.',
    uncertainty: 'The line between investing and trading is not always perfectly sharp, but they require different habits and time horizons.',
    limitations: 'These definitions explain ownership, not whether any asset is suitable for someone.',
    risk: 'Investments can lose value, including shares of familiar companies.',
    sourceTitle: 'Introduction to Investing',
    sourceUrl: 'https://www.investor.gov/introduction-investing',
  ),
  'seal-v1': _StoryNotes(
    body: 'A stock is a piece of ownership in a company. One share is one small unit of that ownership, and a person who owns it is a shareholder. A ticker is the short code for the stock: Apple is AAPL, Nvidia is NVDA, and Tesla is TSLA.',
    uncertainty: 'A familiar company can still have a falling share price. Ownership never guarantees a profit or a dividend.',
    limitations: 'These definitions explain ownership, not whether any asset is suitable for someone.',
    risk: 'Investments can lose value, including shares of familiar companies.',
    sourceTitle: 'Stocks',
    sourceUrl: 'https://www.investor.gov/introduction-investing/investing-basics/investment-products/stocks',
  ),
  'hall-v1': _StoryNotes(
    body: 'A stock price moves because buyers and sellers keep changing what they are willing to pay. Earnings, company news, expectations, and the broader market mood can all shift that balance. A good company can still have a down day because the price reflects expectations about the future, not only what the company is doing today.',
    uncertainty: 'Most price moves have several causes, and a headline cannot tell you what the next move will be.',
    limitations: 'A quote is a moment in time. Prices and available shares can change before an order arrives.',
    risk: 'Fast or thin markets can have wider spreads and less predictable execution.',
    sourceTitle: 'How Stock Markets Work',
    sourceUrl: 'https://www.investor.gov/introduction-investing/investing-basics/how-stock-markets-work',
  ),
  'route-v1': _StoryNotes(
    body: 'Your broker is the app or service that sends an order to the market: you, then the broker, then the market. On a quote, the bid is the highest current buying price and the ask is the lowest current selling price. Their difference is the spread. If AAPL shows a \$199.98 bid and a \$200.02 ask, the spread is \$0.04. Regular U.S. stock-market hours are 9:30 a.m. to 4:00 p.m. ET, with premarket and after-hours sessions around them.',
    uncertainty: 'Outside regular hours, trading can be lighter and spreads can be wider. A displayed quote does not guarantee an execution price.',
    limitations: 'A quote is a moment in time. Prices and available shares can change before an order arrives.',
    risk: 'Fast or thin markets can have wider spreads and less predictable execution.',
    sourceTitle: 'Executing an Order',
    sourceUrl: 'https://www.investor.gov/introduction-investing/investing-basics/how-stock-markets-work/executing-order',
  ),
};
