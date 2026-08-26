import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/features/onboarding/data/onboarding_draft_store.dart';
import 'package:ritual_investing_app/features/onboarding/domain/onboarding_draft.dart';

void main() {
  test(
    'restores an unexpired draft only for the current installation',
    () async {
      final storage = _MemoryProtectedStorage();
      final store = OnboardingDraftStore(
        storage: storage,
        installation: const FixedInstallationBinding('install-a'),
        now: () => DateTime.utc(2026, 8, 24, 12),
      );

      await store.save(_reviewedDraft());
      final result = await store.read();

      expect(result.status, DraftReadStatus.available);
      expect(result.draft, _reviewedDraft());
      expect(storage.values.keys, [OnboardingDraftStore.storageKey]);
    },
  );

  test('checks TTL on every read and erases an expired draft', () async {
    var now = DateTime.utc(2026, 8, 24, 12);
    final storage = _MemoryProtectedStorage();
    final store = OnboardingDraftStore(
      storage: storage,
      installation: const FixedInstallationBinding('install-a'),
      now: () => now,
      ttl: const Duration(hours: 1),
    );
    await store.save(_reviewedDraft());

    expect((await store.read()).status, DraftReadStatus.available);
    now = DateTime.utc(2026, 8, 24, 13, 1);
    expect((await store.read()).status, DraftReadStatus.expired);
    expect(storage.values, isEmpty);
  });

  test('corrupt and restored-install envelopes restart safely', () async {
    final storage = _MemoryProtectedStorage();
    storage.values[OnboardingDraftStore.storageKey] = '{not-json';
    final corrupt = OnboardingDraftStore(
      storage: storage,
      installation: const FixedInstallationBinding('install-a'),
      now: () => DateTime.utc(2026, 8, 24, 12),
    );

    expect((await corrupt.read()).status, DraftReadStatus.corrupted);
    expect(storage.values, isEmpty);

    await corrupt.save(_reviewedDraft());
    final restored = OnboardingDraftStore(
      storage: storage,
      installation: const FixedInstallationBinding('install-b'),
      now: () => DateTime.utc(2026, 8, 24, 12),
    );
    expect((await restored.read()).status, DraftReadStatus.orphaned);
    expect(storage.values, isEmpty);
  });

  test(
    'cache marker eviction fails closed and purges the protected draft',
    () async {
      final appContainer = await Directory.systemTemp.createTemp(
        'ritual-onboarding-install-',
      );
      addTearDown(() async {
        if (await appContainer.exists()) {
          await appContainer.delete(recursive: true);
        }
      });
      final storage = _MemoryProtectedStorage();
      final installed = OnboardingDraftStore(
        storage: storage,
        installation: AppContainerInstallationBinding(
          cacheDirectoryProvider: () async => appContainer,
        ),
        now: () => DateTime.utc(2026, 8, 24, 12),
      );

      await installed.save(_reviewedDraft());

      expect(storage.values.keys, [OnboardingDraftStore.storageKey]);
      await appContainer.delete(recursive: true);
      await appContainer.create();

      final reinstalled = OnboardingDraftStore(
        storage: storage,
        installation: AppContainerInstallationBinding(
          cacheDirectoryProvider: () async => appContainer,
        ),
        now: () => DateTime.utc(2026, 8, 24, 12),
      );
      expect((await reinstalled.read()).status, DraftReadStatus.orphaned);
      expect(storage.values, isEmpty);
    },
  );

  test('locked storage preserves the draft for retry', () async {
    final storage = _MemoryProtectedStorage()
      ..readError = const ProtectedStorageLocked();
    final store = OnboardingDraftStore(
      storage: storage,
      installation: const FixedInstallationBinding('install-a'),
      now: () => DateTime.utc(2026, 8, 24, 12),
    );

    expect((await store.read()).status, DraftReadStatus.locked);
    expect(storage.deleteCalls, 0);
  });

  test(
    'rejects impossible, future, timestamp, and out-of-range dates',
    () async {
      final invalidDates = [
        '2026-02-31',
        '2026-08-25',
        '1899-12-31',
        '1994-05-14T00:00:00.000Z',
      ];
      for (final birthDate in invalidDates) {
        final storage = _MemoryProtectedStorage();
        _writeEnvelope(
          storage,
          _reviewedDraft()
              .copyWith(
                astrologyEnabled: true,
                birthDate: DateTime.utc(1994, 5, 14),
              )
              .toJson()
            ..['birth_date'] = birthDate,
        );
        final store = _store(storage);

        expect(
          (await store.read()).status,
          DraftReadStatus.corrupted,
          reason: birthDate,
        );
        expect(storage.values, isEmpty, reason: birthDate);
      }
    },
  );

  test(
    'rejects inconsistent astrology data and unknown enum answers',
    () async {
      final invalidDrafts = <Map<String, Object?>>[
        _reviewedDraft().toJson()..['birth_date'] = '1994-05-14',
        _reviewedDraft().copyWith(astrologyEnabled: true).toJson(),
        _reviewedDraft().toJson()..['risk'] = 'invented',
        _reviewedDraft().toJson()..['ritual_interests'] = ['invented'],
      ];
      for (final draft in invalidDrafts) {
        final storage = _MemoryProtectedStorage();
        _writeEnvelope(storage, draft);

        expect(
          (await _store(storage).read()).status,
          DraftReadStatus.corrupted,
        );
        expect(storage.values, isEmpty);
      }
    },
  );
}

OnboardingDraftStore _store(_MemoryProtectedStorage storage) =>
    OnboardingDraftStore(
      storage: storage,
      installation: const FixedInstallationBinding('install-a'),
      now: () => DateTime.utc(2026, 8, 24, 12),
    );

void _writeEnvelope(
  _MemoryProtectedStorage storage,
  Map<String, Object?> draft,
) {
  storage.values[OnboardingDraftStore.storageKey] = jsonEncode({
    'schema_version': 2,
    'installation_id': 'install-a',
    'written_at': '2026-08-24T11:00:00.000Z',
    'expires_at': '2026-08-25T11:00:00.000Z',
    'draft': draft,
  });
}

OnboardingDraft _reviewedDraft() => OnboardingDraft(
  experience: InvestingExperience.newToInvesting,
  goal: InvestmentGoal.longTermGrowth,
  horizon: InvestmentHorizon.long,
  risk: RiskComfort.moderate,
  contributionRhythm: ContributionRhythm.monthly,
  ritualLanguage: RitualLanguage.practical,
  ritualFamiliarity: RitualFamiliarity.newToRitual,
  ritualInterests: const {
    RitualInterest.practicalResearch,
    RitualInterest.tarot,
  },
  astrologyEnabled: false,
  birthDate: null,
  termsAccepted: true,
  privacyAccepted: true,
  demoAccepted: true,
);

class _MemoryProtectedStorage implements ProtectedStorage {
  final Map<String, String> values = {};
  Object? readError;
  int deleteCalls = 0;

  @override
  Future<void> delete(String key) async {
    deleteCalls++;
    values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll() async {
    final error = readError;
    if (error != null) throw error;
    return Map.of(values);
  }

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
