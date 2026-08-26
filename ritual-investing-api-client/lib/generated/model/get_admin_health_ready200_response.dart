//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/admin_health.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'get_admin_health_ready200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class GetAdminHealthReady200Response {
  /// Returns a new [GetAdminHealthReady200Response] instance.
  GetAdminHealthReady200Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final AdminHealth data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GetAdminHealthReady200Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory GetAdminHealthReady200Response.fromJson(Map<String, dynamic> json) =>
      _$GetAdminHealthReady200ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GetAdminHealthReady200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
