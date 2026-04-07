import AVFoundation
import CoreML
import Flutter
import Foundation
import SoundAnalysis

#if canImport(CreateML)
import CreateML
#endif

private struct CustomSoundProfileRecord: Codable {
  var id: String
  var name: String
  var enabled: Bool
  var status: String
  var targetSamplePaths: [String]
  var backgroundSamplePaths: [String]
  var createdAt: String
  var updatedAt: String
  var lastError: String?

  var hasEnoughSamples: Bool {
    targetSamplePaths.count >= 5 && !backgroundSamplePaths.isEmpty
  }

  func toDictionary() -> [String: Any] {
    [
      "id": id,
      "name": name,
      "enabled": enabled,
      "status": status,
      "targetSamplePaths": targetSamplePaths,
      "backgroundSamplePaths": backgroundSamplePaths,
      "createdAt": createdAt,
      "updatedAt": updatedAt,
      "lastError": lastError as Any,
    ]
  }
}

class AudioClassificationPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, SNResultsObserving {
  private let analyzerQueue = DispatchQueue(label: "com.senscribe.audioAnalyzerQueue")
  private let trainingQueue = DispatchQueue(label: "com.senscribe.customModelTrainingQueue", qos: .userInitiated)
  private let dateFormatter = ISO8601DateFormatter()
  private let backgroundLabel = "__background__"
  private let recordingDuration: TimeInterval = 5.0
  private let builtInConfidenceThreshold: Double = 0.25
  private let customConfidenceThreshold: Double = 0.94
  private let builtInThrottleInterval: TimeInterval = 10.0
  private let customThrottleInterval: TimeInterval = 10.0
  private let customMinimumSignalRMS: Float = 0.008
  private let requiredCustomConsecutiveMatches = 2

  private var audioEngine: AVAudioEngine?
  private var streamAnalyzer: SNAudioStreamAnalyzer?
  private var builtInRequest: SNClassifySoundRequest?
  private var customRequest: SNClassifySoundRequest?
  private var audioRecorder: AVAudioRecorder?
  private var eventSink: FlutterEventSink?
  private var isMonitoring = false
  private var isCapturingSample = false
  private var resumeMonitoringAfterCapture = false
  private var lastEmittedEventKey: String?
  private var lastEmittedEventDate: Date?
  private var latestInputRMS: Float = 0
  private var latestInputPeak: Float = 0
  private var lastCustomCandidateIdentifier: String?
  private var lastCustomCandidateCount = 0

  private var supportsLocalTraining: Bool {
    #if canImport(CreateML)
    return true
    #else
    return false
    #endif
  }

  private lazy var customSoundsRootURL: URL = {
    let root = applicationSupportDirectory().appendingPathComponent("custom_sounds", isDirectory: true)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)
    return root
  }()

  private lazy var profilesFileURL: URL = {
    customSoundsRootURL.appendingPathComponent("profiles.json")
  }()

  private lazy var modelSourceURL: URL = {
    customSoundsRootURL.appendingPathComponent("custom_sound_model.mlmodel")
  }()

  private lazy var compiledModelURL: URL = {
    customSoundsRootURL.appendingPathComponent("custom_sound_model.mlmodelc", isDirectory: true)
  }()

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
    case "loadCustomSounds":
      result(loadProfiles().map { $0.toDictionary() })
    case "captureSample":
      captureSample(call, result: result)
    case "trainOrRebuildCustomModel":
      trainOrRebuildCustomModel(result: result)
    case "deleteCustomSound":
      deleteCustomSound(call, result: result)
    case "setCustomSoundEnabled":
      setCustomSoundEnabled(call, result: result)
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
    return nil
  }

  private func startClassification(result: @escaping FlutterResult) {
    if isMonitoring {
      result(nil)
      return
    }

    requestMicrophonePermission { [weak self] granted in
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
          try self.configureAudioSession()
          try self.startMonitoringSession()
          self.isMonitoring = true
          self.lastEmittedEventKey = nil
          self.lastEmittedEventDate = nil
          self.sendStatus("started")
          result(nil)
        } catch {
          result(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func stopClassification() {
    internalStopClassification(shouldSendStatus: true, deactivateSession: true)
  }

  private func internalStopClassification(shouldSendStatus: Bool, deactivateSession: Bool) {
    if let inputNode = audioEngine?.inputNode {
      inputNode.removeTap(onBus: 0)
    }

    audioEngine?.stop()
    streamAnalyzer = nil
    builtInRequest = nil
    customRequest = nil
    audioEngine = nil
    isMonitoring = false
    lastEmittedEventKey = nil
    lastEmittedEventDate = nil
    lastCustomCandidateIdentifier = nil
    lastCustomCandidateCount = 0

    if deactivateSession {
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    if shouldSendStatus {
      sendStatus("stopped")
    }
  }

  private func configureAudioSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(
      .playAndRecord,
      mode: .measurement,
      options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]
    )
    try session.setPreferredIOBufferDuration(0.02)
    try session.setActive(true, options: .notifyOthersOnDeactivation)
  }

  private func startMonitoringSession() throws {
    audioEngine = AVAudioEngine()
    guard let audioEngine else {
      throw NSError(domain: "AudioClassificationPlugin", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create audio engine."])
    }

    let inputNode = audioEngine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: 0)
    let analyzer = SNAudioStreamAnalyzer(format: inputFormat)
    streamAnalyzer = analyzer

    if #available(iOS 15.0, *) {
      let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
      builtInRequest = request
      try analyzer.add(request, withObserver: self)
    } else {
      throw NSError(
        domain: "AudioClassificationPlugin",
        code: -3,
        userInfo: [NSLocalizedDescriptionKey: "Built-in sound classification requires iOS 15 or newer."]
      )
    }

    if let customAnalysisRequest = try makeCustomAnalysisRequestIfAvailable() {
      customRequest = customAnalysisRequest
      try analyzer.add(customAnalysisRequest, withObserver: self)
    } else {
      customRequest = nil
    }

    inputNode.removeTap(onBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) { [weak self] buffer, when in
      guard let self else { return }
      self.analyzerQueue.async {
        self.updateInputLevels(from: buffer)
        self.streamAnalyzer?.analyze(buffer, atAudioFramePosition: when.sampleTime)
      }
    }

    audioEngine.prepare()
    try audioEngine.start()
  }

  @available(iOS 15.0, *)
  private func makeCustomAnalysisRequestIfAvailable() throws -> SNClassifySoundRequest? {
    guard FileManager.default.fileExists(atPath: compiledModelURL.path) else {
      return nil
    }

    let model = try MLModel(contentsOf: compiledModelURL)
    return try SNClassifySoundRequest(mlModel: model)
  }

  private func restartMonitoringIfNeeded() {
    guard isMonitoring else { return }

    DispatchQueue.main.async {
      do {
        try self.configureAudioSession()
        self.internalStopClassification(shouldSendStatus: false, deactivateSession: false)
        try self.startMonitoringSession()
        self.isMonitoring = true
        self.sendStatus("reloaded")
      } catch {
        self.eventSink?(FlutterError(code: "reload_failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func captureSample(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let soundId = args["soundId"] as? String,
          let name = args["name"] as? String,
          let sampleKind = args["sampleKind"] as? String else {
      result(FlutterError(code: "invalid_args", message: "Missing sound capture arguments.", details: nil))
      return
    }

    let sampleIndex = (args["sampleIndex"] as? Int) ?? 0
    if isCapturingSample {
      result(FlutterError(code: "capture_in_progress", message: "Another custom sound recording is already in progress.", details: nil))
      return
    }

    var profiles = loadProfiles()
    let now = isoTimestamp()
    let profileIndex = profiles.firstIndex(where: { $0.id == soundId })
    var profile = profileIndex.map { profiles[$0] } ?? CustomSoundProfileRecord(
      id: soundId,
      name: name,
      enabled: true,
      status: "draft",
      targetSamplePaths: [],
      backgroundSamplePaths: [],
      createdAt: now,
      updatedAt: now,
      lastError: nil
    )

    profile.name = name
    profile.status = "recording"
    profile.updatedAt = now
    profile.lastError = nil
    profiles = upsertProfile(profile, in: profiles)
    saveProfiles(profiles)

    if isMonitoring {
      resumeMonitoringAfterCapture = true
      internalStopClassification(shouldSendStatus: false, deactivateSession: true)
    }

    requestMicrophonePermission { [weak self] granted in
      guard let self else {
        result(FlutterError(code: "internal_error", message: "Plugin deallocated.", details: nil))
        return
      }

      DispatchQueue.main.async {
        guard granted else {
          self.completeCaptureFailure(soundId: soundId, error: "Microphone permission is required.", flutterResult: result)
          return
        }

        do {
          try self.configureRecordingSession()
          let outputURL = try self.outputFileURL(for: soundId, sampleKind: sampleKind, sampleIndex: sampleIndex)
          try? FileManager.default.removeItem(at: outputURL)

          let recorder = try AVAudioRecorder(url: outputURL, settings: [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
          ])
          recorder.isMeteringEnabled = false
          recorder.prepareToRecord()
          guard recorder.record() else {
            throw NSError(domain: "AudioClassificationPlugin", code: -9, userInfo: [NSLocalizedDescriptionKey: "Unable to start sample recording."])
          }

          self.audioRecorder = recorder
          self.isCapturingSample = true

          DispatchQueue.main.asyncAfter(deadline: .now() + self.recordingDuration) { [weak self] in
            self?.finishCapture(
              soundId: soundId,
              sampleKind: sampleKind,
              fileURL: outputURL,
              flutterResult: result
            )
          }
        } catch {
          self.completeCaptureFailure(soundId: soundId, error: error.localizedDescription, flutterResult: result)
        }
      }
    }
  }

  private func configureRecordingSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
    try session.setActive(true, options: .notifyOthersOnDeactivation)
  }

  private func finishCapture(
    soundId: String,
    sampleKind: String,
    fileURL: URL,
    flutterResult: @escaping FlutterResult
  ) {
    audioRecorder?.stop()
    audioRecorder = nil
    isCapturingSample = false

    var profiles = loadProfiles()
    guard var profile = profiles.first(where: { $0.id == soundId }) else {
      flutterResult(FlutterError(code: "missing_profile", message: "Custom sound profile not found after recording.", details: nil))
      resumeMonitoringIfNecessary()
      return
    }

    profile.targetSamplePaths = sampleURLs(for: soundId, sampleKind: "target").map(\.path)
    profile.backgroundSamplePaths = sampleURLs(for: soundId, sampleKind: "background").map(\.path)
    profile.status = "draft"
    profile.updatedAt = isoTimestamp()
    profile.lastError = nil

    profiles = upsertProfile(profile, in: profiles)
    saveProfiles(profiles)
    flutterResult(profile.toDictionary())
    resumeMonitoringIfNecessary()
  }

  private func completeCaptureFailure(
    soundId: String,
    error: String,
    flutterResult: @escaping FlutterResult
  ) {
    audioRecorder?.stop()
    audioRecorder = nil
    isCapturingSample = false

    var profiles = loadProfiles()
    if var profile = profiles.first(where: { $0.id == soundId }) {
      profile.status = "failed"
      profile.updatedAt = isoTimestamp()
      profile.lastError = error
      profiles = upsertProfile(profile, in: profiles)
      saveProfiles(profiles)
    }

    flutterResult(FlutterError(code: "capture_failed", message: error, details: nil))
    resumeMonitoringIfNecessary()
  }

  private func resumeMonitoringIfNecessary() {
    guard resumeMonitoringAfterCapture else { return }
    resumeMonitoringAfterCapture = false
    startClassification(result: { _ in })
  }

  private func trainOrRebuildCustomModel(result: @escaping FlutterResult) {
    guard supportsLocalTraining else {
      let message = "Custom sound training is unavailable in this build environment. Apple does not ship CreateML for the iOS simulator SDK, so train on a physical iPhone running iOS 17 or newer."
      var profiles = loadProfiles()
      profiles = profiles.map { profile in
        var updated = profile
        if updated.enabled && updated.hasEnoughSamples {
          updated.status = "failed"
          updated.updatedAt = self.isoTimestamp()
          updated.lastError = message
        }
        return updated
      }
      saveProfiles(profiles)
      result(profiles.map { $0.toDictionary() })
      return
    }

    #if canImport(CreateML)
    trainingQueue.async {
      var profiles = self.loadProfiles()
      let eligibleIndices = profiles.indices.filter { index in
        profiles[index].enabled && profiles[index].hasEnoughSamples
      }

      if eligibleIndices.isEmpty {
        self.clearPersistedCustomModel()
        profiles = profiles.map { profile in
          var updated = profile
          if updated.status == "training" {
            updated.status = "draft"
          }
          updated.lastError = nil
          return updated
        }
        self.saveProfiles(profiles)
        self.restartMonitoringIfNeeded()
        result(profiles.map { $0.toDictionary() })
        return
      }

      for index in eligibleIndices {
        profiles[index].status = "training"
        profiles[index].updatedAt = self.isoTimestamp()
        profiles[index].lastError = nil
      }
      self.saveProfiles(profiles)

      do {
        let trainingData = try self.buildTrainingData(from: profiles)
        guard trainingData.keys.count >= 2 else {
          throw NSError(domain: "AudioClassificationPlugin", code: -10, userInfo: [NSLocalizedDescriptionKey: "Training requires 5 custom sound samples and 1 background calibration sample."])
        }

        let classifier = try MLSoundClassifier(
          trainingData: .filesByLabel(trainingData)
        )
        try self.persistCustomModel(classifier)

        profiles = self.loadProfiles().map { profile in
          var updated = profile
          if updated.enabled && updated.hasEnoughSamples {
            updated.status = "ready"
            updated.updatedAt = self.isoTimestamp()
            updated.lastError = nil
          }
          return updated
        }
        self.saveProfiles(profiles)
        self.restartMonitoringIfNeeded()
        result(profiles.map { $0.toDictionary() })
      } catch {
        profiles = self.loadProfiles().map { profile in
          var updated = profile
          if updated.enabled && updated.hasEnoughSamples {
            updated.status = "failed"
            updated.updatedAt = self.isoTimestamp()
            updated.lastError = error.localizedDescription
          }
          return updated
        }
        self.saveProfiles(profiles)
        result(profiles.map { $0.toDictionary() })
      }
    }
    #else
    result(loadProfiles().map { $0.toDictionary() })
    #endif
  }

  private func deleteCustomSound(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let soundId = args["soundId"] as? String else {
      result(FlutterError(code: "invalid_args", message: "Missing sound id.", details: nil))
      return
    }

    let profileDirectory = profileDirectoryURL(for: soundId)
    try? FileManager.default.removeItem(at: profileDirectory)

    let profiles = loadProfiles().filter { $0.id != soundId }
    saveProfiles(profiles)
    restartMonitoringIfNeeded()
    result(nil)
  }

  private func setCustomSoundEnabled(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let soundId = args["soundId"] as? String,
          let enabled = args["enabled"] as? Bool else {
      result(FlutterError(code: "invalid_args", message: "Missing sound enable arguments.", details: nil))
      return
    }

    var profiles = loadProfiles()
    guard var profile = profiles.first(where: { $0.id == soundId }) else {
      result(FlutterError(code: "missing_profile", message: "Custom sound profile not found.", details: nil))
      return
    }

    profile.enabled = enabled
    profile.updatedAt = isoTimestamp()
    if !enabled {
      profile.lastError = nil
    }

    profiles = upsertProfile(profile, in: profiles)
    saveProfiles(profiles)
    result(profile.toDictionary())
  }

  func request(_ request: SNRequest, didProduce result: SNResult) {
    guard let eventSink else { return }
    guard let classificationResult = result as? SNClassificationResult else { return }
    guard let classification = classificationResult.classifications.first else { return }

    let identifier = classification.identifier
    let confidence = Double(classification.confidence)

    let isCustomRequest = request === customRequest
    let threshold = isCustomRequest ? customConfidenceThreshold : builtInConfidenceThreshold
    guard confidence >= threshold else { return }
    if isCustomRequest && identifier == backgroundLabel {
      lastCustomCandidateIdentifier = nil
      lastCustomCandidateCount = 0
      return
    }

    if isCustomRequest {
      guard latestInputRMS >= customMinimumSignalRMS ||
          latestInputPeak >= customMinimumSignalRMS * 3 else {
        lastCustomCandidateIdentifier = nil
        lastCustomCandidateCount = 0
        return
      }

      if lastCustomCandidateIdentifier == identifier {
        lastCustomCandidateCount += 1
      } else {
        lastCustomCandidateIdentifier = identifier
        lastCustomCandidateCount = 1
      }

      guard lastCustomCandidateCount >= requiredCustomConsecutiveMatches else {
        return
      }
    }

    let source = isCustomRequest ? "custom" : "builtIn"
    let throttleInterval = isCustomRequest ? customThrottleInterval : builtInThrottleInterval
    let throttleKey = "\(source):\(identifier)"
    let now = Date()
    if let lastEventDate = lastEmittedEventDate,
       lastEmittedEventKey == throttleKey,
       now.timeIntervalSince(lastEventDate) < throttleInterval {
      return
    }
    lastEmittedEventKey = throttleKey
    lastEmittedEventDate = now

    var payload: [String: Any] = [
      "type": "result",
      "label": identifier,
      "confidence": confidence,
      "source": source,
      "timestampMs": Int(now.timeIntervalSince1970 * 1000),
    ]

    if isCustomRequest,
       let customSoundId = loadProfiles().first(where: { $0.name == identifier })?.id {
      payload["customSoundId"] = customSoundId
    }

    DispatchQueue.main.async {
      eventSink(payload)
    }
  }

  func request(_ request: SNRequest, didFailWithError error: Error) {
    eventSink?(FlutterError(code: "analysis_failed", message: error.localizedDescription, details: nil))
  }

  func requestDidComplete(_ request: SNRequest) {
    lastEmittedEventKey = nil
    lastEmittedEventDate = nil
    lastCustomCandidateIdentifier = nil
    lastCustomCandidateCount = 0
  }

  private func loadProfiles() -> [CustomSoundProfileRecord] {
    guard let data = try? Data(contentsOf: profilesFileURL) else {
      return []
    }

    do {
      return try JSONDecoder().decode([CustomSoundProfileRecord].self, from: data)
    } catch {
      return []
    }
  }

  private func saveProfiles(_ profiles: [CustomSoundProfileRecord]) {
    do {
      let normalized = profiles.sorted { left, right in
        left.updatedAt > right.updatedAt
      }
      let data = try JSONEncoder().encode(normalized)
      try FileManager.default.createDirectory(at: customSoundsRootURL, withIntermediateDirectories: true, attributes: nil)
      try data.write(to: profilesFileURL, options: .atomic)
    } catch {
      eventSink?(FlutterError(code: "save_profiles_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func upsertProfile(_ profile: CustomSoundProfileRecord, in profiles: [CustomSoundProfileRecord]) -> [CustomSoundProfileRecord] {
    var next = profiles
    if let index = next.firstIndex(where: { $0.id == profile.id }) {
      next[index] = profile
    } else {
      next.append(profile)
    }
    return next
  }

  #if canImport(CreateML)
  private func buildTrainingData(from profiles: [CustomSoundProfileRecord]) throws -> [String: [URL]] {
    var filesByLabel: [String: [URL]] = [:]
    var backgroundFiles: [URL] = []

    for profile in profiles where profile.enabled && profile.hasEnoughSamples {
      let urls = profile.targetSamplePaths.map { URL(fileURLWithPath: $0) }
      if !urls.isEmpty {
        filesByLabel[profile.name] = urls
      }

      backgroundFiles.append(contentsOf: profile.backgroundSamplePaths.map { URL(fileURLWithPath: $0) })
    }

    if !backgroundFiles.isEmpty {
      filesByLabel[backgroundLabel] = backgroundFiles
    }

    return filesByLabel
  }

  private func persistCustomModel(_ classifier: MLSoundClassifier) throws {
    if FileManager.default.fileExists(atPath: modelSourceURL.path) {
      try FileManager.default.removeItem(at: modelSourceURL)
    }
    if FileManager.default.fileExists(atPath: compiledModelURL.path) {
      try FileManager.default.removeItem(at: compiledModelURL)
    }

    try classifier.write(to: modelSourceURL)
    let compiledTemporaryURL = try MLModel.compileModel(at: modelSourceURL)
    try FileManager.default.copyItem(at: compiledTemporaryURL, to: compiledModelURL)
  }
  #endif

  private func clearPersistedCustomModel() {
    if FileManager.default.fileExists(atPath: modelSourceURL.path) {
      try? FileManager.default.removeItem(at: modelSourceURL)
    }
    if FileManager.default.fileExists(atPath: compiledModelURL.path) {
      try? FileManager.default.removeItem(at: compiledModelURL)
    }
  }

  private func sampleURLs(for soundId: String, sampleKind: String) -> [URL] {
    let directoryURL = profileDirectoryURL(for: soundId)
      .appendingPathComponent(sampleKind, isDirectory: true)

    guard let fileURLs = try? FileManager.default.contentsOfDirectory(
      at: directoryURL,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    return fileURLs.sorted { left, right in
      left.lastPathComponent < right.lastPathComponent
    }
  }

  private func outputFileURL(for soundId: String, sampleKind: String, sampleIndex: Int) throws -> URL {
    let directoryURL = profileDirectoryURL(for: soundId)
      .appendingPathComponent(sampleKind, isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
    let filename = sampleKind == "background"
      ? "background_1.caf"
      : "target_\(sampleIndex + 1).caf"
    return directoryURL.appendingPathComponent(filename)
  }

  private func updateInputLevels(from buffer: AVAudioPCMBuffer) {
    let frameLength = Int(buffer.frameLength)
    guard frameLength > 0 else {
      latestInputRMS = 0
      latestInputPeak = 0
      return
    }

    switch buffer.format.commonFormat {
    case .pcmFormatFloat32:
      guard let channelData = buffer.floatChannelData else {
        latestInputRMS = 0
        latestInputPeak = 0
        return
      }
      let samples = UnsafeBufferPointer(start: channelData[0], count: frameLength)
      var sumSquares: Float = 0
      var peak: Float = 0
      for sample in samples {
        let magnitude = abs(sample)
        sumSquares += magnitude * magnitude
        if magnitude > peak {
          peak = magnitude
        }
      }
      latestInputRMS = sqrt(sumSquares / Float(frameLength))
      latestInputPeak = peak
    case .pcmFormatInt16:
      guard let channelData = buffer.int16ChannelData else {
        latestInputRMS = 0
        latestInputPeak = 0
        return
      }
      let samples = UnsafeBufferPointer(start: channelData[0], count: frameLength)
      var sumSquares: Float = 0
      var peak: Float = 0
      for sample in samples {
        let normalized = Float(sample) / Float(Int16.max)
        let magnitude = abs(normalized)
        sumSquares += magnitude * magnitude
        if magnitude > peak {
          peak = magnitude
        }
      }
      latestInputRMS = sqrt(sumSquares / Float(frameLength))
      latestInputPeak = peak
    default:
      latestInputRMS = 0
      latestInputPeak = 0
    }
  }

  private func profileDirectoryURL(for soundId: String) -> URL {
    customSoundsRootURL.appendingPathComponent(soundId, isDirectory: true)
  }

  private func applicationSupportDirectory() -> URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
  }

  private func requestMicrophonePermission(_ completion: @escaping (Bool) -> Void) {
    AVAudioSession.sharedInstance().requestRecordPermission(completion)
  }

  private func isoTimestamp() -> String {
    dateFormatter.string(from: Date())
  }

  private func sendStatus(_ status: String) {
    eventSink?(["type": "status", "status": status])
  }
}
