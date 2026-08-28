//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/get_account401_response_error.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'get_account401_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class GetAccount401Response {
  /// Returns a new [GetAccount401Response] instance.
  GetAccount401Response({required this.error});

  @JsonKey(name: r'error', required: true, includeIfNull: false)
  final GetAccount401ResponseError error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GetAccount401Response && other.error == error;

  @override
  int get hashCode => error.hashCode;

  factory GetAccount401Response.fromJson(Map<String, dynamic> json) =>
      _$GetAccount401ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GetAccount401ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
