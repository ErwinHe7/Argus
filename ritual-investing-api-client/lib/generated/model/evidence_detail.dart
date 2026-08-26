//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/evidence_detail_source.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'evidence_detail.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class EvidenceDetail {
  /// Returns a new [EvidenceDetail] instance.
  EvidenceDetail({
    required this.claimId,

    required this.factorLabel,

    required this.observedAt,

    required this.source_,

    required this.summary,

    required this.uncertainty,
  });

  @JsonKey(name: r'claim_id', required: true, includeIfNull: false)
  final String claimId;

  @JsonKey(name: r'factor_label', required: true, includeIfNull: false)
  final String factorLabel;

  @JsonKey(name: r'observed_at', required: true, includeIfNull: false)
  final DateTime observedAt;

  @JsonKey(name: r'source', required: true, includeIfNull: false)
  final EvidenceDetailSource source_;

  @JsonKey(name: r'summary', required: true, includeIfNull: false)
  final String summary;

  @JsonKey(name: r'uncertainty', required: true, includeIfNull: false)
  final String uncertainty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvidenceDetail &&
          other.claimId == claimId &&
          other.factorLabel == factorLabel &&
          other.observedAt == observedAt &&
          other.source_ == source_ &&
          other.summary == summary &&
          other.uncertainty == uncertainty;

  @override
  int get hashCode =>
      claimId.hashCode +
      factorLabel.hashCode +
      observedAt.hashCode +
      source_.hashCode +
      summary.hashCode +
      uncertainty.hashCode;

  factory EvidenceDetail.fromJson(Map<String, dynamic> json) =>
      _$EvidenceDetailFromJson(json);

  Map<String, dynamic> toJson() => _$EvidenceDetailToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
