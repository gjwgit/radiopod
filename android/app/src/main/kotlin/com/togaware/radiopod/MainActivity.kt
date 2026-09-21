package com.togaware.radiopod

import com.ryanheise.audioservice.AudioServiceActivity

// Extends AudioServiceActivity rather than FlutterActivity so that the UI and
// the background media service share one FlutterEngine. Android Auto can start
// the service with no activity at all, and the user can then open the app;
// both must talk to the same Dart isolate and so to the same AudioPlayer.

class MainActivity : AudioServiceActivity()
