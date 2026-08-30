//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/starpath_knowledge_check.dart';
import 'package:ritual_investing_api_client/generated/model/starpath_node_guide.dart';
import 'package:ritual_investing_api_client/generated/model/starpath_factual_section.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'starpath_node.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StarpathNode {
  /// Returns a new [StarpathNode] instance.
  StarpathNode({
    required this.factualSections,

    required this.factualSummary,

    required this.guide,

    required this.knowledgeCheck,

    required this.lessonId,

    required this.materialLimitations,

    required this.mythicMnemonic,

    required this.nodeOrdinal,

    required this.pathwayOrdinal,

    required this.pathwayPosition,

    required this.recallPrompt,

    required this.revisionId,

    required this.riskContext,

    required this.rowanExplanation,

    required this.state,

    required this.title,
  });

  @JsonKey(name: r'factual_sections', required: true, includeIfNull: false)
  final List<StarpathFactualSection> factualSections;

  @JsonKey(name: r'factual_summary', required: true, includeIfNull: false)
  final String factualSummary;

  @JsonKey(name: r'guide', required: true, includeIfNull: false)
  final StarpathNodeGuide guide;

  @JsonKey(name: r'knowledge_check', required: true, includeIfNull: false)
  final StarpathKnowledgeCheck knowledgeCheck;

  @JsonKey(name: r'lesson_id', required: true, includeIfNull: false)
  final String lessonId;

  @JsonKey(name: r'material_limitations', required: true, includeIfNull: false)
  final String materialLimitations;

  @JsonKey(name: r'mythic_mnemonic', required: true, includeIfNull: false)
  final String mythicMnemonic;

  // minimum: 1
  // maximum: 8
  @JsonKey(name: r'node_ordinal', required: true, includeIfNull: false)
  final int nodeOrdinal;

  // minimum: 1
  // maximum: 4
  @JsonKey(name: r'pathway_ordinal', required: true, includeIfNull: false)
  final int pathwayOrdinal;

  // minimum: 1
  // maximum: 2
  @JsonKey(name: r'pathway_position', required: true, includeIfNull: false)
  final int pathwayPosition;

  @JsonKey(name: r'recall_prompt', required: true, includeIfNull: false)
  final String recallPrompt;

  @JsonKey(name: r'revision_id', required: true, includeIfNull: false)
  final String revisionId;

  @JsonKey(name: r'risk_context', required: true, includeIfNull: false)
  final String riskContext;

  @JsonKey(name: r'rowan_explanation', required: true, includeIfNull: false)
  final String rowanExplanation;

  @JsonKey(
    name: r'state',
    required: true,
    includeIfNull: false,
    unknownEnumValue: StarpathNodeStateEnum.unknownDefaultOpenApi,
  )
  final StarpathNodeStateEnum state;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StarpathNode &&
          other.factualSections == factualSections &&
          other.factualSummary == factualSummary &&
          other.guide == guide &&
          other.knowledgeCheck == knowledgeCheck &&
          other.lessonId == lessonId &&
          other.materialLimitations == materialLimitations &&
          other.mythicMnemonic == mythicMnemonic &&
          other.nodeOrdinal == nodeOrdinal &&
          other.pathwayOrdinal == pathwayOrdinal &&
          other.pathwayPosition == pathwayPosition &&
          other.recallPrompt == recallPrompt &&
          other.revisionId == revisionId &&
          other.riskContext == riskContext &&
          other.rowanExplanation == rowanExplanation &&
          other.state == state &&
          other.title == title;

  @override
  int get hashCode =>
      factualSections.hashCode +
      factualSummary.hashCode +
      guide.hashCode +
      knowledgeCheck.hashCode +
      lessonId.hashCode +
      materialLimitations.hashCode +
      mythicMnemonic.hashCode +
      nodeOrdinal.hashCode +
      pathwayOrdinal.hashCode +
      pathwayPosition.hashCode +
      recallPrompt.hashCode +
      revisionId.hashCode +
      riskContext.hashCode +
      rowanExplanation.hashCode +
      state.hashCode +
      title.hashCode;

  factory StarpathNode.fromJson(Map<String, dynamic> json) =>
      _$StarpathNodeFromJson(json);

  Map<String, dynamic> toJson() => _$StarpathNodeToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum StarpathNodeStateEnum {
  @JsonValue(r'completed')
  completed(r'completed'),
  @JsonValue(r'current')
  current(r'current'),
  @JsonValue(r'locked')
  locked(r'locked'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const StarpathNodeStateEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
