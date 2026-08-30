// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'starpath_progress.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$StarpathProgressCWProxy {
  StarpathProgress currentNodeOrdinal(int currentNodeOrdinal);

  StarpathProgress updatedAt(DateTime updatedAt);

  StarpathProgress version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathProgress(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathProgress(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathProgress call({
    int currentNodeOrdinal,
    DateTime updatedAt,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfStarpathProgress.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfStarpathProgress.copyWith.fieldName(...)`
class _$StarpathProgressCWProxyImpl implements _$StarpathProgressCWProxy {
  const _$StarpathProgressCWProxyImpl(this._value);

  final StarpathProgress _value;

  @override
  StarpathProgress currentNodeOrdinal(int currentNodeOrdinal) =>
      this(currentNodeOrdinal: currentNodeOrdinal);

  @override
  StarpathProgress updatedAt(DateTime updatedAt) => this(updatedAt: updatedAt);

  @override
  StarpathProgress version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathProgress(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathProgress(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathProgress call({
    Object? currentNodeOrdinal = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return StarpathProgress(
      currentNodeOrdinal: currentNodeOrdinal == const $CopyWithPlaceholder()
          ? _value.currentNodeOrdinal
          // ignore: cast_nullable_to_non_nullable
          : currentNodeOrdinal as int,
      updatedAt: updatedAt == const $CopyWithPlaceholder()
          ? _value.updatedAt
          // ignore: cast_nullable_to_non_nullable
          : updatedAt as DateTime,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $StarpathProgressCopyWith on StarpathProgress {
  /// Returns a callable class that can be used as follows: `instanceOfStarpathProgress.copyWith(...)` or like so:`instanceOfStarpathProgress.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$StarpathProgressCWProxy get copyWith => _$StarpathProgressCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StarpathProgress _$StarpathProgressFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'StarpathProgress',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['current_node_ordinal', 'updated_at', 'version'],
        );
        final val = StarpathProgress(
          currentNodeOrdinal: $checkedConvert(
            'current_node_ordinal',
            (v) => (v as num).toInt(),
          ),
          updatedAt: $checkedConvert(
            'updated_at',
            (v) => DateTime.parse(v as String),
          ),
          version: $checkedConvert('version', (v) => (v as num).toInt()),
        );
        return val;
      },
      fieldKeyMap: const {
        'currentNodeOrdinal': 'current_node_ordinal',
        'updatedAt': 'updated_at',
      },
    );

Map<String, dynamic> _$StarpathProgressToJson(StarpathProgress instance) =>
    <String, dynamic>{
      'current_node_ordinal': instance.currentNodeOrdinal,
      'updated_at': instance.updatedAt.toIso8601String(),
      'version': instance.version,
    };
