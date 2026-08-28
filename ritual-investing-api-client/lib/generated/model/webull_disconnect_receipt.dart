//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'webull_disconnect_receipt.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WebullDisconnectReceipt {
  /// Returns a new [WebullDisconnectReceipt] instance.
  WebullDisconnectReceipt({
    required this.connectionId,

    required this.providerGrantRevoked,

    required this.status,
  });

  @JsonKey(name: r'connection_id', required: true, includeIfNull: false)
  final String connectionId;

  @JsonKey(
    name: r'provider_grant_revoked',
    required: true,
    includeIfNull: false,
  )
  final bool providerGrantRevoked;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: WebullDisconnectReceiptStatusEnum.unknownDefaultOpenApi,
  )
  final WebullDisconnectReceiptStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebullDisconnectReceipt &&
          other.connectionId == connectionId &&
          other.providerGrantRevoked == providerGrantRevoked &&
          other.status == status;

  @override
  int get hashCode =>
      connectionId.hashCode + providerGrantRevoked.hashCode + status.hashCode;

  factory WebullDisconnectReceipt.fromJson(Map<String, dynamic> json) =>
      _$WebullDisconnectReceiptFromJson(json);

  Map<String, dynamic> toJson() => _$WebullDisconnectReceiptToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum WebullDisconnectReceiptStatusEnum {
  @JsonValue(r'disconnected')
  disconnected(r'disconnected'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const WebullDisconnectReceiptStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
