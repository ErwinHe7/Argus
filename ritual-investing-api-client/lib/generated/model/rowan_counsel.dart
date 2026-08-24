//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rowan_counsel.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RowanCounsel {
  /// Returns a new [RowanCounsel] instance.
  RowanCounsel({
    required this.body,

    required this.riskFooter,

    required this.scriptRevisionId,

    required this.surface,
  });

  @JsonKey(name: r'body', required: true, includeIfNull: false)
  final String body;

  @JsonKey(name: r'risk_footer', required: true, includeIfNull: false)
  final String riskFooter;

  @JsonKey(name: r'script_revision_id', required: true, includeIfNull: false)
  final String scriptRevisionId;

  @JsonKey(
    name: r'surface',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RowanCounselSurfaceEnum.unknownDefaultOpenApi,
  )
  final RowanCounselSurfaceEnum surface;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RowanCounsel &&
          other.body == body &&
          other.riskFooter == riskFooter &&
          other.scriptRevisionId == scriptRevisionId &&
          other.surface == surface;

  @override
  int get hashCode =>
      body.hashCode +
      riskFooter.hashCode +
      scriptRevisionId.hashCode +
      surface.hashCode;

  factory RowanCounsel.fromJson(Map<String, dynamic> json) =>
      _$RowanCounselFromJson(json);

  Map<String, dynamic> toJson() => _$RowanCounselToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum RowanCounselSurfaceEnum {
  @JsonValue(r'daily_ritual')
  dailyRitual(r'daily_ritual'),
  @JsonValue(r'evidence')
  evidence(r'evidence'),
  @JsonValue(r'asset_codex')
  assetCodex(r'asset_codex'),
  @JsonValue(r'coven')
  coven(r'coven'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RowanCounselSurfaceEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
