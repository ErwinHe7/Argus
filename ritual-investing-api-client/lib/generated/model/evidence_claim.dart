//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/evidence_source.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'evidence_claim.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class EvidenceClaim {
  /// Returns a new [EvidenceClaim] instance.
  EvidenceClaim({
    required this.claimType,

    required this.id,

    required this.observedAt,

    required this.source_,

    required this.summary,

    required this.uncertainty,
  });

  @JsonKey(name: r'claim_type', required: true, includeIfNull: false)
  final String claimType;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'observed_at', required: true, includeIfNull: true)
  final DateTime? observedAt;

  @JsonKey(name: r'source', required: true, includeIfNull: false)
  final EvidenceSource source_;

  @JsonKey(name: r'summary', required: true, includeIfNull: false)
  final String summary;

  @JsonKey(name: r'uncertainty', required: true, includeIfNull: false)
  final String uncertainty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvidenceClaim &&
          other.claimType == claimType &&
          other.id == id &&
          other.observedAt == observedAt &&
          other.source_ == source_ &&
          other.summary == summary &&
          other.uncertainty == uncertainty;

  @override
  int get hashCode =>
      claimType.hashCode +
      id.hashCode +
      (observedAt == null ? 0 : observedAt.hashCode) +
      source_.hashCode +
      summary.hashCode +
      uncertainty.hashCode;

  factory EvidenceClaim.fromJson(Map<String, dynamic> json) =>
      _$EvidenceClaimFromJson(json);

  Map<String, dynamic> toJson() => _$EvidenceClaimToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
