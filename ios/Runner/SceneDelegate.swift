import Flutter
import UIKit

/// The phone's window scene.
///
/// Builds its FlutterViewController on the engine AppDelegate already runs,
/// rather than letting Main.storyboard create one with an implicit engine of
/// its own. Two engines would mean two copies of the app, each with its own
/// audio player, and the car would drive a different one from the phone.
class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    if let windowScene = scene as? UIWindowScene,
      let appDelegate = UIApplication.shared.delegate as? AppDelegate
    {
      let window = UIWindow(windowScene: windowScene)
      window.rootViewController = FlutterViewController(
        engine: appDelegate.flutterEngine, nibName: nil, bundle: nil)
      self.window = window
      window.makeKeyAndVisible()
    }

    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }
}
