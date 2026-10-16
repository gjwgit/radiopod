/// OPML — the list of podcast subscriptions every podcast app reads.
///
// Time-stamp: <Friday 2026-10-16 06:00:00 +1100 Graham Williams>
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
/// Authors: Graham Williams

library;

import 'package:xml/xml.dart';

import 'package:radiopod/utils/playlist_file.dart';

/// One podcast as an OPML file lists it: a title, its feed, and perhaps its
/// web site. Like [PlaylistEntry], all the file carries.

typedef OpmlFeed = ({String title, String url, String? homepage});

/// File extensions offered in the OPML file picker.

const opmlExtensions = ['opml', 'xml'];

/// Read the podcasts listed in an OPML file, in file order.
///
/// 20261016 gjw Written for the files podcast apps actually export rather
/// than the specification alone. Feeds are often grouped into folders, so
/// outlines are read at any depth and the folders themselves (outlines with
/// no `xmlUrl`) are passed over. The attribute is matched without regard to
/// case, since `xmlurl` turns up. The title falls back from `text` to
/// `title` to the feed's host. Only http and https feeds are kept, and a feed
/// listed twice is kept once.
///
/// Throws [FormatException] when [xml] is not OPML at all.

List<OpmlFeed> parseOpml(String xml) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(xml);
  } on XmlException catch (e) {
    throw FormatException('Not an OPML file: ${e.message}');
  }
  if (doc.rootElement.localName.toLowerCase() != 'opml') {
    throw const FormatException('Not an OPML file.');
  }

  final seen = <String>{};
  final feeds = <OpmlFeed>[];
  for (final o in doc.findAllElements('outline')) {
    final url = _attr(o, 'xmlUrl');
    if (url == null || !_isWeb(url) || !seen.add(url)) continue;
    final homepage = _attr(o, 'htmlUrl');
    feeds.add((
      title: _attr(o, 'text') ?? _attr(o, 'title') ?? nameFromUrl(url),
      url: url,
      homepage: homepage != null && _isWeb(homepage) ? homepage : null,
    ));
  }

  return feeds;
}

/// Write [feeds] as an OPML 2.0 subscription list titled [title].
///
/// Each outline carries both `text`, which the specification requires, and
/// `title`, which some readers look for instead.

String writeOpml(List<OpmlFeed> feeds, {String title = 'Podcasts'}) {
  final b = XmlBuilder()..processing('xml', 'version="1.0" encoding="UTF-8"');
  b.element(
    'opml',
    attributes: {'version': '2.0'},
    nest: () {
      b.element('head', nest: () => b.element('title', nest: title));
      b.element(
        'body',
        nest: () {
          for (final f in feeds) {
            b.element(
              'outline',
              attributes: {
                'type': 'rss',
                'text': f.title,
                'title': f.title,
                'xmlUrl': f.url,
                if (f.homepage != null) 'htmlUrl': f.homepage!,
              },
            );
          }
        },
      );
    },
  );

  return '${b.buildDocument().toXmlString(pretty: true)}\n';
}

/// An attribute by name, ignoring case, trimmed, or null when blank.

String? _attr(XmlElement e, String name) {
  final lower = name.toLowerCase();
  for (final a in e.attributes) {
    if (a.localName.toLowerCase() == lower) {
      final v = a.value.trim();

      return v.isEmpty ? null : v;
    }
  }

  return null;
}

bool _isWeb(String url) {
  final scheme = Uri.tryParse(url)?.scheme.toLowerCase();

  return scheme == 'http' || scheme == 'https';
}
