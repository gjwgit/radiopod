// RadioPcmPlugin — the Flutter end of the station reader.
//
// Copyright (C) 2026, Togaware Pty Ltd
//
// Licensed under the GNU General Public License, Version 3 (the "License");
//
// License: https://opensource.org/license/gpl-3-0

#if os(iOS)
  import Flutter
#else
  import FlutterMacOS
#endif
import Foundation

/// Streams a station's audio to Dart as Float32List events.
///
/// Listening to `radio_pcm/samples` with `{url, sampleRate}` opens a reader;
/// cancelling closes it. One reader at a time: a new listen replaces the old
/// one, and anything the old one still had in flight is dropped.

public class RadioPcmPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var reader: StationReader?

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif

    let instance = RadioPcmPlugin()
    FlutterEventChannel(name: "radio_pcm/samples", binaryMessenger: messenger)
      .setStreamHandler(instance)

    let methods = FlutterMethodChannel(name: "radio_pcm/methods", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(instance, channel: methods)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "excludeFromBackup":
      // A downloaded speech model can always be fetched again, so it has no
      // business in the device's iCloud backup.

      guard let path = (call.arguments as? [String: Any])?["path"] as? String else {
        result(FlutterError(code: "bad-args", message: "No path given.", details: nil))
        return
      }
      var url = URL(fileURLWithPath: path)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      do {
        try url.setResourceValues(values)
        result(nil)
      } catch {
        result(FlutterError(code: "io", message: error.localizedDescription, details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    guard
      let args = arguments as? [String: Any],
      let address = args["url"] as? String,
      let url = URL(string: address)
    else {
      return FlutterError(code: "bad-args", message: "No stream address given.", details: nil)
    }
    let sampleRate = (args["sampleRate"] as? NSNumber)?.doubleValue ?? 16000

    reader?.stop()
    sink = events

    var created: StationReader?
    created = StationReader(url: url, sampleRate: sampleRate) { [weak self] event in
      DispatchQueue.main.async {
        // Ignore a late event from a reader that has since been replaced.

        guard let self, let sink = self.sink, self.reader === created else { return }
        switch event {
        case .samples(let data):
          sink(FlutterStandardTypedData(float32: data))
        case .failed(let code, let message):
          sink(FlutterError(code: code, message: message, details: nil))
        case .ended:
          sink(FlutterEndOfEventStream)
        }
      }
    }
    reader = created
    created?.start()

    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    reader?.stop()
    reader = nil
    sink = nil

    return nil
  }
}
