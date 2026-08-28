//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'reconnect_webull_connection_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ReconnectWebullConnectionRequest {
  /// Returns a new [ReconnectWebullConnectionRequest] instance.
  ReconnectWebullConnectionRequest({required this.returnTarget});

  @JsonKey(
    name: r'return_target',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        ReconnectWebullConnectionRequestReturnTargetEnum.unknownDefaultOpenApi,
  )
  final ReconnectWebullConnectionRequestReturnTargetEnum returnTarget;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReconnectWebullConnectionRequest &&
          other.returnTarget == returnTarget;

  @override
  int get hashCode => returnTarget.hashCode;

  factory ReconnectWebullConnectionRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$ReconnectWebullConnectionRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$ReconnectWebullConnectionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum ReconnectWebullConnectionRequestReturnTargetEnum {
  @JsonValue(r'webull_https')
  webullHttps(r'webull_https'),
  @JsonValue(r'webull_native')
  webullNative(r'webull_native'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ReconnectWebullConnectionRequestReturnTargetEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
