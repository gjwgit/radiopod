/// CaptionPanel — live captions under whichever screen is showing.
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <https://opensource.org/license/gpl-3-0>.
///
/// Authors: Tony Chen

library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:gap/gap.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/captions/caption_service.dart';
import 'package:radiopod/services/captions/speech_model.dart';
import 'package:radiopod/services/player.dart';

/// Puts the caption panel beneath [child] while captions are on.
///
/// BENEATH, NOT OVER. A floating now-playing bar was tried once and hid the
/// last station in the list; the panel takes its own space instead, and the
/// list simply gets shorter while it is showing. The child keeps its place
/// in the tree either way, so switching captions on does not lose the
/// screen's scroll position.

class CaptionArea extends StatelessWidget {
  final Widget child;

  const CaptionArea({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final captions = CaptionService.instance;
    if (!captions.supported) return child;

    return ValueListenableBuilder<bool>(
      valueListenable: captions.active,
      builder: (context, on, _) => Column(
        children: [
          Expanded(child: child),
          if (on) const CaptionPanel(),
        ],
      ),
    );
  }
}

/// Switch captions on or off, asking first if a model must be downloaded.
///
/// The model is the one the station on air needs. A station in a language
/// captions cannot do has its CC button greyed out, and tapping it only
/// says why.

Future<void> toggleCaptions(BuildContext context) async {
  final captions = CaptionService.instance;
  if (captions.active.value) return captions.disable();

  final station = Player.handler.currentStation.valueOrNull;
  final model = speechModelFor(station);
  if (model == null) {
    showCaptionsUnavailable(context, station);

    return;
  }

  if (await captions.isModelInstalled(model)) {
    unawaited(captions.enable());

    return;
  }

  if (!context.mounted) return;
  if (await confirmModelDownload(context, model)) {
    unawaited(captions.enable(approved: model));
  }
}

/// Say why captions cannot be had for [station].

void showCaptionsUnavailable(BuildContext context, Station? station) {
  final language = station?.language?.trim() ?? '';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        language.isEmpty
            ? 'Captions need to know what language a station broadcasts in, '
                  'and this one does not say. They are available for English '
                  'and Chinese stations.'
            : 'Captions are available for English and Chinese stations, not '
                  'yet for $language.',
      ),
    ),
  );
}

/// Ask before fetching [model], saying how big it is and where it goes.

Future<bool> confirmModelDownload(
  BuildContext context,
  SpeechModel model,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.closed_caption),
      title: Text('Download the ${model.language} speech model?'),
      content: Text(
        'Captions are made on this device, so nothing you listen to is '
        'sent anywhere to be transcribed.\n\n'
        'For this station RadioPod needs a ${model.language} speech '
        'recognition model of ${model.sizeLabel}, downloaded once from '
        '${model.host}. You may prefer to wait for Wi-Fi. The model stays on '
        'this device until you remove it under Settings.\n\n'
        'While captions are on, RadioPod opens a second connection to the '
        'station to listen with, which roughly doubles the data the station '
        'uses.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Download'),
        ),
      ],
    ),
  );

  return ok == true;
}

class CaptionPanel extends StatefulWidget {
  const CaptionPanel({super.key});

  @override
  State<CaptionPanel> createState() => _CaptionPanelState();
}

class _CaptionPanelState extends State<CaptionPanel> {
  /// Showing the whole transcript rather than the last couple of lines.

  bool _expanded = false;

  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final captions = CaptionService.instance;

    return Material(
      color: cs.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: captions,
          builder: (context, _) => AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context, cs, captions),
                  _body(context, cs, captions),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, ColorScheme cs, CaptionService c) {
    final station = c.supported
        ? Player.handler.currentStation.valueOrNull?.name
        : null;
    final canExpand = c.status == CaptionStatus.listening && c.lines.isNotEmpty;

    return Row(
      children: [
        Icon(Icons.closed_caption, size: 18, color: cs.primary),
        const Gap(8),
        Expanded(
          child: Text(
            station == null ? 'Live captions' : 'Live captions · $station',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        if (canExpand)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: _expanded ? 'Show less' : 'Show the whole transcript',
            icon: Icon(_expanded ? Icons.expand_more : Icons.expand_less),
            onPressed: () => setState(() => _expanded = !_expanded),
          ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Turn captions off',
          icon: const Icon(Icons.close),
          onPressed: c.disable,
        ),
      ],
    );
  }

  Widget _body(BuildContext context, ColorScheme cs, CaptionService c) {
    final text = Theme.of(context).textTheme;
    final quiet = text.bodyMedium?.copyWith(color: cs.onSurfaceVariant);

    switch (c.status) {
      case CaptionStatus.needsModel:
        final model = c.model;

        return Padding(
          padding: const EdgeInsets.only(right: 12, top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This station needs the ${model?.language} speech model '
                '(${model?.sizeLabel}), downloaded once from ${model?.host}.',
                style: quiet,
              ),
              const Gap(8),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.download),
                label: const Text('Download'),
                onPressed: c.downloadModel,
              ),
            ],
          ),
        );

      case CaptionStatus.downloading:
        final p = c.progress ?? 0;

        return Padding(
          padding: const EdgeInsets.only(right: 12, top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Downloading the ${c.model?.language} speech model… '
                '${(p * 100).floor()}%',
                style: quiet,
              ),
              const Gap(8),
              LinearProgressIndicator(value: p),
            ],
          ),
        );

      case CaptionStatus.starting:
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const Gap(10),
              Text('Getting ready to listen…', style: quiet),
            ],
          ),
        );

      case CaptionStatus.waiting:
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Captions will begin when a station is playing.',
            style: quiet,
          ),
        );

      case CaptionStatus.failed:
        return Padding(
          padding: const EdgeInsets.only(top: 4, right: 12),
          child: Text(
            c.message ?? 'Captions stopped.',
            style: text.bodyMedium?.copyWith(color: cs.error),
          ),
        );

      case CaptionStatus.off:
        return const SizedBox.shrink();

      case CaptionStatus.listening:
        return _expanded ? _transcript(context, cs, c) : _latest(cs, c);
    }
  }

  /// The last settled line, faded, and the one being spoken now.

  Widget _latest(ColorScheme cs, CaptionService c) {
    final text = Theme.of(context).textTheme;
    final previous = c.partial.isEmpty
        ? (c.lines.length > 1 ? c.lines[c.lines.length - 2] : null)
        : (c.lines.isEmpty ? null : c.lines.last);
    final now = c.currentLine;

    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (previous != null)
            Text(
              previous,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          const Gap(2),
          Text(
            now.isEmpty ? 'Listening…' : now,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: now.isEmpty
                ? text.bodyLarge?.copyWith(color: cs.onSurfaceVariant)
                : text.titleMedium?.copyWith(color: cs.onSurface),
          ),
        ],
      ),
    );
  }

  /// Everything heard on this station so far, newest at the bottom, and
  /// selectable so a quote can be copied.

  Widget _transcript(BuildContext context, ColorScheme cs, CaptionService c) {
    final lines = [...c.lines, if (c.partial.isNotEmpty) c.partial];
    final height = MediaQuery.sizeOf(context).height * 0.4;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height),
      child: Scrollbar(
        controller: _scroll,
        child: ListView.builder(
          controller: _scroll,
          reverse: true,
          shrinkWrap: true,
          padding: const EdgeInsets.only(right: 12, top: 4),
          itemCount: lines.length,
          itemBuilder: (context, i) {
            final line = lines[lines.length - 1 - i];
            final live = i == 0 && c.partial.isNotEmpty;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SelectableText(
                line,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: live ? cs.primary : cs.onSurface),
              ),
            );
          },
        ),
      ),
    );
  }
}
