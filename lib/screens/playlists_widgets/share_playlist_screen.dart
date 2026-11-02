/// Share playlist screen — grant other Solid users access to a playlist.
///
// Time-stamp: <Monday 2026-11-02 12:00:00 +1100 Tony Chen>
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

import 'package:solidpod/solidpod.dart' show filenameToResourceUrl;
import 'package:solidui/solidui.dart';

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/widgets/error_dialog.dart';

/// Open the sharing page for [playlist].
///
/// The page is solidui's [GrantPermissionUi], as NotePod uses for a note:
/// enter a WebID, choose read or more, and the recipient is granted access
/// and sent a notification. A recipient whose Pod has not been set up for
/// RadioPod cannot be granted access, since the file's key is shared through
/// their RadioPod public key, and they are offered an invitation instead.
///
/// The shared copy of the playlist is written first, so the recipient always
/// receives the playlist as it stands now.

Future<void> sharePlaylist(
  BuildContext context,
  AppProvider provider,
  Playlist playlist,
) async {
  if (provider.source != LibrarySource.pod) {
    await showErrorDialog(
      context,
      title: 'Log in to share',
      message:
          'Playlists are shared from your Solid Pod. Log in, so that your '
          'library is on your Pod, and then share ${playlist.name}.',
      icon: Icons.info_outline,
    );

    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          SharePlaylistScreen(provider: provider, playlist: playlist),
    ),
  );
}

/// Write the shared copy of [playlist], then offer [GrantPermissionUi] on it.

class SharePlaylistScreen extends StatefulWidget {
  const SharePlaylistScreen({
    super.key,
    required this.provider,
    required this.playlist,
  });

  final AppProvider provider;
  final Playlist playlist;

  @override
  State<SharePlaylistScreen> createState() => _SharePlaylistScreenState();
}

class _SharePlaylistScreenState extends State<SharePlaylistScreen> {
  /// The full URL of the shared copy once written. NotePod hands
  /// [GrantPermissionUi] the note's URL, and so does this.

  late final Future<String> _resourceUrl = _prepare();

  Future<String> _prepare() async {
    final saved = await widget.provider.saveSharedPlaylist(widget.playlist);
    if (saved.error != null) throw Exception(saved.error);

    return filenameToResourceUrl(fileName: saved.fileName);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Share ${widget.playlist.name}')),
    body: FutureBuilder<String>(
      future: _resourceUrl,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'The playlist could not be written to your Pod for '
                'sharing.\n\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return GrantPermissionUi(
          showAppBar: false,
          resourceNames: [snapshot.data!],
          resourceDisplayName: widget.playlist.name,
          inviteConfig: inviteOthersConfig,
        );
      },
    ),
  );
}
