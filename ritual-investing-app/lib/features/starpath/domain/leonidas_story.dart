import 'investment_constellation.dart';
import 'starpath.dart';

enum StoryExpression { warm, playful, analytical, concerned }

enum StoryInteraction { dialogue, inspect, sequence, choice }

class StoryOption {
  const StoryOption(this.label, this.response, {this.correct = false});
  final String label;
  final String response;
  final bool correct;
}

class StoryBeat {
  const StoryBeat(
    this.id,
    this.line, {
    this.expression = StoryExpression.warm,
    this.interaction = StoryInteraction.dialogue,
    this.options = const [],
  });
  final String id;
  final String line;
  final StoryExpression expression;
  final StoryInteraction interaction;
  final List<StoryOption> options;
}

class LeonidasStory {
  const LeonidasStory({
    required this.id,
    required this.title,
    required this.setting,
    required this.lessonTitle,
    required this.beats,
  });
  final String id;
  final String title;
  final String setting;
  final String lessonTitle;
  final List<StoryBeat> beats;
}

/// Pilot bindings are deliberately limited to the local preview's immutable
/// identities. A hosted revision must be reviewed and explicitly registered.
LeonidasStory? resolveLeonidasStory(
  StarpathSnapshot snapshot,
  InvestmentLessonEntry entry,
) {
  if (snapshot.authority.manifestId != 'fixture-manifest' ||
      snapshot.authority.manifestVersion != 'fixture-v1') {
    return null;
  }
  final node = entry.node;
  final key = (node.lessonId, node.revisionId, entry.section.ordinal);
  final index = switch (key) {
    ('fixture-lesson-1', 'fixture-revision-1', 1) => 0,
    ('fixture-lesson-1', 'fixture-revision-1', 2) => 1,
    ('fixture-lesson-2', 'fixture-revision-2', 1) => 2,
    ('fixture-lesson-2', 'fixture-revision-2', 2) => 3,
    _ => null,
  };
  if (index == null) return null;
  final story = leonidasStories[index];
  // Also reject accidental preview content drift under a reused fixture ID.
  return entry.section.heading == story.lessonTitle ? story : null;
}

const leonidasStories = <LeonidasStory>[
  LeonidasStory(
    id: 'garden-v1',
    title: 'The Unfinished Garden',
    setting: 'Observatory courtyard',
    lessonTitle: 'What Is Investing?',
    beats: [
      StoryBeat(
        'arrival',
        'The observatory’s market atlas has four unfinished pages. Help me restore the first? We begin here, in a garden that exists only on paper.',
      ),
      StoryBeat(
        'plans',
        'Before we plant anything, what are we hoping this will become? The same starting capital can come with very different intentions.',
        expression: StoryExpression.playful,
      ),
      StoryBeat(
        'intentions',
        'Open both notes on the garden plan. Look for what each person hopes to gain, and when.',
        interaction: StoryInteraction.inspect,
        options: [
          StoryOption(
            'Keep and cultivate',
            '“I want to own this asset for the value it might create over time.” That is an investing intention. Time creates possibilities, not certainty.',
          ),
          StoryOption(
            'Sell after a price move',
            '“I want to sell if its price moves in the short term.” That is a trading intention. The hoped-for move may never arrive.',
          ),
        ],
      ),
      StoryBeat(
        'choose-intent',
        'Someone wants to own the garden for what it may produce over several years. Which intention does that describe?',
        interaction: StoryInteraction.choice,
        options: [
          StoryOption(
            'Investing over time',
            'Yes. The intention centers on ownership and possible value over time. We still need to leave room for loss.',
            correct: true,
          ),
          StoryOption(
            'A short-term price trade',
            'That would focus on a shorter-term change in price. Here, the gardener wants to keep the asset for what it may produce. Try again.',
          ),
        ],
      ),
      StoryBeat(
        'weather',
        'Even a carefully tended garden can face poor weather. Our garden is a memory aid: an investment can also disappoint or lose value.',
        expression: StoryExpression.concerned,
      ),
      StoryBeat(
        'boundary',
        'Investing and trading are not separated by a magic number of days. Purpose and time horizon help us understand the difference.',
        expression: StoryExpression.analytical,
      ),
      StoryBeat(
        'promise',
        'The plan says, “This garden will be worth more later.” What would you change?',
        interaction: StoryInteraction.choice,
        options: [
          StoryOption(
            'Say it may create value; it could lose value',
            'Exactly. An expectation gives us a reason to investigate. It is not a promise from the future.',
            correct: true,
          ),
          StoryOption(
            'Keep “will”; patience guarantees it',
            'Patience does not guarantee a gain. Longer ownership can still end in a loss. Let’s make the uncertainty visible.',
          ),
        ],
      ),
      StoryBeat(
        'recap',
        'Our first page is restored: investing puts capital into an asset for possible value over time. Trading focuses on shorter-term price moves. Both involve risk.',
      ),
      StoryBeat(
        'close',
        'Keep that distinction with you. At the archive desk, there is a seal waiting for us—and a better question than “Will it rise?”: “What do I own?”',
        expression: StoryExpression.playful,
      ),
    ],
  ),
  LeonidasStory(
    id: 'seal-v1',
    title: 'The Ownership Seal',
    setting: 'The archive desk',
    lessonTitle: 'What Is a Stock?',
    beats: [
      StoryBeat(
        'arrival',
        'The second atlas page holds a company certificate. Our fictional company is called Lantern Works. A handsome seal—but let’s read past the decoration.',
        expression: StoryExpression.playful,
      ),
      StoryBeat(
        'certificate',
        'A symbol can name something. It cannot tell us everything about what we own. Inspect the three labels on this practice certificate.',
        interaction: StoryInteraction.inspect,
        options: [
          StoryOption(
            'Company · Lantern Works',
            'The company is the business whose ownership is divided into shares. Lantern Works is fictional.',
          ),
          StoryOption(
            'Share · one ownership unit',
            'One share represents a small ownership interest. Exact rights depend on the security class and issuer documents.',
          ),
          StoryOption(
            'Ticker · LANT (fictional)',
            'A ticker is a short identifier. It is not a quality rating or a promise of profit.',
          ),
        ],
      ),
      StoryBeat(
        'ownership',
        'What does this common share represent?',
        interaction: StoryInteraction.choice,
        options: [
          StoryOption(
            'An ownership interest in the company',
            'Yes. You would be a shareholder. The documents explain the specific rights attached to that share.',
            correct: true,
          ),
          StoryOption(
            'A loan the company must repay with interest',
            'That describes a debt idea, not common-stock ownership. A common share does not promise repayment with interest.',
          ),
          StoryOption(
            'An entitlement to guaranteed income',
            'A common share does not guarantee income. Dividends are not promised simply because someone owns a share.',
          ),
        ],
      ),
      StoryBeat(
        'rights',
        'Some common shares carry voting rights or may receive dividends. We check the issue’s terms; we do not invent rights from a familiar name.',
        expression: StoryExpression.analytical,
      ),
      StoryBeat(
        'familiar',
        'You may recognize a company and still see its share price fall. Familiarity is not protection from loss.',
        expression: StoryExpression.concerned,
      ),
      StoryBeat(
        'label',
        'The ticker belongs on the certificate as an identifier. The uncertainty belongs beside it, just as visibly.',
      ),
      StoryBeat(
        'guarantee',
        'Which note should we attach to the ownership seal?',
        interaction: StoryInteraction.choice,
        options: [
          StoryOption(
            'Ownership; no guaranteed gain or dividend',
            'That is the honest label. We know the kind of claim, and we keep its limits in view.',
            correct: true,
          ),
          StoryOption(
            'Recognizable ticker; dependable profit',
            'A recognizable ticker does not establish future profit. Let’s separate identification from an outcome.',
          ),
        ],
      ),
      StoryBeat(
        'recap',
        'A stock is ownership in a company. A share is a unit of it. A ticker identifies it. None of those words promises a dividend or a rising price.',
      ),
      StoryBeat(
        'close',
        'The seal is readable now. You can revisit the lesson notes or open the existing knowledge check. Beyond the archive, the market hall is beginning to murmur.',
      ),
    ],
  ),
  LeonidasStory(
    id: 'hall-v1',
    title: 'The Murmuring Hall',
    setting: 'The market hall',
    lessonTitle: 'Why Do Prices Move?',
    beats: [
      StoryBeat(
        'arrival',
        'Our third atlas page listens to the market hall. These are fictional voices, not live prices. Each participant is reconsidering what they are willing to pay.',
      ),
      StoryBeat(
        'voices',
        'Listen to all three voices. Notice how the same company can sit inside different expectations.',
        interaction: StoryInteraction.inspect,
        options: [
          StoryOption(
            'The company report',
            '“The company reported stronger sales, so I am reconsidering my buying price.” Company information can change expectations.',
          ),
          StoryOption(
            'The cautious buyer',
            '“I expected even stronger results. I am less willing to pay the earlier price.” Good news can still fall short of expectations.',
          ),
          StoryOption(
            'The broader market',
            '“Conditions beyond this company concern me. I am changing what I am willing to pay.” Broader market conditions can matter too.',
          ),
        ],
      ),
      StoryBeat(
        'balance',
        'What is changing across those voices?',
        interaction: StoryInteraction.choice,
        options: [
          StoryOption(
            'What buyers and sellers are willing to pay or accept',
            'Yes. Changing willingness and expectations help explain why prices move. No single voice describes the whole market.',
            correct: true,
          ),
          StoryOption(
            'A fixed price assigned to every good company',
            'There is no fixed market price for being a good company. Participants can disagree and revise their prices.',
          ),
        ],
      ),
      StoryBeat(
        'expectations',
        'The company has not vanished. The expectations around it have shifted. Business performance and share-price movement are related, but they are not the same thing.',
        expression: StoryExpression.analytical,
      ),
      StoryBeat(
        'causes',
        'Most moves can have several influences: earnings, news, expectations, and broader conditions. A tidy story may leave something out.',
      ),
      StoryBeat(
        'headline',
        'A messenger brings one cheerful headline. It tells us something to examine. It does not show us tomorrow.',
        expression: StoryExpression.playful,
      ),
      StoryBeat(
        'prediction',
        'Can that headline prove which way the price moves next?',
        interaction: StoryInteraction.choice,
        options: [
          StoryOption(
            'No; expectations and other influences remain uncertain',
            'Exactly. We can explain possible influences without pretending to know the next move.',
            correct: true,
          ),
          StoryOption(
            'Yes; cheerful news means the price must rise',
            'The news may already be expected, or other influences may matter more. A headline cannot guarantee the next direction.',
          ),
        ],
      ),
      StoryBeat(
        'recap',
        'Prices move as participants change what they are willing to pay or accept. Several influences may act together. A good company can still have a down day.',
      ),
      StoryBeat(
        'close',
        'The third page records questions, not prophecies. Now let’s follow how a practice instruction travels from a person to the market.',
      ),
    ],
  ),
  LeonidasStory(
    id: 'route-v1',
    title: 'The Lantern Route',
    setting: 'The observatory map room',
    lessonTitle: 'How the Market Works',
    beats: [
      StoryBeat(
        'arrival',
        'The last unfinished page is a route. We will trace a practice instruction across this miniature map. Nothing here submits an order.',
      ),
      StoryBeat(
        'route',
        'Light the stops in order: the learner, then the broker, then the market.',
        interaction: StoryInteraction.sequence,
        options: [
          StoryOption(
            'Learner',
            'First, the person specifies an instruction. In this activity, it stays entirely fictional.',
          ),
          StoryOption(
            'Broker',
            'Next, the broker is the service that sends the order toward the market.',
          ),
          StoryOption(
            'Market',
            'Then the instruction reaches the market. Sending it does not promise a particular execution result.',
          ),
        ],
      ),
      StoryBeat(
        'broker',
        'Which role belongs to the broker?',
        interaction: StoryInteraction.choice,
        options: [
          StoryOption(
            'Send the person’s order toward the market',
            'Yes. It is a service in the route. Its presence does not remove market risk or guarantee an execution price.',
            correct: true,
          ),
          StoryOption(
            'Guarantee a profitable result',
            'A broker does not guarantee profit. Its role here is to send the order toward the market.',
          ),
        ],
      ),
      StoryBeat(
        'quote',
        'Inspect each field on this fictional quote. These are fixed teaching values, not a live market feed.',
        expression: StoryExpression.analytical,
        interaction: StoryInteraction.inspect,
        options: [
          StoryOption(
            r'Bid · $199.98',
            'The bid is the highest current buying price on this example quote.',
          ),
          StoryOption(
            r'Ask · $200.02',
            'The ask is the lowest current selling price on this example quote.',
          ),
          StoryOption(
            r'Spread · $0.04',
            'The spread is the difference between those quoted buying and selling prices.',
          ),
        ],
      ),
      StoryBeat(
        'moment',
        'A quote is a moment in time. Prices and available shares can change before an instruction arrives.',
        expression: StoryExpression.concerned,
      ),
      StoryBeat(
        'sessions',
        'Trading outside regular sessions can be lighter, and spreads can be wider. The lesson notes keep the session context beside the source.',
      ),
      StoryBeat(
        'execution',
        'Does this displayed quote guarantee the eventual execution price?',
        interaction: StoryInteraction.choice,
        options: [
          StoryOption(
            'No; conditions may change before execution',
            'That is the distinction. A quoted price and an eventual execution price are not the same promise.',
            correct: true,
          ),
          StoryOption(
            'Yes; the displayed number must be honored',
            'The display is not an execution guarantee. Prices and available quantities can change. Try that distinction once more.',
          ),
        ],
      ),
      StoryBeat(
        'recap',
        'Learner, broker, market. Bid, ask, spread. You can now name the route and read the quote without mistaking it for a guaranteed result.',
      ),
      StoryBeat(
        'close',
        'Four pages, restored together. You have named an intention, an ownership claim, changing expectations, and a market route. The atlas is ready for another visit whenever you are.',
        expression: StoryExpression.playful,
      ),
    ],
  ),
];
