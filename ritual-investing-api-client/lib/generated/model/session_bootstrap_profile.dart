//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'session_bootstrap_profile.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SessionBootstrapProfile {
  /// Returns a new [SessionBootstrapProfile] instance.
  SessionBootstrapProfile({required this.displayName, required this.locale});

  @JsonKey(name: r'display_name', required: true, includeIfNull: false)
  final String displayName;

  @JsonKey(name: r'locale', required: true, includeIfNull: false)
  final String locale;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionBootstrapProfile &&
          other.displayName == displayName &&
          other.locale == locale;

  @override
  int get hashCode => displayName.hashCode + locale.hashCode;

  factory SessionBootstrapProfile.fromJson(Map<String, dynamic> json) =>
      _$SessionBootstrapProfileFromJson(json);

  Map<String, dynamic> toJson() => _$SessionBootstrapProfileToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
