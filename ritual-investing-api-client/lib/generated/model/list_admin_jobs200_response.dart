//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_jobs200_response_data_inner.dart';
import 'package:ritual_investing_api_client/generated/model/collection_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_admin_jobs200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListAdminJobs200Response {
  /// Returns a new [ListAdminJobs200Response] instance.
  ListAdminJobs200Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final List<ListAdminJobs200ResponseDataInner> data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final CollectionMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListAdminJobs200Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory ListAdminJobs200Response.fromJson(Map<String, dynamic> json) =>
      _$ListAdminJobs200ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ListAdminJobs200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
