//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/webull_disconnect_receipt.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_audit200_response_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'webull_disconnect_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WebullDisconnectResponse {
  /// Returns a new [WebullDisconnectResponse] instance.
  WebullDisconnectResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final WebullDisconnectReceipt data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ListAdminAudit200ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebullDisconnectResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory WebullDisconnectResponse.fromJson(Map<String, dynamic> json) =>
      _$WebullDisconnectResponseFromJson(json);

  Map<String, dynamic> toJson() => _$WebullDisconnectResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
