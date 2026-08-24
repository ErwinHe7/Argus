//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'session_response_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SessionResponseData {
  /// Returns a new [SessionResponseData] instance.
  SessionResponseData({
    required this.contractVersion,

    required this.serverTime,
  });

  @JsonKey(
    name: r'contract_version',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        SessionResponseDataContractVersionEnum.unknownDefaultOpenApi,
  )
  final SessionResponseDataContractVersionEnum contractVersion;

  @JsonKey(name: r'server_time', required: true, includeIfNull: false)
  final DateTime serverTime;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionResponseData &&
          other.contractVersion == contractVersion &&
          other.serverTime == serverTime;

  @override
  int get hashCode => contractVersion.hashCode + serverTime.hashCode;

  factory SessionResponseData.fromJson(Map<String, dynamic> json) =>
      _$SessionResponseDataFromJson(json);

  Map<String, dynamic> toJson() => _$SessionResponseDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum SessionResponseDataContractVersionEnum {
  @JsonValue(r'1.0.0')
  n1period0Period0(r'1.0.0'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SessionResponseDataContractVersionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
