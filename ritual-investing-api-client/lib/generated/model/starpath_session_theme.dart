//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'starpath_session_theme.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StarpathSessionTheme {
  /// Returns a new [StarpathSessionTheme] instance.
  StarpathSessionTheme({
    required this.accessibleLabel,

    required this.factualFocus,

    required this.horoscopeFrame,

    required this.id,

    required this.key,

    required this.title,
  });

  @JsonKey(name: r'accessible_label', required: true, includeIfNull: false)
  final String accessibleLabel;

  @JsonKey(name: r'factual_focus', required: true, includeIfNull: false)
  final String factualFocus;

  @JsonKey(name: r'horoscope_frame', required: true, includeIfNull: false)
  final String horoscopeFrame;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'key', required: true, includeIfNull: false)
  final String key;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StarpathSessionTheme &&
          other.accessibleLabel == accessibleLabel &&
          other.factualFocus == factualFocus &&
          other.horoscopeFrame == horoscopeFrame &&
          other.id == id &&
          other.key == key &&
          other.title == title;

  @override
  int get hashCode =>
      accessibleLabel.hashCode +
      factualFocus.hashCode +
      horoscopeFrame.hashCode +
      id.hashCode +
      key.hashCode +
      title.hashCode;

  factory StarpathSessionTheme.fromJson(Map<String, dynamic> json) =>
      _$StarpathSessionThemeFromJson(json);

  Map<String, dynamic> toJson() => _$StarpathSessionThemeToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
