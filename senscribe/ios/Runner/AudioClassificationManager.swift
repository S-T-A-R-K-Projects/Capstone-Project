import Foundation
import AVFoundation

class AudioClassificationManager: NSObject {
    static let shared = AudioClassificationManager()
    
    private var audioEngine: AudioEngine?
    private var classifier: YAMNetClassifier?
    private let alertManager = AlertManager.shared
    
    private var isMonitoring = false
    private var audioBufferAccumulator: [Float] = []
    private let requiredSamples = 15600
    
    private override init() {
        super.init()
    }
    
    func initialize(modelPath: String) throws {
        print("AudioClassificationManager: Initializing with model at: \(modelPath)")
        
        do {
            classifier = try YAMNetClassifier(modelPath: modelPath)
            print("AudioClassificationManager: YAMNetClassifier initialized successfully")
        } catch {
            print("AudioClassificationManager: Failed to initialize classifier: \(error)")
            throw error
        }
        
        audioEngine = AudioEngine()
        audioEngine?.delegate = self
        print("AudioClassificationManager: AudioEngine initialized")
    }
    
    func startMonitoring() throws {
        guard !isMonitoring else {
            print("AudioClassificationManager: Already monitoring")
            return
        }
        
        print("AudioClassificationManager: Starting monitoring...")
        
        do {
            try audioEngine?.startRecording()
            isMonitoring = true
            audioBufferAccumulator.removeAll()
            print("AudioClassificationManager: Monitoring started successfully")
        } catch {
            print("AudioClassificationManager: Failed to start recording: \(error)")
            throw error
        }
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        audioEngine?.stopRecording()
        isMonitoring = false
        audioBufferAccumulator.removeAll()
    }
    
    func getMonitoringStatus() -> Bool {
        return isMonitoring
    }
    
    func enableDirectionDetection(_ enabled: Bool) {
        alertManager.enableDirectionDetection(enabled)
    }
}

extension AudioClassificationManager: AudioEngineDelegate {
    func audioEngine(_ engine: AudioEngine, didReceiveBuffer buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameCount = Int(buffer.frameLength)
        
        // Accumulate audio samples
        for i in 0..<frameCount {
            audioBufferAccumulator.append(channelData[i])
        }
        
        // Check if we have enough samples for inference
        while audioBufferAccumulator.count >= requiredSamples {
            // Extract samples for classification
            let samplesForClassification = Array(audioBufferAccumulator.prefix(requiredSamples))
            
            // Create buffer for classification
            if let classificationBuffer = createBuffer(from: samplesForClassification) {
                // Perform classification
                if let result = classifier?.classify(audioBuffer: classificationBuffer) {
                    print("Classification: \(result.label) with confidence: \(result.confidence)")
                    
                    // Calculate direction if enabled
                    let direction = alertManager.calculateDirection(from: buffer)
                    
                    // Send result through alert manager
                    alertManager.sendClassificationResult(result, direction: direction)
                }
            }
            
            // Remove processed samples (with 75% overlap for better detection - was 50%)
            let samplesToRemove = requiredSamples / 4
            audioBufferAccumulator.removeFirst(samplesToRemove)
        }
    }
    
    func audioEngine(_ engine: AudioEngine, didEncounterError error: Error) {
        print("Audio engine error: \(error.localizedDescription)")
    }
    
    private func createBuffer(from samples: [Float]) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            return nil
        }
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        ) else {
            return nil
        }
        
        buffer.frameLength = AVAudioFrameCount(samples.count)
        
        guard let channelData = buffer.floatChannelData?[0] else {
            return nil
        }
        
        for i in 0..<samples.count {
            channelData[i] = samples[i]
        }
        
        return buffer
    }
}
