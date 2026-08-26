//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'member_profile.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MemberProfile {
  /// Returns a new [MemberProfile] instance.
  MemberProfile({
    required this.displayName,

    required this.locale,

    required this.version,
  });

  @JsonKey(name: r'display_name', required: true, includeIfNull: false)
  final String displayName;

  @JsonKey(name: r'locale', required: true, includeIfNull: false)
  final String locale;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberProfile &&
          other.displayName == displayName &&
          other.locale == locale &&
          other.version == version;

  @override
  int get hashCode => displayName.hashCode + locale.hashCode + version.hashCode;

  factory MemberProfile.fromJson(Map<String, dynamic> json) =>
      _$MemberProfileFromJson(json);

  Map<String, dynamic> toJson() => _$MemberProfileToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
