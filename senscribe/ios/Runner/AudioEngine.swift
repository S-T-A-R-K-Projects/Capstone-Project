import Foundation
import AVFoundation

protocol AudioEngineDelegate: AnyObject {
    func audioEngine(_ engine: AudioEngine, didReceiveBuffer buffer: AVAudioPCMBuffer)
    func audioEngine(_ engine: AudioEngine, didEncounterError error: Error)
}

class AudioEngine {
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private var audioFormat: AVAudioFormat?
    
    weak var delegate: AudioEngineDelegate?
    
    private(set) var isRunning = false
    private let targetSampleRate: Double = 16000
    private let bufferSize: AVAudioFrameCount = 15600 // YAMNet expected input
    
    init() {
        inputNode = audioEngine.inputNode
    }
    
    func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [])
        try audioSession.setActive(true)
    }
    
    func startRecording() throws {
        guard !isRunning else { return }
        
        print("AudioEngine: Setting up audio session...")
        // Setup audio session
        try setupAudioSession()
        
        print("AudioEngine: Getting input format...")
        // Get input format
        let inputFormat = inputNode.outputFormat(forBus: 0)
        print("AudioEngine: Input format: \(inputFormat)")
        
        // Check if the format is valid (simulator often has 0 Hz)
        if inputFormat.sampleRate == 0 {
            print("AudioEngine: ERROR - Invalid sample rate (0 Hz). Are you running on simulator?")
            throw AudioEngineError.audioSessionSetupFailed
        }
        
        // Create desired format: mono, 16kHz, PCM float
        guard let desiredFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            print("AudioEngine: Failed to create desired format")
            throw AudioEngineError.formatCreationFailed
        }
        
        print("AudioEngine: Desired format: \(desiredFormat)")
        audioFormat = desiredFormat
        
        // Create converter if sample rates differ
        guard let converter = AVAudioConverter(from: inputFormat, to: desiredFormat) else {
            print("AudioEngine: Failed to create converter")
            throw AudioEngineError.converterCreationFailed
        }
        
        print("AudioEngine: Installing tap...")
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // Convert to desired format
            guard let convertedBuffer = self.convertBuffer(buffer, using: converter, to: desiredFormat) else {
                return
            }
            
            // Send to delegate
            self.delegate?.audioEngine(self, didReceiveBuffer: convertedBuffer)
        }
        
        print("AudioEngine: Preparing and starting engine...")
        // Prepare and start engine
        audioEngine.prepare()
        try audioEngine.start()
        isRunning = true
        print("AudioEngine: Successfully started!")
    }
    
    func stopRecording() {
        guard isRunning else { return }
        
        inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRunning = false
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    private func convertBuffer(_ buffer: AVAudioPCMBuffer, using converter: AVAudioConverter, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * (format.sampleRate / buffer.format.sampleRate))
        
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            return nil
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            delegate?.audioEngine(self, didEncounterError: error)
            return nil
        }
        
        convertedBuffer.frameLength = convertedBuffer.frameCapacity
        return convertedBuffer
    }
}

enum AudioEngineError: Error {
    case formatCreationFailed
    case converterCreationFailed
    case audioSessionSetupFailed
}
