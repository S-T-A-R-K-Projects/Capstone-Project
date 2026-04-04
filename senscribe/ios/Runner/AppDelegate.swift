import ActivityKit
import AVFoundation
import Flutter
import Speech
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    
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
}

@available(iOS 16.1, *)
private struct SenscribeLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        let status: String
        let startedAtMs: Int
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
