import ActivityKit
import AVFoundation
import AudioToolbox
import CoreHaptics
import Flutter
import Speech
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var backgroundTasks: [Int: UIBackgroundTaskIdentifier] = [:]
    private var nextBackgroundTaskToken: Int = 1
    private static var hapticEngine: CHHapticEngine?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Suppress unsatisfiable constraint warnings from native platform views
        UserDefaults.standard.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // UIScene lifecycle: plugin registration for the new launch sequence
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AudioClassificationPlugin") {
            AudioClassificationPlugin.register(with: registrar)
        }

        if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SenScribePermissionBridge") {
            let channel = FlutterMethodChannel(
                name: "senscribe/ios_permissions",
                binaryMessenger: registrar.messenger()
            )

            channel.setMethodCallHandler { [weak self] call, result in
                guard let self else {
                    result(FlutterError(code: "unavailable", message: "AppDelegate unavailable", details: nil))
                    return
                }

                switch call.method {
                case "getPermissionStatuses":
                    self.handleGetPermissionStatuses(result: result)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }

        if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SenScribeLiveActivityBridge") {
            let channel = FlutterMethodChannel(
                name: "senscribe/ios_live_activities",
                binaryMessenger: registrar.messenger()
            )

            channel.setMethodCallHandler { call, result in
                guard #available(iOS 16.1, *) else {
                    result(nil)
                    return
                }

                switch call.method {
                case "createOrUpdate":
                    guard let payload = call.arguments as? [String: Any] else {
                        result(FlutterError(code: "invalid_args", message: "Missing live activity payload.", details: nil))
                        return
                    }
                    SenscribeLiveActivityManager.createOrUpdate(payload: payload, result: result)
                case "endAll":
                    SenscribeLiveActivityManager.endAll(result: result)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }

        if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SenScribeIosRuntimeBridge") {
            let channel = FlutterMethodChannel(
                name: "senscribe/ios_runtime",
                binaryMessenger: registrar.messenger()
            )

            channel.setMethodCallHandler { [weak self] call, result in
                guard let self else {
                    result(FlutterError(code: "unavailable", message: "AppDelegate unavailable", details: nil))
                    return
                }

                switch call.method {
                case "beginBackgroundTask":
                    let args = call.arguments as? [String: Any]
                    let name = args?["name"] as? String ?? "senscribe_background_task"
                    result(self.beginBackgroundTask(named: name))
                case "endBackgroundTask":
                    guard
                        let args = call.arguments as? [String: Any],
                        let taskId = args["taskId"] as? Int
                    else {
                        result(FlutterError(code: "invalid_args", message: "Missing task id.", details: nil))
                        return
                    }
                    self.endBackgroundTask(taskId: taskId)
                    result(nil)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }

        if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SenScribeAlertFeedbackBridge") {
            let channel = FlutterMethodChannel(
                name: "senscribe/alert_feedback",
                binaryMessenger: registrar.messenger()
            )

            channel.setMethodCallHandler { call, result in
                switch call.method {
                case "playTriggerAlertFeedback":
                    Self.playTriggerAlertFeedback()
                    result(nil)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }
    }

    private func handleGetPermissionStatuses(result: @escaping FlutterResult) {
        let microphoneStatus = microphonePermissionStatus()
        let speechStatus = speechRecognitionPermissionStatus()

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            result([
                "microphone": microphoneStatus,
                "speechRecognition": speechStatus,
                "notifications": self.notificationPermissionStatus(from: settings.authorizationStatus),
            ])
        }
    }

    private func microphonePermissionStatus() -> String {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            return "granted"
        case .denied:
            return "denied"
        case .undetermined:
            return "notDetermined"
        @unknown default:
            return "denied"
        }
    }

    private func speechRecognitionPermissionStatus() -> String {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return "granted"
        case .denied:
            return "denied"
        case .restricted:
            return "restricted"
        case .notDetermined:
            return "notDetermined"
        @unknown default:
            return "denied"
        }
    }

    private func notificationPermissionStatus(from status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .ephemeral, .provisional:
            return "granted"
        case .denied:
            return "denied"
        case .notDetermined:
            return "notDetermined"
        @unknown default:
            return "denied"
        }
    }

    private func beginBackgroundTask(named name: String) -> Int {
        let token = nextBackgroundTaskToken
        nextBackgroundTaskToken += 1

        var identifier: UIBackgroundTaskIdentifier = .invalid
        identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            self?.endBackgroundTask(taskId: token)
        }

        backgroundTasks[token] = identifier
        return token
    }

    private func endBackgroundTask(taskId: Int) {
        guard let identifier = backgroundTasks.removeValue(forKey: taskId) else {
            return
        }
        UIApplication.shared.endBackgroundTask(identifier)
    }

    private static func playTriggerAlertFeedback() {
        DispatchQueue.main.async {
            let audioSession = AVAudioSession.sharedInstance()
            if #available(iOS 13.0, *) {
                do {
                    try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
                } catch {
                    // Fall back to the best available haptic path below.
                }
            }

            if #available(iOS 13.0, *),
               CHHapticEngine.capabilitiesForHardware().supportsHaptics {
                do {
                    try prepareHapticEngineIfNeeded(audioSession: audioSession)
                    try playCoreHapticsPattern()
                    return
                } catch {
                    Self.hapticEngine = nil
                }
            }

            let notificationGenerator = UINotificationFeedbackGenerator()
            notificationGenerator.prepare()
            notificationGenerator.notificationOccurred(.warning)
            let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
            impactGenerator.prepare()
            impactGenerator.impactOccurred(intensity: 1.0)
            AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        }
    }

    @available(iOS 13.0, *)
    private static func prepareHapticEngineIfNeeded(audioSession: AVAudioSession) throws {
        if hapticEngine == nil {
            let engine = try CHHapticEngine(audioSession: audioSession)
            engine.isAutoShutdownEnabled = true
            engine.stoppedHandler = { _ in
                Self.hapticEngine = nil
            }
            engine.resetHandler = {
                do {
                    try engine.start()
                } catch {
                    Self.hapticEngine = nil
                }
            }
            hapticEngine = engine
        }

        try hapticEngine?.start()
    }

    @available(iOS 13.0, *)
    private static func playCoreHapticsPattern() throws {
        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.85),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55),
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                ],
                relativeTime: 0.14
            ),
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35),
                ],
                relativeTime: 0.3,
                duration: 0.18
            ),
        ]

        let pattern = try CHHapticPattern(events: events, parameters: [])
        let player = try hapticEngine?.makePlayer(with: pattern)
        try player?.start(atTime: 0)
    }
}

@available(iOS 16.1, *)
private struct SenscribeLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        let status: String
        let startedAtMs: Int
        let lastDetectedIdentifier: String
        let lastDetectedLabel: String
        let lastDetectedConfidencePercent: Int
        let lastDetectedAtMs: Int
    }

    let id: String
}

@available(iOS 16.1, *)
private enum SenscribeLiveActivityManager {
    static let activityId = "sound-recognition-status"

    static func createOrUpdate(payload: [String: Any], result: @escaping FlutterResult) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            result(nil)
            return
        }

        let state = SenscribeLiveActivityAttributes.ContentState(
            status: payload["status"] as? String ?? "listening",
            startedAtMs: payload["startedAtMs"] as? Int ?? Int(Date().timeIntervalSince1970 * 1000),
            lastDetectedIdentifier: payload["lastDetectedIdentifier"] as? String ?? "",
            lastDetectedLabel: payload["lastDetectedLabel"] as? String ?? "",
            lastDetectedConfidencePercent: payload["lastDetectedConfidencePercent"] as? Int ?? -1,
            lastDetectedAtMs: payload["lastDetectedAtMs"] as? Int ?? -1
        )

        Task {
            let existingActivity = Activity<SenscribeLiveActivityAttributes>.activities.first {
                $0.attributes.id == activityId &&
                $0.activityState != .dismissed &&
                $0.activityState != .ended
            }

            do {
                if let existingActivity {
                    if #available(iOS 16.2, *) {
                        let content = ActivityContent(state: state, staleDate: nil)
                        await existingActivity.update(content, alertConfiguration: nil)
                    } else {
                        await existingActivity.update(using: state)
                    }
                } else {
                    let attributes = SenscribeLiveActivityAttributes(id: activityId)
                    if #available(iOS 16.2, *) {
                        let content = ActivityContent(state: state, staleDate: nil)
                        _ = try Activity.request(
                            attributes: attributes,
                            content: content,
                            pushType: nil
                        )
                    } else {
                        _ = try Activity.request(
                            attributes: attributes,
                            contentState: state,
                            pushType: nil
                        )
                    }
                }
                result(nil)
            } catch {
                result(
                    FlutterError(
                        code: "live_activity_error",
                        message: "Failed to create or update iOS Live Activity.",
                        details: error.localizedDescription
                    )
                )
            }
        }
    }

    static func endAll(result: @escaping FlutterResult) {
        Task {
            for activity in Activity<SenscribeLiveActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            result(nil)
        }
    }
}
