//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patch_circle_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchCircleRequest {
  /// Returns a new [PatchCircleRequest] instance.
  PatchCircleRequest({this.description, this.title});

  @JsonKey(name: r'description', required: false, includeIfNull: false)
  final String? description;

  @JsonKey(name: r'title', required: false, includeIfNull: false)
  final String? title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchCircleRequest &&
          other.description == description &&
          other.title == title;

  @override
  int get hashCode => description.hashCode + title.hashCode;

  factory PatchCircleRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchCircleRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PatchCircleRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
