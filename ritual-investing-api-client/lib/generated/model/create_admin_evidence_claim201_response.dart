//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/admin_evidence_claim.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_admin_evidence_claim201_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateAdminEvidenceClaim201Response {
  /// Returns a new [CreateAdminEvidenceClaim201Response] instance.
  CreateAdminEvidenceClaim201Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final AdminEvidenceClaim data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateAdminEvidenceClaim201Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory CreateAdminEvidenceClaim201Response.fromJson(
    Map<String, dynamic> json,
  ) => _$CreateAdminEvidenceClaim201ResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateAdminEvidenceClaim201ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
