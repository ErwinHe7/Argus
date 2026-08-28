//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'finalize_upload_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FinalizeUploadRequest {
  /// Returns a new [FinalizeUploadRequest] instance.
  FinalizeUploadRequest({required this.byteSize, required this.checksum});

  // minimum: 0
  @JsonKey(name: r'byteSize', required: true, includeIfNull: false)
  final int byteSize;

  @JsonKey(name: r'checksum', required: true, includeIfNull: false)
  final String checksum;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinalizeUploadRequest &&
          other.byteSize == byteSize &&
          other.checksum == checksum;

  @override
  int get hashCode => byteSize.hashCode + checksum.hashCode;

  factory FinalizeUploadRequest.fromJson(Map<String, dynamic> json) =>
      _$FinalizeUploadRequestFromJson(json);

  Map<String, dynamic> toJson() => _$FinalizeUploadRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
