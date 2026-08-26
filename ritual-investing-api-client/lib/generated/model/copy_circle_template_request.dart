//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'copy_circle_template_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CopyCircleTemplateRequest {
  /// Returns a new [CopyCircleTemplateRequest] instance.
  CopyCircleTemplateRequest({this.title});

  @JsonKey(name: r'title', required: false, includeIfNull: false)
  final String? title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CopyCircleTemplateRequest && other.title == title;

  @override
  int get hashCode => title.hashCode;

  factory CopyCircleTemplateRequest.fromJson(Map<String, dynamic> json) =>
      _$CopyCircleTemplateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CopyCircleTemplateRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
