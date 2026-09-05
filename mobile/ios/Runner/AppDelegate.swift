import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var timerChannel: FlutterMethodChannel?
  private var pendingWorkoutOpen = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let didLaunch = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    UNUserNotificationCenter.current().delegate = self
    KiloWatchConnectivityManager.shared.activate()
    return didLaunch
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound])
    } else {
      completionHandler([.alert, .sound])
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(name: "kilo.platform.timer", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    timerChannel = channel
    KiloWatchConnectivityManager.shared.onCompleteSet = { [weak self] completedSets in
      self?.timerChannel?.invokeMethod(
        "completeSetFromNotification",
        arguments: ["completedSets": completedSets]
      )
    }
    channel.setMethodCallHandler { call, result in
      if call.method == "showNotification" {
        let arguments = call.arguments as? [String: Any] ?? [:]
        let content = UNMutableNotificationContent()
        content.title = arguments["title"] as? String ?? "形域"
        content.body = arguments["body"] as? String ?? "你有一条新的训练消息"
        content.sound = .default
        UNUserNotificationCenter.current().add(
          UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        ) { error in
          DispatchQueue.main.async { result(error == nil ? nil : FlutterError(code: "notification_failed", message: error?.localizedDescription, details: nil)) }
        }
        return
      }
      if call.method == "configureNotifications" {
        let arguments = call.arguments as? [String: Any] ?? [:]
        let enabled = arguments["enabled"] as? Bool ?? false
        let center = UNUserNotificationCenter.current()
        if !enabled {
          center.removePendingNotificationRequests(withIdentifiers: ["kilo.daily.training.reminder"])
          center.removeDeliveredNotifications(withIdentifiers: ["kilo.daily.training.reminder"])
          result(true)
          return
        }
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
          guard granted else {
            DispatchQueue.main.async { result(false) }
            return
          }
          let content = UNMutableNotificationContent()
          content.title = "今天也为自己完成一次训练"
          content.body = "打开形域，记录今天的训练进度。"
          content.sound = .default
          var components = DateComponents()
          components.hour = 20
          let request = UNNotificationRequest(
            identifier: "kilo.daily.training.reminder",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
          )
          center.removePendingNotificationRequests(withIdentifiers: ["kilo.daily.training.reminder"])
          center.add(request) { error in
            DispatchQueue.main.async { result(error == nil) }
          }
        }
        return
      }
      if call.method == "getAppleWatchStatus" {
        result(KiloWatchConnectivityManager.shared.isPairedAndInstalled)
        return
      }
      if call.method == "consumePendingWorkoutOpen" {
        let pending = self.pendingWorkoutOpen
        self.pendingWorkoutOpen = false
        result(pending)
        return
      }
      if call.method == "consumePendingTimerActions" {
        if #available(iOS 16.1, *) {
          Task { @MainActor in
            var actions = KiloLiveActivityManager.shared.consumeSystemActions()
            if let completedSets = KiloWatchConnectivityManager.shared.consumeCompletedSets() {
              actions["completedSets"] = completedSets
            }
            result(actions)
          }
        } else {
          if let completedSets = KiloWatchConnectivityManager.shared.consumeCompletedSets() {
            result(["completedSets": completedSets])
          } else {
            result([:])
          }
        }
        return
      }
      let arguments = call.arguments as? [String: Any] ?? [:]
      let watch = KiloWatchConnectivityManager.shared
      switch call.method {
      case "startWorkout":
        watch.startWorkout(
          name: arguments["workoutName"] as? String ?? "自由训练",
          exercise: arguments["exercise"] as? String ?? "准备训练",
          exerciseSymbol: arguments["exerciseSymbol"] as? String ?? "figure.strengthtraining.traditional",
          completedSets: arguments["completedSets"] as? Int ?? 0,
          totalSets: arguments["totalSets"] as? Int ?? 0,
          nextRestSeconds: arguments["nextRestSeconds"] as? Int ?? 0
        )
      case "updateWorkoutState":
        watch.updateWorkout(
          exercise: arguments["exercise"] as? String ?? "准备训练",
          exerciseSymbol: arguments["exerciseSymbol"] as? String ?? "figure.strengthtraining.traditional",
          completedSets: arguments["completedSets"] as? Int ?? 0,
          totalSets: arguments["totalSets"] as? Int ?? 0,
          nextRestSeconds: arguments["nextRestSeconds"] as? Int ?? 0
        )
      case "startTimer", "updateTimer":
        watch.updateRest(
          exercise: arguments["exercise"] as? String ?? "组间休息",
          seconds: arguments["seconds"] as? Int ?? 0,
          endsAtEpochMs: (arguments["endsAtEpochMs"] as? NSNumber)?.int64Value
        )
      case "clearRest", "completeRest":
        watch.clearRest()
      case "pauseTimer":
        watch.pause()
      case "finishTimer":
        watch.finish()
      default:
        break
      }
      guard #available(iOS 16.1, *) else {
        result(nil)
        return
      }
      Task { @MainActor in
        let liveActivity = KiloLiveActivityManager.shared
        switch call.method {
        case "startWorkout":
          await liveActivity.startWorkout(
            name: arguments["workoutName"] as? String ?? "自由训练",
            elapsedSeconds: arguments["elapsedSeconds"] as? Int ?? 0,
            exercise: arguments["exercise"] as? String ?? "准备训练",
            completedSets: arguments["completedSets"] as? Int ?? 0,
            totalSets: arguments["totalSets"] as? Int ?? 0
          )
        case "updateWorkoutState":
          await liveActivity.updateWorkoutState(
            exercise: arguments["exercise"] as? String ?? "准备训练",
            completedSets: arguments["completedSets"] as? Int ?? 0,
            totalSets: arguments["totalSets"] as? Int ?? 0
          )
        case "startTimer", "updateTimer":
          await liveActivity.updateRest(
            exercise: arguments["exercise"] as? String ?? "组间休息",
            seconds: arguments["seconds"] as? Int ?? 0,
            endsAtEpochMs: (arguments["endsAtEpochMs"] as? NSNumber)?.int64Value
          )
        case "clearRest":
          await liveActivity.clearRest()
        case "completeRest":
          await liveActivity.completeRest()
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

  @discardableResult
  func handleWorkoutURL(_ url: URL) -> Bool {
    guard url.scheme?.lowercased() == "ember",
          url.host?.lowercased() == "training" else {
      return false
    }
    pendingWorkoutOpen = true
    timerChannel?.invokeMethod("openWorkoutFromSystem", arguments: nil)
    return true
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if handleWorkoutURL(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }
}
