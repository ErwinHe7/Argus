//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/public_asset_teaser.dart';
import 'package:ritual_investing_api_client/generated/model/art_reference.dart';
import 'package:ritual_investing_api_client/generated/model/demo_disclosure.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'daily_ritual_preview.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DailyRitualPreview {
  /// Returns a new [DailyRitualPreview] instance.
  DailyRitualPreview({
    required this.art,

    required this.date,

    required this.demo,

    required this.ideaTeasers,

    required this.interpretationExcerpt,

    required this.marketLabel,

    required this.mode,

    required this.title,
  });

  @JsonKey(name: r'art', required: true, includeIfNull: false)
  final ArtReference art;

  @JsonKey(name: r'date', required: true, includeIfNull: false)
  final DateTime date;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final DemoDisclosure demo;

  @JsonKey(name: r'idea_teasers', required: true, includeIfNull: false)
  final List<PublicAssetTeaser> ideaTeasers;

  @JsonKey(
    name: r'interpretation_excerpt',
    required: true,
    includeIfNull: false,
  )
  final String interpretationExcerpt;

  @JsonKey(name: r'market_label', required: true, includeIfNull: false)
  final String marketLabel;

  @JsonKey(
    name: r'mode',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DailyRitualPreviewModeEnum.unknownDefaultOpenApi,
  )
  final DailyRitualPreviewModeEnum mode;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyRitualPreview &&
          other.art == art &&
          other.date == date &&
          other.demo == demo &&
          other.ideaTeasers == ideaTeasers &&
          other.interpretationExcerpt == interpretationExcerpt &&
          other.marketLabel == marketLabel &&
          other.mode == mode &&
          other.title == title;

  @override
  int get hashCode =>
      art.hashCode +
      date.hashCode +
      demo.hashCode +
      ideaTeasers.hashCode +
      interpretationExcerpt.hashCode +
      marketLabel.hashCode +
      mode.hashCode +
      title.hashCode;

  factory DailyRitualPreview.fromJson(Map<String, dynamic> json) =>
      _$DailyRitualPreviewFromJson(json);

  Map<String, dynamic> toJson() => _$DailyRitualPreviewToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum DailyRitualPreviewModeEnum {
  @JsonValue(r'tarot')
  tarot(r'tarot'),
  @JsonValue(r'astrology')
  astrology(r'astrology'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DailyRitualPreviewModeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
