//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/circle_asset_input.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_circle_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateCircleRequest {
  /// Returns a new [CreateCircleRequest] instance.
  CreateCircleRequest({
    this.assets,

    required this.description,

    required this.title,
  });

  @JsonKey(name: r'assets', required: false, includeIfNull: false)
  final List<CircleAssetInput>? assets;

  @JsonKey(name: r'description', required: true, includeIfNull: false)
  final String description;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateCircleRequest &&
          other.assets == assets &&
          other.description == description &&
          other.title == title;

  @override
  int get hashCode => assets.hashCode + description.hashCode + title.hashCode;

  factory CreateCircleRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateCircleRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateCircleRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
