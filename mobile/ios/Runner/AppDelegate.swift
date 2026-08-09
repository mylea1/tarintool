import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(name: "kilo.platform.timer", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard #available(iOS 16.1, *) else {
        result(nil)
        return
      }
      let arguments = call.arguments as? [String: Any] ?? [:]
      Task { @MainActor in
        let liveActivity = KiloLiveActivityManager.shared
        switch call.method {
        case "startWorkout":
          await liveActivity.startWorkout(
            name: arguments["workoutName"] as? String ?? "自由训练",
            elapsedSeconds: arguments["elapsedSeconds"] as? Int ?? 0
          )
        case "startTimer", "updateTimer":
          await liveActivity.updateRest(
            exercise: arguments["exercise"] as? String ?? "组间休息",
            seconds: arguments["seconds"] as? Int ?? 0
          )
        case "clearRest":
          await liveActivity.clearRest()
        case "pauseTimer":
          await liveActivity.pause()
        case "finishTimer":
          await liveActivity.finish()
        default:
          result(FlutterMethodNotImplemented)
          return
        }
        result(nil)
      }
    }
  }
}
