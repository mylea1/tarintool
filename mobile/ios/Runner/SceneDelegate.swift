import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    guard let url = connectionOptions.urlContexts.first?.url,
          let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
      return
    }
    appDelegate.handleWorkoutURL(url)
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    guard let url = URLContexts.first?.url,
          let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
      return
    }
    appDelegate.handleWorkoutURL(url)
  }
}
