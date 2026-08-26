//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'asset_codex_detail_risks_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AssetCodexDetailRisksInner {
  /// Returns a new [AssetCodexDetailRisksInner] instance.
  AssetCodexDetailRisksInner({
    required this.detail,

    required this.severity,

    required this.title,
  });

  @JsonKey(name: r'detail', required: true, includeIfNull: false)
  final String detail;

  @JsonKey(
    name: r'severity',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        AssetCodexDetailRisksInnerSeverityEnum.unknownDefaultOpenApi,
  )
  final AssetCodexDetailRisksInnerSeverityEnum severity;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetCodexDetailRisksInner &&
          other.detail == detail &&
          other.severity == severity &&
          other.title == title;

  @override
  int get hashCode => detail.hashCode + severity.hashCode + title.hashCode;

  factory AssetCodexDetailRisksInner.fromJson(Map<String, dynamic> json) =>
      _$AssetCodexDetailRisksInnerFromJson(json);

  Map<String, dynamic> toJson() => _$AssetCodexDetailRisksInnerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum AssetCodexDetailRisksInnerSeverityEnum {
  @JsonValue(r'low')
  low(r'low'),
  @JsonValue(r'medium')
  medium(r'medium'),
  @JsonValue(r'high')
  high(r'high'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AssetCodexDetailRisksInnerSeverityEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
