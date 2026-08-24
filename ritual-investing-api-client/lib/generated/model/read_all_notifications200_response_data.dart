//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'read_all_notifications200_response_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ReadAllNotifications200ResponseData {
  /// Returns a new [ReadAllNotifications200ResponseData] instance.
  ReadAllNotifications200ResponseData({required this.updatedCount});

  // minimum: 0
  // maximum: 100
  @JsonKey(name: r'updated_count', required: true, includeIfNull: false)
  final int updatedCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadAllNotifications200ResponseData &&
          other.updatedCount == updatedCount;

  @override
  int get hashCode => updatedCount.hashCode;

  factory ReadAllNotifications200ResponseData.fromJson(
    Map<String, dynamic> json,
  ) => _$ReadAllNotifications200ResponseDataFromJson(json);

  Map<String, dynamic> toJson() =>
      _$ReadAllNotifications200ResponseDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
