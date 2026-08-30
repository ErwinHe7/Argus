//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'starpath_node_guide.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StarpathNodeGuide {
  /// Returns a new [StarpathNodeGuide] instance.
  StarpathNodeGuide({required this.accessibleLabel, required this.tarotKey});

  @JsonKey(name: r'accessible_label', required: true, includeIfNull: false)
  final String accessibleLabel;

  @JsonKey(name: r'tarot_key', required: true, includeIfNull: false)
  final String tarotKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StarpathNodeGuide &&
          other.accessibleLabel == accessibleLabel &&
          other.tarotKey == tarotKey;

  @override
  int get hashCode => accessibleLabel.hashCode + tarotKey.hashCode;

  factory StarpathNodeGuide.fromJson(Map<String, dynamic> json) =>
      _$StarpathNodeGuideFromJson(json);

  Map<String, dynamic> toJson() => _$StarpathNodeGuideToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
