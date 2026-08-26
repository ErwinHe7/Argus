import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/bootstrap/app_runtime.dart';
import 'package:ritual_investing_app/core/bootstrap/member_shell_runtime.dart';

import 'support/fixture_services.dart';

void main() {
  test(
    'completed member runtime starts at the shell and owns its scope directly',
    () async {
      final production = fixtureContainer();
      addTearDown(production.dispose);
      await production.bootstrap();
      final bootstrap = production.memberBootstrap!;
      final scope = production.featureScope!;

      final runtime = MemberShellRuntime.completed(
        bootstrap: bootstrap,
        featureScope: scope,
      );

      expect(runtime.entryGate, MemberEntryGate.member);
      expect(runtime.memberBootstrap, same(bootstrap));
      expect(runtime.featureScope, same(scope));

      await runtime.ensureBranchLoaded(MemberBranch.ritual);
      expect(runtime.dailyRitualController.state.value, isNotNull);

      runtime.dispose();
      expect(scope.isDisposed, isTrue);
    },
  );

  test('production container delegates active shell ownership', () async {
    final container = fixtureContainer();
    addTearDown(container.dispose);

    await container.bootstrap();

    expect(container.memberShellRuntime, isA<MemberShellRuntime>());
    expect(
      container.memberShellRuntime.featureScope,
      same(container.featureScope),
    );
    expect(container.entryGate, MemberEntryGate.member);

    await container.logout();

    expect(container.memberShellRuntime.featureScope, isNull);
    expect(container.entryGate, MemberEntryGate.signedOut);
  });
}
