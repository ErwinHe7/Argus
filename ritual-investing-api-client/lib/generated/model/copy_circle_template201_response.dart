//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/circle_view.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'copy_circle_template201_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CopyCircleTemplate201Response {
  /// Returns a new [CopyCircleTemplate201Response] instance.
  CopyCircleTemplate201Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final CircleView data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CopyCircleTemplate201Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory CopyCircleTemplate201Response.fromJson(Map<String, dynamic> json) =>
      _$CopyCircleTemplate201ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CopyCircleTemplate201ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
