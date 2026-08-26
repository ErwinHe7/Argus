//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'field_error.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FieldError {
  /// Returns a new [FieldError] instance.
  FieldError({required this.code, required this.path});

  @JsonKey(name: r'code', required: true, includeIfNull: false)
  final String code;

  @JsonKey(name: r'path', required: true, includeIfNull: false)
  final String path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldError && other.code == code && other.path == path;

  @override
  int get hashCode => code.hashCode + path.hashCode;

  factory FieldError.fromJson(Map<String, dynamic> json) =>
      _$FieldErrorFromJson(json);

  Map<String, dynamic> toJson() => _$FieldErrorToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
