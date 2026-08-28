//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'read_all_notifications_response_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ReadAllNotificationsResponseData {
  /// Returns a new [ReadAllNotificationsResponseData] instance.
  ReadAllNotificationsResponseData({required this.updatedCount});

  // minimum: 0
  // maximum: 10000
  @JsonKey(name: r'updated_count', required: true, includeIfNull: false)
  final int updatedCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadAllNotificationsResponseData &&
          other.updatedCount == updatedCount;

  @override
  int get hashCode => updatedCount.hashCode;

  factory ReadAllNotificationsResponseData.fromJson(
    Map<String, dynamic> json,
  ) => _$ReadAllNotificationsResponseDataFromJson(json);

  Map<String, dynamic> toJson() =>
      _$ReadAllNotificationsResponseDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
