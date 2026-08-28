//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_admin_audit200_response_meta.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListAdminAudit200ResponseMeta {
  /// Returns a new [ListAdminAudit200ResponseMeta] instance.
  ListAdminAudit200ResponseMeta({required this.requestId});

  @JsonKey(name: r'request_id', required: true, includeIfNull: false)
  final String requestId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListAdminAudit200ResponseMeta && other.requestId == requestId;

  @override
  int get hashCode => requestId.hashCode;

  factory ListAdminAudit200ResponseMeta.fromJson(Map<String, dynamic> json) =>
      _$ListAdminAudit200ResponseMetaFromJson(json);

  Map<String, dynamic> toJson() => _$ListAdminAudit200ResponseMetaToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
