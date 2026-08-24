//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_notifications200_response_data_inner.dart';
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'set_notification_read_state200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SetNotificationReadState200Response {
  /// Returns a new [SetNotificationReadState200Response] instance.
  SetNotificationReadState200Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final ListNotifications200ResponseDataInner data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetNotificationReadState200Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory SetNotificationReadState200Response.fromJson(
    Map<String, dynamic> json,
  ) => _$SetNotificationReadState200ResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$SetNotificationReadState200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
