//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/admin_me.dart';
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'get_admin_me200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class GetAdminMe200Response {
  /// Returns a new [GetAdminMe200Response] instance.
  GetAdminMe200Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final AdminMe data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GetAdminMe200Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory GetAdminMe200Response.fromJson(Map<String, dynamic> json) =>
      _$GetAdminMe200ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GetAdminMe200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
