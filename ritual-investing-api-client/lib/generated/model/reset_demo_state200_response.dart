//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/demo_reset_result.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'reset_demo_state200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ResetDemoState200Response {
  /// Returns a new [ResetDemoState200Response] instance.
  ResetDemoState200Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final DemoResetResult data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResetDemoState200Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory ResetDemoState200Response.fromJson(Map<String, dynamic> json) =>
      _$ResetDemoState200ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ResetDemoState200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
