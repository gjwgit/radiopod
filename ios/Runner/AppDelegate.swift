import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// The one Flutter engine for the life of the process.
  ///
  /// Created and run here, rather than implicitly by a storyboard's
  /// FlutterViewController, because CarPlay can launch RadioPod on its own
  /// with no phone window at all. In that case no view controller would ever
  /// be built, so no engine and no Dart would run, and the car would have no
  /// library to browse and nothing to play it with. Owning the engine here
  /// means Dart starts at launch whichever scene connects first, and the
  /// phone's SceneDelegate and the CarPlaySceneDelegate share it.
  lazy var flutterEngine = FlutterEngine(name: "radiopod")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)

    // Register the CarPlay channel before returning to the run loop, so it is
    // in place before Dart's main() can publish the library over it.
    CarPlayBridge.shared.attach(to: flutterEngine.binaryMessenger)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
