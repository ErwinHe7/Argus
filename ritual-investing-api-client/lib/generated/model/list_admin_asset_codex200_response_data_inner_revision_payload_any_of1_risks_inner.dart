//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_admin_asset_codex200_response_data_inner_revision_payload_any_of1_risks_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner {
  /// Returns a new [ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner] instance.
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner({
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
        ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerSeverityEnum
            .unknownDefaultOpenApi,
  )
  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerSeverityEnum
  severity;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner &&
          other.detail == detail &&
          other.severity == severity &&
          other.title == title;

  @override
  int get hashCode => detail.hashCode + severity.hashCode + title.hashCode;

  factory ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerFromJson(
        json,
      );

  Map<String, dynamic> toJson() =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerToJson(
        this,
      );

  @override
  String toString() {
    return toJson().toString();
  }
}

enum ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerSeverityEnum {
  @JsonValue(r'low')
  low(r'low'),
  @JsonValue(r'medium')
  medium(r'medium'),
  @JsonValue(r'high')
  high(r'high'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerSeverityEnum(
    this.value,
  );

  final String value;

  @override
  String toString() => value;
}
