//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/starpath_snapshot.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_audit200_response_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'starpath_snapshot_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StarpathSnapshotResponse {
  /// Returns a new [StarpathSnapshotResponse] instance.
  StarpathSnapshotResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final StarpathSnapshot data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ListAdminAudit200ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StarpathSnapshotResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory StarpathSnapshotResponse.fromJson(Map<String, dynamic> json) =>
      _$StarpathSnapshotResponseFromJson(json);

  Map<String, dynamic> toJson() => _$StarpathSnapshotResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
