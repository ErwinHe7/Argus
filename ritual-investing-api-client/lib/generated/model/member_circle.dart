//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/member_circle_assets_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'member_circle.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MemberCircle {
  /// Returns a new [MemberCircle] instance.
  MemberCircle({
    required this.archivedAt,

    this.assets,

    required this.deletionEpoch,

    required this.description,

    required this.id,

    required this.private,

    required this.sourceRevisionId,

    required this.sourceTemplateId,

    required this.title,

    required this.userId,

    required this.version,
  });

  @JsonKey(name: r'archived_at', required: true, includeIfNull: true)
  final DateTime? archivedAt;

  @JsonKey(name: r'assets', required: false, includeIfNull: false)
  final List<MemberCircleAssetsInner>? assets;

  // minimum: 0
  @JsonKey(name: r'deletion_epoch', required: true, includeIfNull: true)
  final int? deletionEpoch;

  @JsonKey(name: r'description', required: true, includeIfNull: false)
  final String description;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'private', required: true, includeIfNull: false)
  final bool private;

  @JsonKey(name: r'source_revision_id', required: true, includeIfNull: true)
  final String? sourceRevisionId;

  @JsonKey(name: r'source_template_id', required: true, includeIfNull: true)
  final String? sourceTemplateId;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @JsonKey(name: r'user_id', required: true, includeIfNull: false)
  final String userId;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberCircle &&
          other.archivedAt == archivedAt &&
          other.assets == assets &&
          other.deletionEpoch == deletionEpoch &&
          other.description == description &&
          other.id == id &&
          other.private == private &&
          other.sourceRevisionId == sourceRevisionId &&
          other.sourceTemplateId == sourceTemplateId &&
          other.title == title &&
          other.userId == userId &&
          other.version == version;

  @override
  int get hashCode =>
      (archivedAt == null ? 0 : archivedAt.hashCode) +
      assets.hashCode +
      (deletionEpoch == null ? 0 : deletionEpoch.hashCode) +
      description.hashCode +
      id.hashCode +
      private.hashCode +
      (sourceRevisionId == null ? 0 : sourceRevisionId.hashCode) +
      (sourceTemplateId == null ? 0 : sourceTemplateId.hashCode) +
      title.hashCode +
      userId.hashCode +
      version.hashCode;

  factory MemberCircle.fromJson(Map<String, dynamic> json) =>
      _$MemberCircleFromJson(json);

  Map<String, dynamic> toJson() => _$MemberCircleToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
