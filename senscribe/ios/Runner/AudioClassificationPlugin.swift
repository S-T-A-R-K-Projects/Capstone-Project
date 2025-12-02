import AVFoundation
import Flutter
import Foundation
import SoundAnalysis

class AudioClassificationPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, SNResultsObserving {
  private var audioEngine: AVAudioEngine?
  private var streamAnalyzer: SNAudioStreamAnalyzer?
  private var analysisRequest: SNClassifySoundRequest?
  private var analyzerQueue = DispatchQueue(label: "com.senscribe.audioAnalyzerQueue")
  private var eventSink: FlutterEventSink?
  private var isMonitoring = false
  private var lastIdentifier: String?
  private var lastEventDate = Date.distantPast
  private let throttleInterval: TimeInterval = 0.5
  private let confidenceThreshold: Double = 0.25

  static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(name: "senscribe/audio_classifier", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "senscribe/audio_classifier_events", binaryMessenger: registrar.messenger())
    let instance = AudioClassificationPlugin()
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      startClassification(result: result)
    case "stop":
      stopClassification()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    stopClassification()
    return nil
  }

  private func startClassification(result: @escaping FlutterResult) {
    if isMonitoring {
      result(nil)
      return
    }

    let session = AVAudioSession.sharedInstance()
    session.requestRecordPermission { [weak self] granted in
      guard let self else {
        result(FlutterError(code: "internal_error", message: "Plugin deallocated.", details: nil))
        return
      }

      DispatchQueue.main.async {
        guard granted else {
          result(FlutterError(code: "microphone_permission_denied", message: "Microphone permission is required.", details: nil))
          return
        }

        do {
          try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
          try session.setActive(true, options: .notifyOthersOnDeactivation)
          try self.configureAnalyzer()
          try self.startAudioEngine()
          self.isMonitoring = true
          self.lastIdentifier = nil
          self.lastEventDate = Date.distantPast
          self.eventSink?(["type": "status", "status": "started"])
          result(nil)
        } catch {
          result(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func stopClassification() {
    guard isMonitoring else { return }

    if let inputNode = audioEngine?.inputNode {
      inputNode.removeTap(onBus: 0)
    }
    audioEngine?.stop()
    streamAnalyzer = nil
    analysisRequest = nil
    audioEngine = nil
    isMonitoring = false

    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

    eventSink?(["type": "status", "status": "stopped"])
  }

  private func configureAnalyzer() throws {
    audioEngine = AVAudioEngine()
    guard let audioEngine else {
      throw NSError(domain: "AudioClassificationPlugin", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create audio engine."])
    }

    let inputNode = audioEngine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: 0)

    streamAnalyzer = SNAudioStreamAnalyzer(format: inputFormat)
    if #available(iOS 15.0, *) {
      analysisRequest = try SNClassifySoundRequest(classifierIdentifier: .version1)
    } else {
      throw NSError(
        domain: "AudioClassificationPlugin",
        code: -3,
        userInfo: [NSLocalizedDescriptionKey: "Built-in sound classification requires iOS 15 or newer."]
      )
    }

    guard let analysisRequest, let streamAnalyzer else {
      throw NSError(domain: "AudioClassificationPlugin", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to create sound analysis request."])
    }

    try streamAnalyzer.add(analysisRequest, withObserver: self)

    inputNode.removeTap(onBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) { [weak self] buffer, when in
      guard let self else { return }
      self.analyzerQueue.async {
        self.streamAnalyzer?.analyze(buffer, atAudioFramePosition: when.sampleTime)
      }
    }
  }

  private func startAudioEngine() throws {
    guard let audioEngine else { return }

    audioEngine.prepare()
    try audioEngine.start()
  }

  func request(_ request: SNRequest, didProduce result: SNResult) {
    guard let eventSink else { return }
    guard let classificationResult = result as? SNClassificationResult else { return }
    guard let classification = classificationResult.classifications.first else { return }

    let confidence = classification.confidence
    guard confidence >= confidenceThreshold else { return }

    let identifier = classification.identifier
    let now = Date()

    if identifier == lastIdentifier, now.timeIntervalSince(lastEventDate) < throttleInterval {
      return
    }

    lastIdentifier = identifier
    lastEventDate = now

    let payload: [String: Any] = [
      "type": "result",
      "label": identifier,
      "confidence": Double(confidence),
      "timestampMs": Int(now.timeIntervalSince1970 * 1000)
    ]

    DispatchQueue.main.async {
      eventSink(payload)
    }
  }

  func request(_ request: SNRequest, didFailWithError error: Error) {
    eventSink?(FlutterError(code: "analysis_failed", message: error.localizedDescription, details: nil))
  }

  func requestDidComplete(_ request: SNRequest) {
    // Notifies when audio analysis request completes. This typically won't fire for live audio, but reset throttle state.
    lastIdentifier = nil
    lastEventDate = Date.distantPast
  }
}
