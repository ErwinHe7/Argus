// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rowan_counsel.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RowanCounselCWProxy {
  RowanCounsel allowedTokens(List<String> allowedTokens);

  RowanCounsel bodyTemplate(String bodyTemplate);

  RowanCounsel id(String id);

  RowanCounsel priority(int? priority);

  RowanCounsel riskFooter(String riskFooter);

  RowanCounsel scriptKey(String scriptKey);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RowanCounsel(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RowanCounsel(...).copyWith(id: 12, name: "My name")
  /// ````
  RowanCounsel call({
    List<String> allowedTokens,
    String bodyTemplate,
    String id,
    int? priority,
    String riskFooter,
    String scriptKey,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRowanCounsel.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRowanCounsel.copyWith.fieldName(...)`
class _$RowanCounselCWProxyImpl implements _$RowanCounselCWProxy {
  const _$RowanCounselCWProxyImpl(this._value);

  final RowanCounsel _value;

  @override
  RowanCounsel allowedTokens(List<String> allowedTokens) =>
      this(allowedTokens: allowedTokens);

  @override
  RowanCounsel bodyTemplate(String bodyTemplate) =>
      this(bodyTemplate: bodyTemplate);

  @override
  RowanCounsel id(String id) => this(id: id);

  @override
  RowanCounsel priority(int? priority) => this(priority: priority);

  @override
  RowanCounsel riskFooter(String riskFooter) => this(riskFooter: riskFooter);

  @override
  RowanCounsel scriptKey(String scriptKey) => this(scriptKey: scriptKey);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RowanCounsel(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RowanCounsel(...).copyWith(id: 12, name: "My name")
  /// ````
  RowanCounsel call({
    Object? allowedTokens = const $CopyWithPlaceholder(),
    Object? bodyTemplate = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? priority = const $CopyWithPlaceholder(),
    Object? riskFooter = const $CopyWithPlaceholder(),
    Object? scriptKey = const $CopyWithPlaceholder(),
  }) {
    return RowanCounsel(
      allowedTokens: allowedTokens == const $CopyWithPlaceholder()
          ? _value.allowedTokens
          // ignore: cast_nullable_to_non_nullable
          : allowedTokens as List<String>,
      bodyTemplate: bodyTemplate == const $CopyWithPlaceholder()
          ? _value.bodyTemplate
          // ignore: cast_nullable_to_non_nullable
          : bodyTemplate as String,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      priority: priority == const $CopyWithPlaceholder()
          ? _value.priority
          // ignore: cast_nullable_to_non_nullable
          : priority as int?,
      riskFooter: riskFooter == const $CopyWithPlaceholder()
          ? _value.riskFooter
          // ignore: cast_nullable_to_non_nullable
          : riskFooter as String,
      scriptKey: scriptKey == const $CopyWithPlaceholder()
          ? _value.scriptKey
          // ignore: cast_nullable_to_non_nullable
          : scriptKey as String,
    );
  }
}

extension $RowanCounselCopyWith on RowanCounsel {
  /// Returns a callable class that can be used as follows: `instanceOfRowanCounsel.copyWith(...)` or like so:`instanceOfRowanCounsel.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RowanCounselCWProxy get copyWith => _$RowanCounselCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RowanCounsel _$RowanCounselFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'RowanCounsel',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'allowed_tokens',
            'body_template',
            'id',
            'priority',
            'risk_footer',
            'script_key',
          ],
        );
        final val = RowanCounsel(
          allowedTokens: $checkedConvert(
            'allowed_tokens',
            (v) => (v as List<dynamic>).map((e) => e as String).toList(),
          ),
          bodyTemplate: $checkedConvert('body_template', (v) => v as String),
          id: $checkedConvert('id', (v) => v as String),
          priority: $checkedConvert('priority', (v) => (v as num?)?.toInt()),
          riskFooter: $checkedConvert('risk_footer', (v) => v as String),
          scriptKey: $checkedConvert('script_key', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'allowedTokens': 'allowed_tokens',
        'bodyTemplate': 'body_template',
        'riskFooter': 'risk_footer',
        'scriptKey': 'script_key',
      },
    );

Map<String, dynamic> _$RowanCounselToJson(RowanCounsel instance) =>
    <String, dynamic>{
      'allowed_tokens': instance.allowedTokens,
      'body_template': instance.bodyTemplate,
      'id': instance.id,
      'priority': instance.priority,
      'risk_footer': instance.riskFooter,
      'script_key': instance.scriptKey,
    };
