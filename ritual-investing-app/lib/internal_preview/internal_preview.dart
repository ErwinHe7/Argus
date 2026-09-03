import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/ritual_investing_app.dart';
import 'internal_preview_services.dart';

const internalPreviewQueryParameter = 'preview';

/// The internal preview is opt-in and web-only. Normal URLs continue through
/// production runtime configuration and Google authentication.
bool shouldLaunchInternalPreview(Uri uri, {bool? isWebOverride}) =>
    (isWebOverride ?? kIsWeb) &&
    uri.queryParameters[internalPreviewQueryParameter] == '1';

Widget createInternalPreviewApp() => RitualInvestingApp(
  container: createInternalPreviewDependencyContainer(
    includeU9: true,
    includeSearch: true,
  ),
  allowSelfServiceSignup: false,
  appBuilder: _buildInternalPreviewFrame,
);

Widget _buildInternalPreviewFrame(BuildContext context, Widget? child) {
  final media = MediaQuery.of(context);
  final colors = Theme.of(context).colorScheme;
  return ColoredBox(
    color: colors.surface,
    child: Column(
      children: [
        Semantics(
          container: true,
          liveRegion: true,
          label: 'Internal preview. Sample data only. Changes are not saved.',
          excludeSemantics: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.tertiaryContainer,
              border: Border(bottom: BorderSide(color: colors.outlineVariant)),
            ),
            child: Padding(
              padding: EdgeInsets.only(top: media.padding.top),
              child: SizedBox(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 18,
                          color: colors.onTertiaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            constraints.maxWidth < 460
                                ? 'INTERNAL PREVIEW · NOT SAVED'
                                : 'INTERNAL PREVIEW · SAMPLE DATA · CHANGES ARE NOT SAVED',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: colors.onTertiaryContainer,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ],
    ),
  );
}
