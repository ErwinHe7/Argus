//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rowan_counsel.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RowanCounsel {
  /// Returns a new [RowanCounsel] instance.
  RowanCounsel({
    required this.allowedTokens,

    required this.bodyTemplate,

    required this.id,

    required this.priority,

    required this.riskFooter,

    required this.scriptKey,
  });

  @JsonKey(name: r'allowed_tokens', required: true, includeIfNull: false)
  final List<String> allowedTokens;

  @JsonKey(name: r'body_template', required: true, includeIfNull: false)
  final String bodyTemplate;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'priority', required: true, includeIfNull: true)
  final int? priority;

  @JsonKey(name: r'risk_footer', required: true, includeIfNull: false)
  final String riskFooter;

  @JsonKey(name: r'script_key', required: true, includeIfNull: false)
  final String scriptKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RowanCounsel &&
          other.allowedTokens == allowedTokens &&
          other.bodyTemplate == bodyTemplate &&
          other.id == id &&
          other.priority == priority &&
          other.riskFooter == riskFooter &&
          other.scriptKey == scriptKey;

  @override
  int get hashCode =>
      allowedTokens.hashCode +
      bodyTemplate.hashCode +
      id.hashCode +
      (priority == null ? 0 : priority.hashCode) +
      riskFooter.hashCode +
      scriptKey.hashCode;

  factory RowanCounsel.fromJson(Map<String, dynamic> json) =>
      _$RowanCounselFromJson(json);

  Map<String, dynamic> toJson() => _$RowanCounselToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
