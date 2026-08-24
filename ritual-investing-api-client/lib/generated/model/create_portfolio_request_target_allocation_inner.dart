//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_portfolio_request_target_allocation_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreatePortfolioRequestTargetAllocationInner {
  /// Returns a new [CreatePortfolioRequestTargetAllocationInner] instance.
  CreatePortfolioRequestTargetAllocationInner({
    required this.assetId,

    required this.targetBps,
  });

  @JsonKey(name: r'asset_id', required: true, includeIfNull: false)
  final String assetId;

  // minimum: 0
  // maximum: 10000
  @JsonKey(name: r'target_bps', required: true, includeIfNull: false)
  final int targetBps;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreatePortfolioRequestTargetAllocationInner &&
          other.assetId == assetId &&
          other.targetBps == targetBps;

  @override
  int get hashCode => assetId.hashCode + targetBps.hashCode;

  factory CreatePortfolioRequestTargetAllocationInner.fromJson(
    Map<String, dynamic> json,
  ) => _$CreatePortfolioRequestTargetAllocationInnerFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreatePortfolioRequestTargetAllocationInnerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
