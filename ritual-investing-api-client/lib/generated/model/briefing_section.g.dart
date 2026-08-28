// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'briefing_section.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BriefingSectionCWProxy {
  BriefingSection disclosure(String disclosure);

  BriefingSection ordinal(int ordinal);

  BriefingSection schemaVersion(int schemaVersion);

  BriefingSection sourceSequence(int sourceSequence);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BriefingSection(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BriefingSection(...).copyWith(id: 12, name: "My name")
  /// ````
  BriefingSection call({
    String disclosure,
    int ordinal,
    int schemaVersion,
    int sourceSequence,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBriefingSection.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBriefingSection.copyWith.fieldName(...)`
class _$BriefingSectionCWProxyImpl implements _$BriefingSectionCWProxy {
  const _$BriefingSectionCWProxyImpl(this._value);

  final BriefingSection _value;

  @override
  BriefingSection disclosure(String disclosure) => this(disclosure: disclosure);

  @override
  BriefingSection ordinal(int ordinal) => this(ordinal: ordinal);

  @override
  BriefingSection schemaVersion(int schemaVersion) =>
      this(schemaVersion: schemaVersion);

  @override
  BriefingSection sourceSequence(int sourceSequence) =>
      this(sourceSequence: sourceSequence);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BriefingSection(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BriefingSection(...).copyWith(id: 12, name: "My name")
  /// ````
  BriefingSection call({
    Object? disclosure = const $CopyWithPlaceholder(),
    Object? ordinal = const $CopyWithPlaceholder(),
    Object? schemaVersion = const $CopyWithPlaceholder(),
    Object? sourceSequence = const $CopyWithPlaceholder(),
  }) {
    return BriefingSection(
      disclosure: disclosure == const $CopyWithPlaceholder()
          ? _value.disclosure
          // ignore: cast_nullable_to_non_nullable
          : disclosure as String,
      ordinal: ordinal == const $CopyWithPlaceholder()
          ? _value.ordinal
          // ignore: cast_nullable_to_non_nullable
          : ordinal as int,
      schemaVersion: schemaVersion == const $CopyWithPlaceholder()
          ? _value.schemaVersion
          // ignore: cast_nullable_to_non_nullable
          : schemaVersion as int,
      sourceSequence: sourceSequence == const $CopyWithPlaceholder()
          ? _value.sourceSequence
          // ignore: cast_nullable_to_non_nullable
          : sourceSequence as int,
    );
  }
}

extension $BriefingSectionCopyWith on BriefingSection {
  /// Returns a callable class that can be used as follows: `instanceOfBriefingSection.copyWith(...)` or like so:`instanceOfBriefingSection.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BriefingSectionCWProxy get copyWith => _$BriefingSectionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BriefingSection _$BriefingSectionFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'BriefingSection',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'disclosure',
            'ordinal',
            'schema_version',
            'source_sequence',
          ],
        );
        final val = BriefingSection(
          disclosure: $checkedConvert('disclosure', (v) => v as String),
          ordinal: $checkedConvert('ordinal', (v) => (v as num).toInt()),
          schemaVersion: $checkedConvert(
            'schema_version',
            (v) => (v as num).toInt(),
          ),
          sourceSequence: $checkedConvert(
            'source_sequence',
            (v) => (v as num).toInt(),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'schemaVersion': 'schema_version',
        'sourceSequence': 'source_sequence',
      },
    );

Map<String, dynamic> _$BriefingSectionToJson(BriefingSection instance) =>
    <String, dynamic>{
      'disclosure': instance.disclosure,
      'ordinal': instance.ordinal,
      'schema_version': instance.schemaVersion,
      'source_sequence': instance.sourceSequence,
    };
