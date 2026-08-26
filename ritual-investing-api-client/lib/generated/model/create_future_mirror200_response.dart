//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/future_mirror_view.dart';
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_future_mirror200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateFutureMirror200Response {
  /// Returns a new [CreateFutureMirror200Response] instance.
  CreateFutureMirror200Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final FutureMirrorView data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateFutureMirror200Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory CreateFutureMirror200Response.fromJson(Map<String, dynamic> json) =>
      _$CreateFutureMirror200ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CreateFutureMirror200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
