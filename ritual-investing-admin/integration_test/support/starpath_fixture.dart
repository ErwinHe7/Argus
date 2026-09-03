Map<String, Object?> starpathLessonFixture() => {
  'stable_key': 'share-sigil',
  'pathway_ordinal': 1,
  'pathway_position': 1,
  'policy_version': 'starpath-no-advice-v1',
  'classification': 'education_general',
  'title': 'The Share Sigil',
  'tarot_key': 'the-magician',
  'tarot_accessible_label': 'The Magician as a memory aid',
  'mythic_mnemonic': 'A sigil can help you remember that one share is one unit of ownership; it predicts nothing.',
  'factual_summary':
      'A share of common stock represents an ownership interest in a company.',
  'material_limitations':
      'Ownership does not guarantee dividends, voting power, or a gain.',
  'risk_context': 'A share price can fall and an investor can lose money.',
  'recall_prompt': 'What does one share represent?',
  'rowan_explanation': 'Think of a share as a documented unit of ownership, not a promise of profit.',
  'sections': [
    {
      'kind': 'fact',
      'heading': 'What a share records',
      'body': 'Companies may issue shares, and existing shares may later trade between market participants.',
      'uncertainty': 'Rights differ by security class and issuer documents.',
      'observed_at': '2026-08-30T00:00:00.000Z',
      'evidence': [
        {
          'canonical_url': 'https://www.investor.gov/introduction-investing/investing-basics/investment-products/stocks',
          'source_title': 'Stocks',
          'publisher': 'SEC',
          'source_observed_at': '2026-08-30T00:00:00.000Z',
          'effective_at': null,
          'retrieved_at': '2026-08-30T00:00:00.000Z',
          'current_until': '2026-11-30T00:00:00.000Z',
          'claim_summary': 'Defines stocks as an ownership interest and describes common rights.',
        },
      ],
    },
  ],
  'check': {
    'prompt': 'Which statement describes a share of common stock?',
    'explanation':
        'A share is an ownership interest; it is not a guaranteed return.',
    'options': [
      {
        'label': 'It is an ownership interest in a company.',
        'is_correct': true,
        'explanation': 'Correct.',
      },
      {
        'label': 'It guarantees a dividend and a gain.',
        'is_correct': false,
        'explanation': 'Neither dividends nor gains are guaranteed.',
      },
    ],
  },
};
