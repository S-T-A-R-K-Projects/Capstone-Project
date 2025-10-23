import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }
        
        setupMethodChannel(controller: controller)
        setupEventChannel(controller: controller)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func setupMethodChannel(controller: FlutterViewController) {
        methodChannel = FlutterMethodChannel(
            name: "com.senscribe/audio_classification",
            binaryMessenger: controller.binaryMessenger
        )
        
        methodChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handleMethodCall(call, result: result)
        }
    }
    
    private func setupEventChannel(controller: FlutterViewController) {
        eventChannel = FlutterEventChannel(
            name: "com.senscribe/audio_events",
            binaryMessenger: controller.binaryMessenger
        )
        
        eventChannel?.setStreamHandler(AudioEventStreamHandler())
    }
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initializeAudioClassification(result: result)
            
        case "startMonitoring":
            startMonitoring(result: result)
            
        case "stopMonitoring":
            stopMonitoring(result: result)
            
        case "isMonitoring":
            let isMonitoring = AudioClassificationManager.shared.getMonitoringStatus()
            result(isMonitoring)
            
        case "enableDirectionDetection":
            if let args = call.arguments as? [String: Any],
               let enable = args["enable"] as? Bool {
                AudioClassificationManager.shared.enableDirectionDetection(enable)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid argument", details: nil))
            }
            
        case "requestMicrophonePermission":
            requestMicrophonePermission(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func requestMicrophonePermission(result: @escaping FlutterResult) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                result(granted)
            }
        }
    }
    
    private func initializeAudioClassification(result: @escaping FlutterResult) {
        print("AppDelegate: Initializing audio classification...")
        
        // Try multiple paths to find the model
        var modelPath: String?
        
        // Path 1: Direct in bundle (if added to Xcode project)
        modelPath = Bundle.main.path(forResource: "yamnet", ofType: "tflite")
        if modelPath != nil {
            print("AppDelegate: Found model at path 1 (direct): \(modelPath!)")
        }
        
        // Path 2: Flutter assets
        if modelPath == nil {
            modelPath = Bundle.main.path(forResource: "yamnet", ofType: "tflite", inDirectory: "flutter_assets/assets/models")
            if modelPath != nil {
                print("AppDelegate: Found model at path 2 (flutter_assets): \(modelPath!)")
            }
        }
        
        // Path 3: In Frameworks (Flutter asset alternative)
        if modelPath == nil {
            modelPath = Bundle.main.path(forResource: "flutter_assets/assets/models/yamnet", ofType: "tflite")
            if modelPath != nil {
                print("AppDelegate: Found model at path 3 (frameworks): \(modelPath!)")
            }
        }
        
        // Debug: List all resources in bundle
        if modelPath == nil {
            print("AppDelegate: Model not found. Listing bundle contents:")
            if let resourcePath = Bundle.main.resourcePath {
                do {
                    let items = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                    print("AppDelegate: Bundle resources count: \(items.count)")
                    for item in items.prefix(10) {
                        print("  - \(item)")
                    }
                } catch {
                    print("AppDelegate: Error listing bundle: \(error)")
                }
            }
        }
        
        guard let finalPath = modelPath else {
            result(FlutterError(code: "MODEL_NOT_FOUND", message: "YAMNet model not found in bundle", details: nil))
            return
        }
        
        print("AppDelegate: Using model at: \(finalPath)")
        
        do {
            try AudioClassificationManager.shared.initialize(modelPath: finalPath)
            print("AppDelegate: Audio classification initialized successfully")
            result(nil)
        } catch {
            print("AppDelegate: Initialization error: \(error)")
            result(FlutterError(code: "INIT_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func startMonitoring(result: @escaping FlutterResult) {
        do {
            try AudioClassificationManager.shared.startMonitoring()
            result(nil)
        } catch {
            result(FlutterError(code: "START_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func stopMonitoring(result: @escaping FlutterResult) {
        AudioClassificationManager.shared.stopMonitoring()
        result(nil)
    }
}

class AudioEventStreamHandler: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        AlertManager.shared.setEventSink(events)
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        AlertManager.shared.removeEventSink()
        return nil
    }
}
