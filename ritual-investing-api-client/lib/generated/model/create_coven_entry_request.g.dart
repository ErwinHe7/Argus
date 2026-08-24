// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_coven_entry_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateCovenEntryRequestCWProxy {
  CreateCovenEntryRequest companyId(String companyId);

  CreateCovenEntryRequest inclusionRationale(String inclusionRationale);

  CreateCovenEntryRequest limitations(String limitations);

  CreateCovenEntryRequest slug(String slug);

  CreateCovenEntryRequest summary(String summary);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateCovenEntryRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateCovenEntryRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateCovenEntryRequest call({
    String companyId,
    String inclusionRationale,
    String limitations,
    String slug,
    String summary,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateCovenEntryRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateCovenEntryRequest.copyWith.fieldName(...)`
class _$CreateCovenEntryRequestCWProxyImpl
    implements _$CreateCovenEntryRequestCWProxy {
  const _$CreateCovenEntryRequestCWProxyImpl(this._value);

  final CreateCovenEntryRequest _value;

  @override
  CreateCovenEntryRequest companyId(String companyId) =>
      this(companyId: companyId);

  @override
  CreateCovenEntryRequest inclusionRationale(String inclusionRationale) =>
      this(inclusionRationale: inclusionRationale);

  @override
  CreateCovenEntryRequest limitations(String limitations) =>
      this(limitations: limitations);

  @override
  CreateCovenEntryRequest slug(String slug) => this(slug: slug);

  @override
  CreateCovenEntryRequest summary(String summary) => this(summary: summary);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateCovenEntryRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateCovenEntryRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateCovenEntryRequest call({
    Object? companyId = const $CopyWithPlaceholder(),
    Object? inclusionRationale = const $CopyWithPlaceholder(),
    Object? limitations = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? summary = const $CopyWithPlaceholder(),
  }) {
    return CreateCovenEntryRequest(
      companyId: companyId == const $CopyWithPlaceholder()
          ? _value.companyId
          // ignore: cast_nullable_to_non_nullable
          : companyId as String,
      inclusionRationale: inclusionRationale == const $CopyWithPlaceholder()
          ? _value.inclusionRationale
          // ignore: cast_nullable_to_non_nullable
          : inclusionRationale as String,
      limitations: limitations == const $CopyWithPlaceholder()
          ? _value.limitations
          // ignore: cast_nullable_to_non_nullable
          : limitations as String,
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String,
      summary: summary == const $CopyWithPlaceholder()
          ? _value.summary
          // ignore: cast_nullable_to_non_nullable
          : summary as String,
    );
  }
}

extension $CreateCovenEntryRequestCopyWith on CreateCovenEntryRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateCovenEntryRequest.copyWith(...)` or like so:`instanceOfCreateCovenEntryRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateCovenEntryRequestCWProxy get copyWith =>
      _$CreateCovenEntryRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateCovenEntryRequest _$CreateCovenEntryRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CreateCovenEntryRequest',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'company_id',
        'inclusion_rationale',
        'limitations',
        'slug',
        'summary',
      ],
    );
    final val = CreateCovenEntryRequest(
      companyId: $checkedConvert('company_id', (v) => v as String),
      inclusionRationale: $checkedConvert(
        'inclusion_rationale',
        (v) => v as String,
      ),
      limitations: $checkedConvert('limitations', (v) => v as String),
      slug: $checkedConvert('slug', (v) => v as String),
      summary: $checkedConvert('summary', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'companyId': 'company_id',
    'inclusionRationale': 'inclusion_rationale',
  },
);

Map<String, dynamic> _$CreateCovenEntryRequestToJson(
  CreateCovenEntryRequest instance,
) => <String, dynamic>{
  'company_id': instance.companyId,
  'inclusion_rationale': instance.inclusionRationale,
  'limitations': instance.limitations,
  'slug': instance.slug,
  'summary': instance.summary,
};
