//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/circle_view_assets_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'circle_view.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CircleView {
  /// Returns a new [CircleView] instance.
  CircleView({
    required this.archivedAt,

    required this.assets,

    required this.description,

    required this.id,

    required this.private,

    required this.sourceRevisionId,

    required this.sourceTemplateId,

    required this.title,

    required this.version,
  });

  @JsonKey(name: r'archived_at', required: true, includeIfNull: true)
  final DateTime? archivedAt;

  @JsonKey(name: r'assets', required: true, includeIfNull: false)
  final List<CircleViewAssetsInner> assets;

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

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CircleView &&
          other.archivedAt == archivedAt &&
          other.assets == assets &&
          other.description == description &&
          other.id == id &&
          other.private == private &&
          other.sourceRevisionId == sourceRevisionId &&
          other.sourceTemplateId == sourceTemplateId &&
          other.title == title &&
          other.version == version;

  @override
  int get hashCode =>
      (archivedAt == null ? 0 : archivedAt.hashCode) +
      assets.hashCode +
      description.hashCode +
      id.hashCode +
      private.hashCode +
      (sourceRevisionId == null ? 0 : sourceRevisionId.hashCode) +
      (sourceTemplateId == null ? 0 : sourceTemplateId.hashCode) +
      title.hashCode +
      version.hashCode;

  factory CircleView.fromJson(Map<String, dynamic> json) =>
      _$CircleViewFromJson(json);

  Map<String, dynamic> toJson() => _$CircleViewToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
