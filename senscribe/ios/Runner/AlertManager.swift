import Foundation
import AVFoundation

class AlertManager {
    static let shared = AlertManager()
    
    private var eventSink: FlutterEventSink?
    private var isDirectionDetectionEnabled = false
    
    private init() {}
    
    func setEventSink(_ sink: @escaping FlutterEventSink) {
        self.eventSink = sink
    }
    
    func removeEventSink() {
        self.eventSink = nil
    }
    
    func enableDirectionDetection(_ enabled: Bool) {
        isDirectionDetectionEnabled = enabled
    }
    
    func sendClassificationResult(_ result: ClassificationResult, direction: String? = nil) {
        guard let eventSink = eventSink else { return }
        
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        
        var resultDict: [String: Any] = [
            "label": result.label,
            "confidence": result.confidence,
            "timestamp": timestamp
        ]
        
        if let direction = direction {
            resultDict["direction"] = direction
        }
        
        eventSink(resultDict)
    }
    
    func calculateDirection(from buffer: AVAudioPCMBuffer) -> String? {
        guard isDirectionDetectionEnabled else { return nil }
        guard buffer.format.channelCount == 2 else { return nil }
        
        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            return nil
        }
        
        let frameCount = Int(buffer.frameLength)
        
        // Calculate RMS for each channel
        var leftRMS: Float = 0.0
        var rightRMS: Float = 0.0
        
        for i in 0..<frameCount {
            leftRMS += leftChannel[i] * leftChannel[i]
            rightRMS += rightChannel[i] * rightChannel[i]
        }
        
        leftRMS = sqrt(leftRMS / Float(frameCount))
        rightRMS = sqrt(rightRMS / Float(frameCount))
        
        // Calculate direction ratio
        let total = leftRMS + rightRMS
        guard total > 0 else { return "center" }
        
        let ratio = (rightRMS - leftRMS) / total
        
        // Map to direction string
        if ratio < -0.3 {
            return "left"
        } else if ratio > 0.3 {
            return "right"
        } else {
            return "center"
        }
    }
}
