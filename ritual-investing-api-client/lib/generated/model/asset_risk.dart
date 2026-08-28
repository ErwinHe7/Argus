//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'asset_risk.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AssetRisk {
  /// Returns a new [AssetRisk] instance.
  AssetRisk({
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
    unknownEnumValue: AssetRiskSeverityEnum.unknownDefaultOpenApi,
  )
  final AssetRiskSeverityEnum severity;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetRisk &&
          other.detail == detail &&
          other.severity == severity &&
          other.title == title;

  @override
  int get hashCode => detail.hashCode + severity.hashCode + title.hashCode;

  factory AssetRisk.fromJson(Map<String, dynamic> json) =>
      _$AssetRiskFromJson(json);

  Map<String, dynamic> toJson() => _$AssetRiskToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum AssetRiskSeverityEnum {
  @JsonValue(r'low')
  low(r'low'),
  @JsonValue(r'medium')
  medium(r'medium'),
  @JsonValue(r'high')
  high(r'high'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AssetRiskSeverityEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
