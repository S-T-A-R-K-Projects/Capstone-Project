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
