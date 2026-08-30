//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'starpath_evidence.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StarpathEvidence {
  /// Returns a new [StarpathEvidence] instance.
  StarpathEvidence({
    required this.canonicalUrl,

    required this.claimSummary,

    required this.currentUntil,

    required this.effectiveAt,

    required this.ordinal,

    required this.publisher,

    required this.retrievedAt,

    required this.sourceObservedAt,

    required this.sourceTitle,
  });

  @JsonKey(name: r'canonical_url', required: true, includeIfNull: false)
  final String canonicalUrl;

  @JsonKey(name: r'claim_summary', required: true, includeIfNull: false)
  final String claimSummary;

  @JsonKey(name: r'current_until', required: true, includeIfNull: false)
  final DateTime currentUntil;

  @JsonKey(name: r'effective_at', required: true, includeIfNull: true)
  final DateTime? effectiveAt;

  // minimum: 1
  // maximum: 12
  @JsonKey(name: r'ordinal', required: true, includeIfNull: false)
  final int ordinal;

  @JsonKey(name: r'publisher', required: true, includeIfNull: false)
  final String publisher;

  @JsonKey(name: r'retrieved_at', required: true, includeIfNull: false)
  final DateTime retrievedAt;

  @JsonKey(name: r'source_observed_at', required: true, includeIfNull: false)
  final DateTime sourceObservedAt;

  @JsonKey(name: r'source_title', required: true, includeIfNull: false)
  final String sourceTitle;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StarpathEvidence &&
          other.canonicalUrl == canonicalUrl &&
          other.claimSummary == claimSummary &&
          other.currentUntil == currentUntil &&
          other.effectiveAt == effectiveAt &&
          other.ordinal == ordinal &&
          other.publisher == publisher &&
          other.retrievedAt == retrievedAt &&
          other.sourceObservedAt == sourceObservedAt &&
          other.sourceTitle == sourceTitle;

  @override
  int get hashCode =>
      canonicalUrl.hashCode +
      claimSummary.hashCode +
      currentUntil.hashCode +
      (effectiveAt == null ? 0 : effectiveAt.hashCode) +
      ordinal.hashCode +
      publisher.hashCode +
      retrievedAt.hashCode +
      sourceObservedAt.hashCode +
      sourceTitle.hashCode;

  factory StarpathEvidence.fromJson(Map<String, dynamic> json) =>
      _$StarpathEvidenceFromJson(json);

  Map<String, dynamic> toJson() => _$StarpathEvidenceToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
