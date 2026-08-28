//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_audit200_response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/webull_connection.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'webull_connection_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WebullConnectionResponse {
  /// Returns a new [WebullConnectionResponse] instance.
  WebullConnectionResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final WebullConnection data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ListAdminAudit200ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebullConnectionResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory WebullConnectionResponse.fromJson(Map<String, dynamic> json) =>
      _$WebullConnectionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$WebullConnectionResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
