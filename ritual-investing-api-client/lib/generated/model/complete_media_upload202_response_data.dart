//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'complete_media_upload202_response_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CompleteMediaUpload202ResponseData {
  /// Returns a new [CompleteMediaUpload202ResponseData] instance.
  CompleteMediaUpload202ResponseData({
    required this.mediaId,

    required this.outboxId,

    required this.status,
  });

  @JsonKey(name: r'media_id', required: true, includeIfNull: false)
  final String mediaId;

  @JsonKey(name: r'outbox_id', required: true, includeIfNull: false)
  final String outboxId;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CompleteMediaUpload202ResponseDataStatusEnum.unknownDefaultOpenApi,
  )
  final CompleteMediaUpload202ResponseDataStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompleteMediaUpload202ResponseData &&
          other.mediaId == mediaId &&
          other.outboxId == outboxId &&
          other.status == status;

  @override
  int get hashCode => mediaId.hashCode + outboxId.hashCode + status.hashCode;

  factory CompleteMediaUpload202ResponseData.fromJson(
    Map<String, dynamic> json,
  ) => _$CompleteMediaUpload202ResponseDataFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CompleteMediaUpload202ResponseDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CompleteMediaUpload202ResponseDataStatusEnum {
  @JsonValue(r'scanning')
  scanning(r'scanning'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CompleteMediaUpload202ResponseDataStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
