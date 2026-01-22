import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, GenAIWrapperDelegate {
    private var eventSink: FlutterEventSink?
    
    // Channel names for LLM communication
    private let LLM_METHOD_CHANNEL = "com.example.senscribe/llm"
    private let LLM_EVENT_CHANNEL = "com.example.senscribe/llm_tokens"
    
    // Key for storing security-scoped bookmark
    private let BOOKMARK_KEY = "model_folder_bookmark"
    
    var genAIWrapper: GenAIWrapper?
    
    // Track the currently accessed security-scoped URL
    private var accessedURL: URL?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Register existing plugins first
        GeneratedPluginRegistrant.register(with: self)
        
        // Register AudioClassificationPlugin
        if let registrar = self.registrar(forPlugin: "AudioClassificationPlugin") {
            AudioClassificationPlugin.register(with: registrar)
        }
        
        // Initialize GenAI wrapper
        genAIWrapper = GenAIWrapper()
        genAIWrapper?.delegate = self
        
        // Get the binary messenger from the registrar instead of rootViewController
        guard let registrar = self.registrar(forPlugin: "LLMPlugin") else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }
        let binaryMessenger = registrar.messenger()
        
        // Setup LLM Method Channel
        let llmMethodChannel = FlutterMethodChannel(
            name: LLM_METHOD_CHANNEL,
            binaryMessenger: binaryMessenger
        )
        llmMethodChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard let self = self else { return }
            switch call.method {
            case "loadModel":
                if let path = call.arguments as? String {
                    self.handleLoadModel(path: path, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Model path is required", details: nil))
                }
            case "summarize":
                self.handleSummarize(call: call, result: result)
            case "unloadModel":
                self.handleUnloadModel(result: result)
            case "isModelLoaded":
                result(self.genAIWrapper?.isLoaded() ?? false)
            case "validateAndBookmarkFolder":
                if let args = call.arguments as? [String: Any],
                   let path = args["path"] as? String,
                   let files = args["files"] as? [String] {
                    self.handleValidateAndBookmark(path: path, requiredFiles: files, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Path and files are required", details: nil))
                }
            case "hasValidBookmark":
                self.handleHasValidBookmark(result: result)
            case "clearBookmark":
                self.handleClearBookmark(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        // Setup LLM Event Channel for token streaming
        let llmEventChannel = FlutterEventChannel(
            name: LLM_EVENT_CHANNEL,
            binaryMessenger: binaryMessenger
        )
        llmEventChannel.setStreamHandler(self)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // MARK: - LLM Method Handlers
    
    /// Validate folder contents and create a security-scoped bookmark for persistent access
    private func handleValidateAndBookmark(path: String, requiredFiles: [String], result: @escaping FlutterResult) {
        NSLog("AppDelegate: Validating folder at path: \(path)")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let folderURL = URL(fileURLWithPath: path)
            
            // Start accessing security-scoped resource
            let hasAccess = folderURL.startAccessingSecurityScopedResource()
            NSLog("AppDelegate: Security scoped access: \(hasAccess)")
            
            defer {
                if hasAccess {
                    folderURL.stopAccessingSecurityScopedResource()
                }
            }
            
            // Check for missing files
            var missingFiles: [String] = []
            let fileManager = FileManager.default
            
            for fileName in requiredFiles {
                let fileURL = folderURL.appendingPathComponent(fileName)
                if !fileManager.fileExists(atPath: fileURL.path) {
                    missingFiles.append(fileName)
                    NSLog("AppDelegate: Missing file: \(fileName)")
                } else {
                    NSLog("AppDelegate: Found file: \(fileName)")
                }
            }
            
            if !missingFiles.isEmpty {
                DispatchQueue.main.async {
                    result([
                        "success": false,
                        "missingFiles": missingFiles
                    ])
                }
                return
            }
            
            // All files present - create security-scoped bookmark for persistent access
            do {
                let bookmarkData = try folderURL.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                
                // Save bookmark to UserDefaults
                UserDefaults.standard.set(bookmarkData, forKey: self.BOOKMARK_KEY)
                NSLog("AppDelegate: Bookmark saved successfully")
                
                DispatchQueue.main.async {
                    result([
                        "success": true,
                        "path": path
                    ])
                }
            } catch {
                NSLog("AppDelegate: Failed to create bookmark: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    result([
                        "success": false,
                        "error": "Failed to save folder access: \(error.localizedDescription)"
                    ])
                }
            }
        }
    }
    
    /// Check if we have a valid bookmark saved (without accessing files)
    private func handleHasValidBookmark(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { result(false) }
                return
            }
            
            guard let bookmarkData = UserDefaults.standard.data(forKey: self.BOOKMARK_KEY) else {
                NSLog("AppDelegate: No bookmark found")
                DispatchQueue.main.async { result(false) }
                return
            }
            
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                NSLog("AppDelegate: Bookmark resolves to: \(url.path), stale: \(isStale)")
                DispatchQueue.main.async { result(!isStale) }
            } catch {
                NSLog("AppDelegate: Failed to resolve bookmark: \(error.localizedDescription)")
                DispatchQueue.main.async { result(false) }
            }
        }
    }
    
    /// Clear the saved bookmark
    private func handleClearBookmark(result: @escaping FlutterResult) {
        UserDefaults.standard.removeObject(forKey: BOOKMARK_KEY)
        NSLog("AppDelegate: Bookmark cleared")
        result(true)
    }
    
    /// Resolve the saved bookmark and return the accessible URL
    private func resolveBookmarkedURL() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: BOOKMARK_KEY) else {
            NSLog("AppDelegate: No bookmark found")
            return nil
        }
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                NSLog("AppDelegate: Bookmark is stale, may need to re-select folder")
            }
            
            return url
        } catch {
            NSLog("AppDelegate: Failed to resolve bookmark: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func handleLoadModel(path: String, result: @escaping FlutterResult) {
        NSLog("AppDelegate: Loading model from path: \(path)")
        
        guard let wrapper = self.genAIWrapper else {
            result(FlutterError(code: "NO_WRAPPER", message: "GenAI wrapper not initialized", details: nil))
            return
        }
        
        // Load on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try wrapper.load(path)
                DispatchQueue.main.async {
                    NSLog("AppDelegate: Model loaded successfully")
                    result("LOADED")
                }
            } catch {
                DispatchQueue.main.async {
                    NSLog("AppDelegate: Model load failed: \(error.localizedDescription)")
                    result(FlutterError(
                        code: "LOAD_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }
    
    private func handleSummarize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let prompt = args["prompt"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Prompt is required", details: nil))
            return
        }
        
        let params = args["params"] as? [String: Double] ?? [:]
        
        NSLog("AppDelegate: Starting summarization with prompt length: \(prompt.count)")
        
        // Run inference on background thread to avoid blocking main thread
        // iOS watchdog kills apps that block main thread for too long
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let paramsDict: [String: NSNumber] = params.mapValues { NSNumber(value: $0) }
            let success = self?.genAIWrapper?.inference(prompt, withParams: paramsDict) ?? false
            
            DispatchQueue.main.async {
                NSLog("AppDelegate: Summarization completed with success: \(success)")
                
                if success {
                    result("DONE")
                } else {
                    result(FlutterError(
                        code: "SUMMARIZATION_FAILED",
                        message: "Text summarization failed",
                        details: nil
                    ))
                }
            }
        }
    }
    
    private func handleUnloadModel(result: FlutterResult) {
        NSLog("AppDelegate: Unloading model")
        genAIWrapper?.unload()
        result("UNLOADED")
    }
    
    // MARK: - GenAIWrapperDelegate
    
    func didGenerateToken(_ token: String) {
        // Dispatch to main thread since inference runs on background thread
        DispatchQueue.main.async { [weak self] in
            if let eventSink = self?.eventSink {
                eventSink(token)
            }
        }
    }
}

// MARK: - FlutterStreamHandler

extension AppDelegate: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        NSLog("AppDelegate: Event stream started listening")
        eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NSLog("AppDelegate: Event stream cancelled")
        eventSink = nil
        return nil
    }
}
