/// CaptionsSection — the speech model behind live captions.
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

import 'package:flutter/material.dart';

import 'package:gap/gap.dart';

import 'package:radiopod/services/captions/caption_service.dart';
import 'package:radiopod/services/captions/speech_model.dart';

/// Says what captions download and where it goes, and offers to remove each
/// model.
///
/// Hidden where captions are not offered, so a platform without them does
/// not describe a feature it cannot use.

class CaptionsSection extends StatefulWidget {
  const CaptionsSection({super.key});

  @override
  State<CaptionsSection> createState() => _CaptionsSectionState();
}

class _CaptionsSectionState extends State<CaptionsSection> {
  final _captions = CaptionService.instance;
  late Future<Set<String>> _installed = _check();

  CaptionStatus? _lastStatus;

  @override
  void initState() {
    super.initState();

    // A download finishing, or captions being switched off after one,
    // changes the answer.

    _captions.addListener(_refresh);
  }

  @override
  void dispose() {
    _captions.removeListener(_refresh);
    super.dispose();
  }

  Future<Set<String>> _check() async => {
    for (final m in speechModels)
      if (await _captions.isModelInstalled(m)) m.id,
  };

  void _refresh() {
    if (_captions.status == _lastStatus) return;
    _lastStatus = _captions.status;
    setState(() => _installed = _check());
  }

  Future<void> _delete(SpeechModel model) async {
    await _captions.deleteModel(model);
    if (mounted) setState(() => _installed = _check());
  }

  @override
  Widget build(BuildContext context) {
    if (!_captions.supported) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(32),
        Text('Live captions', style: Theme.of(context).textTheme.titleLarge),
        const Gap(8),
        Text(
          'While a station is playing, the CC button in the toolbar shows '
          'what is being said. Speech is recognised on this device by '
          'sherpa-onnx; no audio or text is sent anywhere to be transcribed. '
          'The words also take the place of the station name on the lock '
          'screen, with the station and programme on the line beneath.',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        const Gap(8),
        Text(
          'The speech model is chosen by the language the station lists: '
          'English stations use the English model, and Chinese or Mandarin '
          'stations the Chinese and English one. For stations in any other '
          'language, or that list none, the CC button is greyed out.',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        const Gap(12),
        FutureBuilder<Set<String>>(
          future: _installed,
          builder: (context, snapshot) {
            final installed = snapshot.data ?? const <String>{};

            return Column(
              children: [
                for (final model in speechModels)
                  _modelRow(cs, model, installed.contains(model.id)),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _modelRow(ColorScheme cs, SpeechModel model, bool installed) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Icon(
              installed ? Icons.check_circle : Icons.cloud_download,
              size: 20,
              color: installed ? cs.primary : cs.onSurfaceVariant,
            ),
            const Gap(8),
            Expanded(
              child: Text(
                installed
                    ? '${model.language} speech model downloaded '
                          '(${model.sizeLabel}).'
                    : '${model.language} speech model not downloaded. It is '
                          'fetched (${model.sizeLabel}) the first time it is '
                          'needed.',
              ),
            ),
            if (installed)
              TextButton(
                onPressed: () => _delete(model),
                child: const Text('Remove'),
              ),
          ],
        ),
      );
}
