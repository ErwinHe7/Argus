//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patch_profile_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchProfileRequest {
  /// Returns a new [PatchProfileRequest] instance.
  PatchProfileRequest({this.displayName, this.locale});

  @JsonKey(name: r'display_name', required: false, includeIfNull: false)
  final String? displayName;

  @JsonKey(name: r'locale', required: false, includeIfNull: false)
  final String? locale;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchProfileRequest &&
          other.displayName == displayName &&
          other.locale == locale;

  @override
  int get hashCode => displayName.hashCode + locale.hashCode;

  factory PatchProfileRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchProfileRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PatchProfileRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
