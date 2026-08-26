//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/create_portfolio_request_target_allocation_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patch_portfolio_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchPortfolioRequest {
  /// Returns a new [PatchPortfolioRequest] instance.
  PatchPortfolioRequest({this.name, this.targetAllocation});

  @JsonKey(name: r'name', required: false, includeIfNull: false)
  final String? name;

  @JsonKey(name: r'target_allocation', required: false, includeIfNull: false)
  final List<CreatePortfolioRequestTargetAllocationInner>? targetAllocation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchPortfolioRequest &&
          other.name == name &&
          other.targetAllocation == targetAllocation;

  @override
  int get hashCode => name.hashCode + targetAllocation.hashCode;

  factory PatchPortfolioRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchPortfolioRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PatchPortfolioRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
