// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_ritual_preview.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DailyRitualPreviewCWProxy {
  DailyRitualPreview art(ArtReference art);

  DailyRitualPreview date(DateTime date);

  DailyRitualPreview demo(DemoDisclosure demo);

  DailyRitualPreview ideaTeasers(List<PublicAssetTeaser> ideaTeasers);

  DailyRitualPreview interpretationExcerpt(String interpretationExcerpt);

  DailyRitualPreview marketLabel(String marketLabel);

  DailyRitualPreview mode(DailyRitualPreviewModeEnum mode);

  DailyRitualPreview title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DailyRitualPreview(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DailyRitualPreview(...).copyWith(id: 12, name: "My name")
  /// ````
  DailyRitualPreview call({
    ArtReference art,
    DateTime date,
    DemoDisclosure demo,
    List<PublicAssetTeaser> ideaTeasers,
    String interpretationExcerpt,
    String marketLabel,
    DailyRitualPreviewModeEnum mode,
    String title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDailyRitualPreview.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDailyRitualPreview.copyWith.fieldName(...)`
class _$DailyRitualPreviewCWProxyImpl implements _$DailyRitualPreviewCWProxy {
  const _$DailyRitualPreviewCWProxyImpl(this._value);

  final DailyRitualPreview _value;

  @override
  DailyRitualPreview art(ArtReference art) => this(art: art);

  @override
  DailyRitualPreview date(DateTime date) => this(date: date);

  @override
  DailyRitualPreview demo(DemoDisclosure demo) => this(demo: demo);

  @override
  DailyRitualPreview ideaTeasers(List<PublicAssetTeaser> ideaTeasers) =>
      this(ideaTeasers: ideaTeasers);

  @override
  DailyRitualPreview interpretationExcerpt(String interpretationExcerpt) =>
      this(interpretationExcerpt: interpretationExcerpt);

  @override
  DailyRitualPreview marketLabel(String marketLabel) =>
      this(marketLabel: marketLabel);

  @override
  DailyRitualPreview mode(DailyRitualPreviewModeEnum mode) => this(mode: mode);

  @override
  DailyRitualPreview title(String title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DailyRitualPreview(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DailyRitualPreview(...).copyWith(id: 12, name: "My name")
  /// ````
  DailyRitualPreview call({
    Object? art = const $CopyWithPlaceholder(),
    Object? date = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? ideaTeasers = const $CopyWithPlaceholder(),
    Object? interpretationExcerpt = const $CopyWithPlaceholder(),
    Object? marketLabel = const $CopyWithPlaceholder(),
    Object? mode = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return DailyRitualPreview(
      art: art == const $CopyWithPlaceholder()
          ? _value.art
          // ignore: cast_nullable_to_non_nullable
          : art as ArtReference,
      date: date == const $CopyWithPlaceholder()
          ? _value.date
          // ignore: cast_nullable_to_non_nullable
          : date as DateTime,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as DemoDisclosure,
      ideaTeasers: ideaTeasers == const $CopyWithPlaceholder()
          ? _value.ideaTeasers
          // ignore: cast_nullable_to_non_nullable
          : ideaTeasers as List<PublicAssetTeaser>,
      interpretationExcerpt:
          interpretationExcerpt == const $CopyWithPlaceholder()
          ? _value.interpretationExcerpt
          // ignore: cast_nullable_to_non_nullable
          : interpretationExcerpt as String,
      marketLabel: marketLabel == const $CopyWithPlaceholder()
          ? _value.marketLabel
          // ignore: cast_nullable_to_non_nullable
          : marketLabel as String,
      mode: mode == const $CopyWithPlaceholder()
          ? _value.mode
          // ignore: cast_nullable_to_non_nullable
          : mode as DailyRitualPreviewModeEnum,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
    );
  }
}

extension $DailyRitualPreviewCopyWith on DailyRitualPreview {
  /// Returns a callable class that can be used as follows: `instanceOfDailyRitualPreview.copyWith(...)` or like so:`instanceOfDailyRitualPreview.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DailyRitualPreviewCWProxy get copyWith =>
      _$DailyRitualPreviewCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DailyRitualPreview _$DailyRitualPreviewFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'DailyRitualPreview',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'art',
            'date',
            'demo',
            'idea_teasers',
            'interpretation_excerpt',
            'market_label',
            'mode',
            'title',
          ],
        );
        final val = DailyRitualPreview(
          art: $checkedConvert(
            'art',
            (v) => ArtReference.fromJson(v as Map<String, dynamic>),
          ),
          date: $checkedConvert('date', (v) => DateTime.parse(v as String)),
          demo: $checkedConvert(
            'demo',
            (v) => DemoDisclosure.fromJson(v as Map<String, dynamic>),
          ),
          ideaTeasers: $checkedConvert(
            'idea_teasers',
            (v) => (v as List<dynamic>)
                .map(
                  (e) => PublicAssetTeaser.fromJson(e as Map<String, dynamic>),
                )
                .toList(),
          ),
          interpretationExcerpt: $checkedConvert(
            'interpretation_excerpt',
            (v) => v as String,
          ),
          marketLabel: $checkedConvert('market_label', (v) => v as String),
          mode: $checkedConvert(
            'mode',
            (v) => $enumDecode(
              _$DailyRitualPreviewModeEnumEnumMap,
              v,
              unknownValue: DailyRitualPreviewModeEnum.unknownDefaultOpenApi,
            ),
          ),
          title: $checkedConvert('title', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'ideaTeasers': 'idea_teasers',
        'interpretationExcerpt': 'interpretation_excerpt',
        'marketLabel': 'market_label',
      },
    );

Map<String, dynamic> _$DailyRitualPreviewToJson(DailyRitualPreview instance) =>
    <String, dynamic>{
      'art': instance.art.toJson(),
      'date': instance.date.toIso8601String(),
      'demo': instance.demo.toJson(),
      'idea_teasers': instance.ideaTeasers.map((e) => e.toJson()).toList(),
      'interpretation_excerpt': instance.interpretationExcerpt,
      'market_label': instance.marketLabel,
      'mode': _$DailyRitualPreviewModeEnumEnumMap[instance.mode]!,
      'title': instance.title,
    };

const _$DailyRitualPreviewModeEnumEnumMap = {
  DailyRitualPreviewModeEnum.tarot: 'tarot',
  DailyRitualPreviewModeEnum.astrology: 'astrology',
  DailyRitualPreviewModeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
