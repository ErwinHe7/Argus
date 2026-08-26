import '../domain/daily_ritual.dart';

class RitualTarotArtwork {
  const RitualTarotArtwork({
    required this.key,
    required this.title,
    required this.assetPath,
    required this.alt,
  });

  final String key;
  final String title;
  final String assetPath;
  final String alt;
}

const majorArcanaArtwork = <RitualTarotArtwork>[
  RitualTarotArtwork(
    key: 'the_fool',
    title: 'The Fool',
    assetPath: 'assets/images/tarot/modern-rider-waite/major/00-the-fool.webp',
    alt: 'The Fool tarot card: a traveler approaches a cliff with a white dog',
  ),
  RitualTarotArtwork(
    key: 'the_magician',
    title: 'The Magician',
    assetPath:
        'assets/images/tarot/modern-rider-waite/major/01-the-magician.webp',
    alt: 'The Magician tarot card: a creator raises a wand above an elemental table',
  ),
  RitualTarotArtwork(
    key: 'the_high_priestess',
    title: 'The High Priestess',
    assetPath: 'assets/images/tarot/modern-rider-waite/major/02-the-high-priestess.webp',
    alt: 'The High Priestess tarot card: a guardian sits between dark and light pillars',
  ),
  RitualTarotArtwork(
    key: 'the_empress',
    title: 'The Empress',
    assetPath:
        'assets/images/tarot/modern-rider-waite/major/03-the-empress.webp',
    alt: 'The Empress tarot card: a crowned figure sits among grain, forest, and flowing water',
  ),
  RitualTarotArtwork(
    key: 'the_emperor',
    title: 'The Emperor',
    assetPath:
        'assets/images/tarot/modern-rider-waite/major/04-the-emperor.webp',
    alt: 'The Emperor tarot card: a ruler sits on a ram-carved throne before mountains',
  ),
  RitualTarotArtwork(
    key: 'the_hierophant',
    title: 'The Hierophant',
    assetPath:
        'assets/images/tarot/modern-rider-waite/major/05-the-hierophant.webp',
    alt: 'The Hierophant tarot card: a mentor blesses two learners above crossed keys',
  ),
  RitualTarotArtwork(
    key: 'the_lovers',
    title: 'The Lovers',
    assetPath:
        'assets/images/tarot/modern-rider-waite/major/06-the-lovers.webp',
    alt: 'The Lovers tarot card: two partners stand beneath a radiant angel',
  ),
  RitualTarotArtwork(
    key: 'the_chariot',
    title: 'The Chariot',
    assetPath:
        'assets/images/tarot/modern-rider-waite/major/07-the-chariot.webp',
    alt: 'The Chariot tarot card: an armored navigator stands with black and white sphinxes',
  ),
  RitualTarotArtwork(
    key: 'strength',
    title: 'Strength',
    assetPath: 'assets/images/tarot/modern-rider-waite/major/08-strength.webp',
    alt: 'Strength tarot card: a calm woman gently holds a golden lion',
  ),
  RitualTarotArtwork(
    key: 'the_hermit',
    title: 'The Hermit',
    assetPath:
        'assets/images/tarot/modern-rider-waite/major/09-the-hermit.webp',
    alt: 'The Hermit tarot card: an elder holds a star lantern on a snowy mountain',
  ),
  RitualTarotArtwork(
    key: 'wheel_of_fortune',
    title: 'Wheel of Fortune',
    assetPath:
        'assets/images/tarot/modern-rider-waite/major/10-wheel-of-fortune.webp',
    alt: 'Wheel of Fortune tarot card: a symbolic wheel turns among winged creatures',
  ),
  RitualTarotArtwork(
    key: 'justice',
    title: 'Justice',
    assetPath: 'assets/images/tarot/modern-rider-waite/major/11-justice.webp',
    alt:
        'Justice tarot card: a crowned judge holds a sword and balanced scales',
  ),
  RitualTarotArtwork(
    key: 'the_hanged_man',
    title: 'The Hanged Man',
    assetPath:
        'assets/images/tarot/modern-rider-waite/major/12-the-hanged-man.webp',
    alt: 'The Hanged Man tarot card: a peaceful figure hangs upside down from a living tree',
  ),
  RitualTarotArtwork(
    key: 'death',
    title: 'Death',
    assetPath: 'assets/images/tarot/modern-rider-waite/major/13-death.webp',
    alt: 'Death tarot card: a skeletal rider advances on a white horse at sunrise',
  ),
  RitualTarotArtwork(
    key: 'temperance',
    title: 'Temperance',
    assetPath:
        'assets/images/tarot/modern-rider-waite/major/14-temperance.webp',
    alt: 'Temperance tarot card: an angel pours water between two cups',
  ),
  RitualTarotArtwork(
    key: 'the_devil',
    title: 'The Devil',
    assetPath: 'assets/images/tarot/modern-rider-waite/major/15-the-devil.webp',
    alt: 'The Devil tarot card: a chained pair stands before a horned winged figure',
  ),
  RitualTarotArtwork(
    key: 'the_tower',
    title: 'The Tower',
    assetPath: 'assets/images/tarot/modern-rider-waite/major/16-the-tower.webp',
    alt: 'The Tower tarot card: lightning shatters a crowned tower',
  ),
  RitualTarotArtwork(
    key: 'the_star',
    title: 'The Star',
    assetPath: 'assets/images/tarot/modern-rider-waite/major/17-the-star.webp',
    alt: 'The Star tarot card: a woman pours water beneath eight stars',
  ),
  RitualTarotArtwork(
    key: 'the_moon',
    title: 'The Moon',
    assetPath: 'assets/images/tarot/modern-rider-waite/major/18-the-moon.webp',
    alt: 'The Moon tarot card: a wolf and dog face the moon between two towers',
  ),
  RitualTarotArtwork(
    key: 'the_sun',
    title: 'The Sun',
    assetPath: 'assets/images/tarot/modern-rider-waite/major/19-the-sun.webp',
    alt: 'The Sun tarot card: a joyful child rides beneath a radiant sun',
  ),
  RitualTarotArtwork(
    key: 'judgement',
    title: 'Judgement',
    assetPath: 'assets/images/tarot/modern-rider-waite/major/20-judgement.webp',
    alt: 'Judgement tarot card: an angel sounds a trumpet as people rise',
  ),
  RitualTarotArtwork(
    key: 'the_world',
    title: 'The World',
    assetPath: 'assets/images/tarot/modern-rider-waite/major/21-the-world.webp',
    alt: 'The World tarot card: a dancer floats within a laurel wreath',
  ),
];

final Map<String, RitualTarotArtwork> _majorArcanaArtworkByKey =
    Map.unmodifiable({
      for (final artwork in majorArcanaArtwork) artwork.key: artwork,
    });

RitualTarotArtwork? resolveRitualTarotArtwork({
  required RitualArt art,
  required DateTime date,
  required DailyRitualMode mode,
}) {
  if (mode != DailyRitualMode.tarot) return null;

  final explicitlyAssigned = _majorArcanaArtworkByKey[art.key];
  if (explicitlyAssigned != null) return explicitlyAssigned;
  if (art.key != 'the_compass') return null;

  final calendarDate = DateTime.utc(date.year, date.month, date.day);
  final dayNumber = calendarDate.difference(DateTime.utc(2000)).inDays;
  final index = dayNumber % majorArcanaArtwork.length;
  return majorArcanaArtwork[index];
}
