//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'update_circle_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class UpdateCircleRequest {
  /// Returns a new [UpdateCircleRequest] instance.
  UpdateCircleRequest({this.description, this.title});

  @JsonKey(name: r'description', required: false, includeIfNull: false)
  final String? description;

  @JsonKey(name: r'title', required: false, includeIfNull: false)
  final String? title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateCircleRequest &&
          other.description == description &&
          other.title == title;

  @override
  int get hashCode => description.hashCode + title.hashCode;

  factory UpdateCircleRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateCircleRequestFromJson(json);

  Map<String, dynamic> toJson() => _$UpdateCircleRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
