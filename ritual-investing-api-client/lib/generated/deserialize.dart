import 'package:ritual_investing_api_client/generated/model/error_response.dart';
import 'package:ritual_investing_api_client/generated/model/error_response_error.dart';
import 'package:ritual_investing_api_client/generated/model/field_error.dart';
import 'package:ritual_investing_api_client/generated/model/health_response.dart';
import 'package:ritual_investing_api_client/generated/model/health_response_data.dart';
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/session_response.dart';
import 'package:ritual_investing_api_client/generated/model/session_response_data.dart';

final _regList = RegExp(r'^List<(.*)>$');
final _regSet = RegExp(r'^Set<(.*)>$');
final _regMap = RegExp(r'^Map<String,(.*)>$');

ReturnType deserialize<ReturnType, BaseType>(
  dynamic value,
  String targetType, {
  bool growable = true,
}) {
  switch (targetType) {
    case 'String':
      return '$value' as ReturnType;
    case 'int':
      return (value is int ? value : int.parse('$value')) as ReturnType;
    case 'bool':
      if (value is bool) {
        return value as ReturnType;
      }
      final valueString = '$value'.toLowerCase();
      return (valueString == 'true' || valueString == '1') as ReturnType;
    case 'double':
      return (value is double ? value : double.parse('$value')) as ReturnType;
    case 'ErrorResponse':
      return ErrorResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ErrorResponseError':
      return ErrorResponseError.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'FieldError':
      return FieldError.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'HealthResponse':
      return HealthResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'HealthResponseData':
      return HealthResponseData.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ResponseMeta':
      return ResponseMeta.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'SessionResponse':
      return SessionResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SessionResponseData':
      return SessionResponseData.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    default:
      RegExpMatch? match;

      if (value is List && (match = _regList.firstMatch(targetType)) != null) {
        targetType = match![1]!; // ignore: parameter_assignments
        return value
                .map<BaseType>(
                  (dynamic v) => deserialize<BaseType, BaseType>(
                    v,
                    targetType,
                    growable: growable,
                  ),
                )
                .toList(growable: growable)
            as ReturnType;
      }
      if (value is Set && (match = _regSet.firstMatch(targetType)) != null) {
        targetType = match![1]!; // ignore: parameter_assignments
        return value
                .map<BaseType>(
                  (dynamic v) => deserialize<BaseType, BaseType>(
                    v,
                    targetType,
                    growable: growable,
                  ),
                )
                .toSet()
            as ReturnType;
      }
      if (value is Map && (match = _regMap.firstMatch(targetType)) != null) {
        targetType = match![1]!.trim(); // ignore: parameter_assignments
        return Map<String, BaseType>.fromIterables(
              value.keys as Iterable<String>,
              value.values.map(
                (dynamic v) => deserialize<BaseType, BaseType>(
                  v,
                  targetType,
                  growable: growable,
                ),
              ),
            )
            as ReturnType;
      }
      break;
  }
  throw Exception('Cannot deserialize');
}
