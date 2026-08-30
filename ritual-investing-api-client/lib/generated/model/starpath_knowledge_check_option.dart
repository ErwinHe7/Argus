//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'starpath_knowledge_check_option.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StarpathKnowledgeCheckOption {
  /// Returns a new [StarpathKnowledgeCheckOption] instance.
  StarpathKnowledgeCheckOption({
    required this.id,

    required this.label,

    required this.ordinal,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'label', required: true, includeIfNull: false)
  final String label;

  // minimum: 1
  // maximum: 5
  @JsonKey(name: r'ordinal', required: true, includeIfNull: false)
  final int ordinal;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StarpathKnowledgeCheckOption &&
          other.id == id &&
          other.label == label &&
          other.ordinal == ordinal;

  @override
  int get hashCode => id.hashCode + label.hashCode + ordinal.hashCode;

  factory StarpathKnowledgeCheckOption.fromJson(Map<String, dynamic> json) =>
      _$StarpathKnowledgeCheckOptionFromJson(json);

  Map<String, dynamic> toJson() => _$StarpathKnowledgeCheckOptionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
