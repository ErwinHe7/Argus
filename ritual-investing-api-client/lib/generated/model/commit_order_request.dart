//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'commit_order_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CommitOrderRequest {
  /// Returns a new [CommitOrderRequest] instance.
  CommitOrderRequest({required this.portfolioVersion, required this.previewId});

  // minimum: 0
  @JsonKey(name: r'portfolio_version', required: true, includeIfNull: false)
  final int portfolioVersion;

  @JsonKey(name: r'preview_id', required: true, includeIfNull: false)
  final String previewId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommitOrderRequest &&
          other.portfolioVersion == portfolioVersion &&
          other.previewId == previewId;

  @override
  int get hashCode => portfolioVersion.hashCode + previewId.hashCode;

  factory CommitOrderRequest.fromJson(Map<String, dynamic> json) =>
      _$CommitOrderRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CommitOrderRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
