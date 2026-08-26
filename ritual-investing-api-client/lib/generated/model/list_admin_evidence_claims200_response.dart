//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/collection_meta.dart';
import 'package:ritual_investing_api_client/generated/model/admin_evidence_claim.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_admin_evidence_claims200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListAdminEvidenceClaims200Response {
  /// Returns a new [ListAdminEvidenceClaims200Response] instance.
  ListAdminEvidenceClaims200Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final List<AdminEvidenceClaim> data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final CollectionMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListAdminEvidenceClaims200Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory ListAdminEvidenceClaims200Response.fromJson(
    Map<String, dynamic> json,
  ) => _$ListAdminEvidenceClaims200ResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$ListAdminEvidenceClaims200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
