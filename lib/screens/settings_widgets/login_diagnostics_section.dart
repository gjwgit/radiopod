/// LoginDiagnosticsSection — what happened the last time you tried to log in.
///
// Time-stamp: <Monday 2026-09-29 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gap/gap.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';

import 'package:radiopod/services/oidc_event_log.dart';
import 'package:radiopod/widgets/app_snack_bar.dart';

/// Shows the native sign-in browser's own account of a login attempt.
///
/// 20260929 gjw This is here, on a screen reachable by tapping Continue,
/// precisely because it is needed by someone who could NOT log in. A tester on
/// TestFlight has no console and no Xcode; asking them what they saw gets an
/// answer about the user interface, not about whether the redirect arrived.
/// This gives them something to screenshot.
///
/// Hidden entirely until there is something to show, so the ordinary Settings
/// screen is not cluttered by a section that says "nothing happened".

class LoginDiagnosticsSection extends StatefulWidget {
  const LoginDiagnosticsSection({super.key});

  @override
  State<LoginDiagnosticsSection> createState() =>
      _LoginDiagnosticsSectionState();
}

class _LoginDiagnosticsSectionState extends State<LoginDiagnosticsSection> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final log = OidcEventLog.instance;

    if (log.isEmpty) return const SizedBox.shrink();

    final text = log.entries.join('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(32),
        Text(
          'Login diagnostics',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Gap(8),
        Text(
          'What the sign-in browser reported on this device. It is kept in '
          'memory only, is never written to your Pod or sent anywhere, and '
          'holds no addresses or sign-in codes. Useful to copy into a bug '
          'report when a login will not complete.',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        const Gap(12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        const Gap(8),
        Row(
          children: [
            MarkdownTooltip(
              message: '''

              **Copy.** Tap to copy the log above to the clipboard, ready to
              paste into an email or a bug report.

              ''',
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) {
                    showPositiveSnackBar(context, 'Login diagnostics copied.');
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
            ),
            const Gap(12),
            MarkdownTooltip(
              message: '''

              **Clear.** Tap to empty the log, so the next login attempt is
              recorded on its own and is easier to read.

              ''',
              child: OutlinedButton.icon(
                onPressed: () => setState(OidcEventLog.instance.clear),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
