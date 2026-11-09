import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    guard let url = URLContexts.first?.url else { return }
    let path = url.path
    if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
      appDelegate.handleIncomingFile(path: path)
    }
  }
}
