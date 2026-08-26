//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'request_admin_asset_codex_review_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RequestAdminAssetCodexReviewRequest {
  /// Returns a new [RequestAdminAssetCodexReviewRequest] instance.
  RequestAdminAssetCodexReviewRequest({this.highTrust, required this.note});

  @JsonKey(name: r'high_trust', required: false, includeIfNull: false)
  final bool? highTrust;

  @JsonKey(name: r'note', required: true, includeIfNull: false)
  final String note;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequestAdminAssetCodexReviewRequest &&
          other.highTrust == highTrust &&
          other.note == note;

  @override
  int get hashCode => highTrust.hashCode + note.hashCode;

  factory RequestAdminAssetCodexReviewRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$RequestAdminAssetCodexReviewRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$RequestAdminAssetCodexReviewRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
