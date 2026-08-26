//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_admin_asset_codex200_response_data_inner_revision_payload_any_of6_sections_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner {
  /// Returns a new [ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner] instance.
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner({
    required this.body,

    required this.heading,

    required this.sectionType,
  });

  @JsonKey(name: r'body', required: true, includeIfNull: false)
  final String body;

  @JsonKey(name: r'heading', required: true, includeIfNull: false)
  final String heading;

  @JsonKey(name: r'section_type', required: true, includeIfNull: false)
  final String sectionType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other
              is ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner &&
          other.body == body &&
          other.heading == heading &&
          other.sectionType == sectionType;

  @override
  int get hashCode => body.hashCode + heading.hashCode + sectionType.hashCode;

  factory ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInnerFromJson(
        json,
      );

  Map<String, dynamic> toJson() =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInnerToJson(
        this,
      );

  @override
  String toString() {
    return toJson().toString();
  }
}
