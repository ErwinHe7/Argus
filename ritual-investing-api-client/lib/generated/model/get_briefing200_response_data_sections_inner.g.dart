// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_briefing200_response_data_sections_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetBriefing200ResponseDataSectionsInnerCWProxy {
  GetBriefing200ResponseDataSectionsInner ordinal(int ordinal);

  GetBriefing200ResponseDataSectionsInner payload(Map<String, Object?> payload);

  GetBriefing200ResponseDataSectionsInner schemaVersion(int schemaVersion);

  GetBriefing200ResponseDataSectionsInner sectionType(String sectionType);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetBriefing200ResponseDataSectionsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetBriefing200ResponseDataSectionsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  GetBriefing200ResponseDataSectionsInner call({
    int ordinal,
    Map<String, Object?> payload,
    int schemaVersion,
    String sectionType,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetBriefing200ResponseDataSectionsInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetBriefing200ResponseDataSectionsInner.copyWith.fieldName(...)`
class _$GetBriefing200ResponseDataSectionsInnerCWProxyImpl
    implements _$GetBriefing200ResponseDataSectionsInnerCWProxy {
  const _$GetBriefing200ResponseDataSectionsInnerCWProxyImpl(this._value);

  final GetBriefing200ResponseDataSectionsInner _value;

  @override
  GetBriefing200ResponseDataSectionsInner ordinal(int ordinal) =>
      this(ordinal: ordinal);

  @override
  GetBriefing200ResponseDataSectionsInner payload(
    Map<String, Object?> payload,
  ) => this(payload: payload);

  @override
  GetBriefing200ResponseDataSectionsInner schemaVersion(int schemaVersion) =>
      this(schemaVersion: schemaVersion);

  @override
  GetBriefing200ResponseDataSectionsInner sectionType(String sectionType) =>
      this(sectionType: sectionType);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetBriefing200ResponseDataSectionsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetBriefing200ResponseDataSectionsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  GetBriefing200ResponseDataSectionsInner call({
    Object? ordinal = const $CopyWithPlaceholder(),
    Object? payload = const $CopyWithPlaceholder(),
    Object? schemaVersion = const $CopyWithPlaceholder(),
    Object? sectionType = const $CopyWithPlaceholder(),
  }) {
    return GetBriefing200ResponseDataSectionsInner(
      ordinal: ordinal == const $CopyWithPlaceholder()
          ? _value.ordinal
          // ignore: cast_nullable_to_non_nullable
          : ordinal as int,
      payload: payload == const $CopyWithPlaceholder()
          ? _value.payload
          // ignore: cast_nullable_to_non_nullable
          : payload as Map<String, Object?>,
      schemaVersion: schemaVersion == const $CopyWithPlaceholder()
          ? _value.schemaVersion
          // ignore: cast_nullable_to_non_nullable
          : schemaVersion as int,
      sectionType: sectionType == const $CopyWithPlaceholder()
          ? _value.sectionType
          // ignore: cast_nullable_to_non_nullable
          : sectionType as String,
    );
  }
}

extension $GetBriefing200ResponseDataSectionsInnerCopyWith
    on GetBriefing200ResponseDataSectionsInner {
  /// Returns a callable class that can be used as follows: `instanceOfGetBriefing200ResponseDataSectionsInner.copyWith(...)` or like so:`instanceOfGetBriefing200ResponseDataSectionsInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetBriefing200ResponseDataSectionsInnerCWProxy get copyWith =>
      _$GetBriefing200ResponseDataSectionsInnerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetBriefing200ResponseDataSectionsInner
_$GetBriefing200ResponseDataSectionsInnerFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'GetBriefing200ResponseDataSectionsInner',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'ordinal',
            'payload',
            'schema_version',
            'section_type',
          ],
        );
        final val = GetBriefing200ResponseDataSectionsInner(
          ordinal: $checkedConvert('ordinal', (v) => (v as num).toInt()),
          payload: $checkedConvert('payload', (v) => v as Map<String, dynamic>),
          schemaVersion: $checkedConvert(
            'schema_version',
            (v) => (v as num).toInt(),
          ),
          sectionType: $checkedConvert('section_type', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'schemaVersion': 'schema_version',
        'sectionType': 'section_type',
      },
    );

Map<String, dynamic> _$GetBriefing200ResponseDataSectionsInnerToJson(
  GetBriefing200ResponseDataSectionsInner instance,
) => <String, dynamic>{
  'ordinal': instance.ordinal,
  'payload': instance.payload,
  'schema_version': instance.schemaVersion,
  'section_type': instance.sectionType,
};
