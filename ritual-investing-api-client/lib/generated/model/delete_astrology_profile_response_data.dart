//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'delete_astrology_profile_response_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DeleteAstrologyProfileResponseData {
  /// Returns a new [DeleteAstrologyProfileResponseData] instance.
  DeleteAstrologyProfileResponseData({required this.removed});

  @JsonKey(name: r'removed', required: true, includeIfNull: false)
  final bool removed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeleteAstrologyProfileResponseData && other.removed == removed;

  @override
  int get hashCode => removed.hashCode;

  factory DeleteAstrologyProfileResponseData.fromJson(
    Map<String, dynamic> json,
  ) => _$DeleteAstrologyProfileResponseDataFromJson(json);

  Map<String, dynamic> toJson() =>
      _$DeleteAstrologyProfileResponseDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
