// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    as api;

import '../../../core/api/date_only_request_interceptor.dart';
import '../../../core/api/api_failure_mapper.dart';
import '../../../core/api/view_state.dart';
import '../domain/model.dart';
import 'repository.dart';

class GeneratedBriefingService implements BriefingService {
  GeneratedBriefingService(api.RitualInvestingApiClient client)
    : _api = api.BriefingsApi(client.dio) {
    ensureDateOnlyRequestSerialization(client.dio);
  }

  final api.BriefingsApi _api;

  @override
  Future<BriefingPage> list({
    BriefingType? type,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? cursor,
  }) async {
    _requireUtcDate(periodStart, 'period_start');
    _requireUtcDate(periodEnd, 'period_end');
    if (periodStart != null &&
        periodEnd != null &&
        periodStart.isAfter(periodEnd)) {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
    try {
      final response = (await _api.listBriefings(
        type: _typeValue(type),
        periodStart: periodStart,
        periodEnd: periodEnd,
        cursor: cursor,
      )).data!;
      final items = response.data.map(_summary).toList(growable: false);
      _requireUniqueIds(items.map((item) => item.id));
      _requirePage(response.meta.hasMore, response.meta.nextCursor);
      return BriefingPage(
        items: items,
        hasMore: response.meta.hasMore,
        nextCursor: response.meta.nextCursor,
      );
    } on DioException catch (error) {
      _throwFailure(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
  }

  @override
  Future<BriefingDetail> get(String briefingId) async {
    _requireUuid(briefingId);
    try {
      final detail = _detail(
        (await _api.getBriefing(briefingId: briefingId)).data!.data,
      );
      if (detail.id != briefingId) _terminal();
      return detail;
    } on DioException catch (error) {
      _throwFailure(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
  }

  @override
  Future<DailyBriefingResult> daily(DateTime localDate) async {
    _requireUtcDate(localDate, 'local_date');
    try {
      final detail = _detail(
        (await _api.getDailyBriefing(localDate: localDate)).data!.data,
      );
      if (detail.type != BriefingType.daily) _terminal();
      return DailyBriefingResult.available(detail);
    } on DioException catch (error) {
      if (error.response?.statusCode == 202) {
        try {
          final raw = error.response?.data;
          if (raw is! Map) _terminal();
          final response = api.GetDailyBriefing202Response.fromJson(
            Map<String, dynamic>.from(raw),
          );
          if (response.data.status !=
              api.GetDailyBriefing202ResponseDataStatusEnum.briefingPending) {
            _terminal();
          }
          final pendingDate = _dateOnly(response.data.localDate);
          if (!_sameDate(pendingDate, localDate)) _terminal();
          return DailyBriefingResult.pending(pendingDate);
        } on LoadFailure {
          rethrow;
        } on Object {
          throw const LoadFailure(LoadPhase.terminalFailure);
        }
      }
      _throwFailure(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
  }

  @override
  Future<BriefingSummary> setRead(String briefingId, bool read) async {
    _requireUuid(briefingId);
    try {
      final value = (await _api.setBriefingReadState(
        briefingId: briefingId,
        setBriefingReadStateRequest: api.SetBriefingReadStateRequest(
          read: read,
        ),
      )).data!.data;
      final summary = _summary(value);
      if (summary.id != briefingId || summary.isRead != read) _terminal();
      return summary;
    } on DioException catch (error) {
      _throwFailure(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
  }
}

BriefingDetail _detail(api.GetBriefing200ResponseData value) {
  final summary = BriefingSummary(
    id: value.id,
    type: _detailType(value.briefingType),
    periodStart: _dateOnly(value.periodStart),
    periodEnd: _dateOnly(value.periodEnd),
    generatedAt: _utcTimestamp(value.generatedAt),
    generation: value.generation,
    sourceSequence: value.sourceSequence,
    readAt: value.readAt == null ? null : _utcTimestamp(value.readAt!),
  );
  _validateSummary(summary);
  final ordinals = <int>{};
  final sections =
      value.sections
          .map((section) {
            if (section.sectionType != 'summary' ||
                section.schemaVersion != 1 ||
                section.ordinal <= 0 ||
                !ordinals.add(section.ordinal) ||
                section.payload.length != 2 ||
                section.payload['source_sequence'] is! int ||
                section.payload['disclosure'] is! String) {
              _terminal();
            }
            final sourceSequence = section.payload['source_sequence']! as int;
            final disclosure = (section.payload['disclosure']! as String)
                .trim();
            if (sourceSequence != summary.sourceSequence ||
                disclosure.isEmpty) {
              _terminal();
            }
            return BriefingSummarySection(
              ordinal: section.ordinal,
              sourceSequence: sourceSequence,
              disclosure: disclosure,
            );
          })
          .toList(growable: false)
        ..sort((left, right) => left.ordinal.compareTo(right.ordinal));
  if (sections.isEmpty) _terminal();
  return BriefingDetail(summary: summary, sections: sections);
}

BriefingSummary _summary(api.ListBriefings200ResponseDataInner value) {
  final result = BriefingSummary(
    id: value.id,
    type: _listType(value.briefingType),
    periodStart: _dateOnly(value.periodStart),
    periodEnd: _dateOnly(value.periodEnd),
    generatedAt: _utcTimestamp(value.generatedAt),
    generation: value.generation,
    sourceSequence: value.sourceSequence,
    readAt: value.readAt == null ? null : _utcTimestamp(value.readAt!),
  );
  _validateSummary(result);
  return result;
}

void _validateSummary(BriefingSummary value) {
  _requireUuid(value.id);
  if (value.generation <= 0 ||
      value.sourceSequence < 0 ||
      value.periodStart.isAfter(value.periodEnd) ||
      value.generatedAt.isAfter(
        DateTime.now().toUtc().add(const Duration(days: 1)),
      )) {
    _terminal();
  }
}

BriefingType _listType(
  api.ListBriefings200ResponseDataInnerBriefingTypeEnum value,
) => switch (value) {
  api.ListBriefings200ResponseDataInnerBriefingTypeEnum.daily =>
    BriefingType.daily,
  api.ListBriefings200ResponseDataInnerBriefingTypeEnum.weekly =>
    BriefingType.weekly,
  api.ListBriefings200ResponseDataInnerBriefingTypeEnum.moonCycle =>
    BriefingType.moonCycle,
  api.ListBriefings200ResponseDataInnerBriefingTypeEnum.unknownDefaultOpenApi =>
    throw const LoadFailure(LoadPhase.terminalFailure),
};

BriefingType _detailType(
  api.GetBriefing200ResponseDataBriefingTypeEnum value,
) => switch (value) {
  api.GetBriefing200ResponseDataBriefingTypeEnum.daily => BriefingType.daily,
  api.GetBriefing200ResponseDataBriefingTypeEnum.weekly => BriefingType.weekly,
  api.GetBriefing200ResponseDataBriefingTypeEnum.moonCycle =>
    BriefingType.moonCycle,
  api.GetBriefing200ResponseDataBriefingTypeEnum.unknownDefaultOpenApi =>
    throw const LoadFailure(LoadPhase.terminalFailure),
};

String? _typeValue(BriefingType? value) => switch (value) {
  BriefingType.daily => 'daily',
  BriefingType.weekly => 'weekly',
  BriefingType.moonCycle => 'moon_cycle',
  null => null,
};

DateTime _dateOnly(DateTime value) {
  if (value.hour != 0 ||
      value.minute != 0 ||
      value.second != 0 ||
      value.millisecond != 0 ||
      value.microsecond != 0) {
    _terminal();
  }
  return DateTime.utc(value.year, value.month, value.day);
}

DateTime _utcTimestamp(DateTime value) => value.toUtc();

void _requireUtcDate(DateTime? value, String field) {
  if (value == null) return;
  if (!value.isUtc ||
      value.hour != 0 ||
      value.minute != 0 ||
      value.second != 0 ||
      value.millisecond != 0 ||
      value.microsecond != 0) {
    throw LoadFailure(
      LoadPhase.terminalFailure,
      message: '$field must be a UTC date.',
    );
  }
}

void _requireUuid(String value) {
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value)) {
    _terminal();
  }
}

void _requireUniqueIds(Iterable<String> ids) {
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) _terminal();
  }
}

void _requirePage(bool hasMore, String? cursor) {
  if (hasMore != (cursor != null && cursor.isNotEmpty)) _terminal();
}

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

Never _terminal() => throw const LoadFailure(LoadPhase.terminalFailure);

Never _throwFailure(DioException error) {
  if (_ambiguous(error)) throw const OfflineException();
  throw ApiFailureMapper.map(error);
}

bool _ambiguous(DioException error) =>
    error.type == DioExceptionType.connectionError ||
    error.type == DioExceptionType.connectionTimeout ||
    error.type == DioExceptionType.receiveTimeout ||
    error.type == DioExceptionType.sendTimeout;
