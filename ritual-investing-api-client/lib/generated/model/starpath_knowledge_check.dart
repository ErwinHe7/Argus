//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/starpath_knowledge_check_option.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'starpath_knowledge_check.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StarpathKnowledgeCheck {
  /// Returns a new [StarpathKnowledgeCheck] instance.
  StarpathKnowledgeCheck({
    required this.id,

    required this.options,

    required this.prompt,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'options', required: true, includeIfNull: false)
  final List<StarpathKnowledgeCheckOption> options;

  @JsonKey(name: r'prompt', required: true, includeIfNull: false)
  final String prompt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StarpathKnowledgeCheck &&
          other.id == id &&
          other.options == options &&
          other.prompt == prompt;

  @override
  int get hashCode => id.hashCode + options.hashCode + prompt.hashCode;

  factory StarpathKnowledgeCheck.fromJson(Map<String, dynamic> json) =>
      _$StarpathKnowledgeCheckFromJson(json);

  Map<String, dynamic> toJson() => _$StarpathKnowledgeCheckToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
