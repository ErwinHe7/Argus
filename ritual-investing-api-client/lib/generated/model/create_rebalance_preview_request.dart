//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/create_portfolio_request_target_allocation_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_rebalance_preview_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateRebalancePreviewRequest {
  /// Returns a new [CreateRebalancePreviewRequest] instance.
  CreateRebalancePreviewRequest({required this.targetAllocation});

  @JsonKey(name: r'target_allocation', required: true, includeIfNull: false)
  final List<CreatePortfolioRequestTargetAllocationInner> targetAllocation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateRebalancePreviewRequest &&
          other.targetAllocation == targetAllocation;

  @override
  int get hashCode => targetAllocation.hashCode;

  factory CreateRebalancePreviewRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateRebalancePreviewRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateRebalancePreviewRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
