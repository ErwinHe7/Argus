//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/session_bootstrap.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'session_bootstrap_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SessionBootstrapResponse {
  /// Returns a new [SessionBootstrapResponse] instance.
  SessionBootstrapResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final SessionBootstrap data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionBootstrapResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory SessionBootstrapResponse.fromJson(Map<String, dynamic> json) =>
      _$SessionBootstrapResponseFromJson(json);

  Map<String, dynamic> toJson() => _$SessionBootstrapResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
