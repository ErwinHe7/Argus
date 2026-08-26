//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'complete_media_upload_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CompleteMediaUploadRequest {
  /// Returns a new [CompleteMediaUploadRequest] instance.
  CompleteMediaUploadRequest({required this.checksum});

  @JsonKey(name: r'checksum', required: true, includeIfNull: false)
  final String checksum;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompleteMediaUploadRequest && other.checksum == checksum;

  @override
  int get hashCode => checksum.hashCode;

  factory CompleteMediaUploadRequest.fromJson(Map<String, dynamic> json) =>
      _$CompleteMediaUploadRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CompleteMediaUploadRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
