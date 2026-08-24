//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'get_briefing200_response_data_sections_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class GetBriefing200ResponseDataSectionsInner {
  /// Returns a new [GetBriefing200ResponseDataSectionsInner] instance.
  GetBriefing200ResponseDataSectionsInner({
    required this.ordinal,

    required this.payload,

    required this.schemaVersion,

    required this.sectionType,
  });

  // minimum: 0
  @JsonKey(name: r'ordinal', required: true, includeIfNull: false)
  final int ordinal;

  @JsonKey(name: r'payload', required: true, includeIfNull: false)
  final Map<String, Object?> payload;

  // minimum: 0
  @JsonKey(name: r'schema_version', required: true, includeIfNull: false)
  final int schemaVersion;

  @JsonKey(name: r'section_type', required: true, includeIfNull: false)
  final String sectionType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GetBriefing200ResponseDataSectionsInner &&
          other.ordinal == ordinal &&
          other.payload == payload &&
          other.schemaVersion == schemaVersion &&
          other.sectionType == sectionType;

  @override
  int get hashCode =>
      ordinal.hashCode +
      payload.hashCode +
      schemaVersion.hashCode +
      sectionType.hashCode;

  factory GetBriefing200ResponseDataSectionsInner.fromJson(
    Map<String, dynamic> json,
  ) => _$GetBriefing200ResponseDataSectionsInnerFromJson(json);

  Map<String, dynamic> toJson() =>
      _$GetBriefing200ResponseDataSectionsInnerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
