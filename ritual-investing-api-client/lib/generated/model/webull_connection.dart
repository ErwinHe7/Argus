//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'webull_connection.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WebullConnection {
  /// Returns a new [WebullConnection] instance.
  WebullConnection({
    this.authorizedAt,

    this.capabilityVersion,

    this.disconnectedAt,

    this.id,

    this.lastErrorCode,

    required this.status,

    this.updatedAt,
  });

  @JsonKey(name: r'authorized_at', required: false, includeIfNull: false)
  final DateTime? authorizedAt;

  // minimum: 0
  @JsonKey(name: r'capability_version', required: false, includeIfNull: false)
  final int? capabilityVersion;

  @JsonKey(name: r'disconnected_at', required: false, includeIfNull: false)
  final DateTime? disconnectedAt;

  @JsonKey(name: r'id', required: false, includeIfNull: false)
  final String? id;

  @JsonKey(name: r'last_error_code', required: false, includeIfNull: false)
  final String? lastErrorCode;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: WebullConnectionStatusEnum.unknownDefaultOpenApi,
  )
  final WebullConnectionStatusEnum status;

  @JsonKey(name: r'updated_at', required: false, includeIfNull: false)
  final DateTime? updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebullConnection &&
          other.authorizedAt == authorizedAt &&
          other.capabilityVersion == capabilityVersion &&
          other.disconnectedAt == disconnectedAt &&
          other.id == id &&
          other.lastErrorCode == lastErrorCode &&
          other.status == status &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      (authorizedAt == null ? 0 : authorizedAt.hashCode) +
      (capabilityVersion == null ? 0 : capabilityVersion.hashCode) +
      (disconnectedAt == null ? 0 : disconnectedAt.hashCode) +
      (id == null ? 0 : id.hashCode) +
      (lastErrorCode == null ? 0 : lastErrorCode.hashCode) +
      status.hashCode +
      (updatedAt == null ? 0 : updatedAt.hashCode);

  factory WebullConnection.fromJson(Map<String, dynamic> json) =>
      _$WebullConnectionFromJson(json);

  Map<String, dynamic> toJson() => _$WebullConnectionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum WebullConnectionStatusEnum {
  @JsonValue(r'disconnected')
  disconnected(r'disconnected'),
  @JsonValue(r'pending')
  pending(r'pending'),
  @JsonValue(r'connected')
  connected(r'connected'),
  @JsonValue(r'denied')
  denied(r'denied'),
  @JsonValue(r'failed')
  failed(r'failed'),
  @JsonValue(r'temporarily_unavailable')
  temporarilyUnavailable(r'temporarily_unavailable'),
  @JsonValue(r'reauthorization_required')
  reauthorizationRequired(r'reauthorization_required'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const WebullConnectionStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
