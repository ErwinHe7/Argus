//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_admin_asset_codex200_response_data_inner_revision.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListAdminAssetCodex200ResponseDataInnerRevision {
  /// Returns a new [ListAdminAssetCodex200ResponseDataInnerRevision] instance.
  ListAdminAssetCodex200ResponseDataInnerRevision({
    required this.authorStaffId,

    required this.etag,

    required this.id,

    required this.payload,

    required this.revisionNumber,

    required this.state,

    required this.version,
  });

  @JsonKey(name: r'author_staff_id', required: true, includeIfNull: false)
  final String authorStaffId;

  @JsonKey(name: r'etag', required: true, includeIfNull: false)
  final String etag;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'payload', required: true, includeIfNull: false)
  final ListAdminAssetCodex200ResponseDataInnerRevisionPayload payload;

  // minimum: 0
  @JsonKey(name: r'revision_number', required: true, includeIfNull: false)
  final int revisionNumber;

  @JsonKey(
    name: r'state',
    required: true,
    includeIfNull: false,
    unknownEnumValue: ListAdminAssetCodex200ResponseDataInnerRevisionStateEnum
        .unknownDefaultOpenApi,
  )
  final ListAdminAssetCodex200ResponseDataInnerRevisionStateEnum state;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListAdminAssetCodex200ResponseDataInnerRevision &&
          other.authorStaffId == authorStaffId &&
          other.etag == etag &&
          other.id == id &&
          other.payload == payload &&
          other.revisionNumber == revisionNumber &&
          other.state == state &&
          other.version == version;

  @override
  int get hashCode =>
      authorStaffId.hashCode +
      etag.hashCode +
      id.hashCode +
      payload.hashCode +
      revisionNumber.hashCode +
      state.hashCode +
      version.hashCode;

  factory ListAdminAssetCodex200ResponseDataInnerRevision.fromJson(
    Map<String, dynamic> json,
  ) => _$ListAdminAssetCodex200ResponseDataInnerRevisionFromJson(json);

  Map<String, dynamic> toJson() =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum ListAdminAssetCodex200ResponseDataInnerRevisionStateEnum {
  @JsonValue(r'draft')
  draft(r'draft'),
  @JsonValue(r'in_review')
  inReview(r'in_review'),
  @JsonValue(r'approved')
  approved(r'approved'),
  @JsonValue(r'changes_requested')
  changesRequested(r'changes_requested'),
  @JsonValue(r'rejected')
  rejected(r'rejected'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ListAdminAssetCodex200ResponseDataInnerRevisionStateEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
