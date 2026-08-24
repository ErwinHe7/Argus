//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'publish_admin_asset_codex_revision_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PublishAdminAssetCodexRevisionRequest {
  /// Returns a new [PublishAdminAssetCodexRevisionRequest] instance.
  PublishAdminAssetCodexRevisionRequest({
    required this.effectiveAt,

    required this.reason,
  });

  @JsonKey(name: r'effective_at', required: true, includeIfNull: false)
  final DateTime effectiveAt;

  @JsonKey(name: r'reason', required: true, includeIfNull: false)
  final String reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublishAdminAssetCodexRevisionRequest &&
          other.effectiveAt == effectiveAt &&
          other.reason == reason;

  @override
  int get hashCode => effectiveAt.hashCode + reason.hashCode;

  factory PublishAdminAssetCodexRevisionRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$PublishAdminAssetCodexRevisionRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$PublishAdminAssetCodexRevisionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
