import Foundation
import TensorFlowLite
import AVFoundation

class YAMNetClassifier {
    private var interpreter: Interpreter?
    private let labels: [String]
    private let modelPath: String
    
    // YAMNet expects 15600 samples (0.975s @ 16kHz)
    private let expectedSampleCount = 15600
    
    init(modelPath: String) throws {
        self.modelPath = modelPath
        
        print("YAMNetClassifier: Loading labels...")
        // Load YAMNet class labels
        self.labels = YAMNetClassifier.loadLabels()
        print("YAMNetClassifier: Loaded \(self.labels.count) labels")
        
        // Initialize TensorFlow Lite interpreter
        print("YAMNetClassifier: Setting up interpreter...")
        try setupInterpreter()
        print("YAMNetClassifier: Interpreter setup complete")
    }
    
    private func setupInterpreter() throws {
        print("YAMNetClassifier: Creating interpreter options...")
        var options = Interpreter.Options()
        options.threadCount = 2
        
        print("YAMNetClassifier: Creating interpreter with model at: \(modelPath)")
        do {
            interpreter = try Interpreter(modelPath: modelPath, options: options)
            print("YAMNetClassifier: Interpreter created, allocating tensors...")
            try interpreter?.allocateTensors()
            print("YAMNetClassifier: Tensors allocated successfully")
        } catch {
            print("YAMNetClassifier: Failed to setup interpreter: \(error)")
            throw error
        }
    }
    
    func classify(audioBuffer: AVAudioPCMBuffer) -> ClassificationResult? {
        guard let interpreter = interpreter else { return nil }
        guard let channelData = audioBuffer.floatChannelData?[0] else { return nil }
        
        let frameCount = Int(audioBuffer.frameLength)
        
        // Prepare input buffer
        var inputData = Data()
        
        // Convert audio samples to Float32 and normalize
        for i in 0..<min(frameCount, expectedSampleCount) {
            var sample = channelData[i]
            inputData.append(Data(bytes: &sample, count: MemoryLayout<Float>.size))
        }
        
        // Pad with zeros if needed
        if frameCount < expectedSampleCount {
            var zero: Float = 0.0
            for _ in frameCount..<expectedSampleCount {
                inputData.append(Data(bytes: &zero, count: MemoryLayout<Float>.size))
            }
        }
        
        do {
            // Copy input data to interpreter
            try interpreter.copy(inputData, toInputAt: 0)
            
            // Run inference
            try interpreter.invoke()
            
            // Get output
            let outputTensor = try interpreter.output(at: 0)
            
            // Parse output - YAMNet outputs shape [1, 521] for 521 classes
            let results = parseOutput(outputTensor.data)
            
            return results
        } catch {
            print("Inference error: \(error)")
            return nil
        }
    }
    
    private func parseOutput(_ data: Data) -> ClassificationResult? {
        let floatArray = data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> [Float] in
            let buffer = pointer.bindMemory(to: Float.self)
            return Array(buffer)
        }
        
        guard let maxIndex = floatArray.indices.max(by: { floatArray[$0] < floatArray[$1] }) else {
            return nil
        }
        
        let confidence = floatArray[maxIndex]
        
        // Lower threshold for better detection (was 0.5, now 0.3)
        guard confidence > 0.3 else { return nil }
        
        let label = maxIndex < labels.count ? labels[maxIndex] : "Unknown"
        
        return ClassificationResult(label: label, confidence: Double(confidence))
    }
    
    private static func loadLabels() -> [String] {
        // YAMNet AudioSet class labels
        // This is a simplified version - full labels should be loaded from a file
        return [
            "Speech", "Male speech", "Female speech", "Child speech", "Conversation",
            "Narration", "Babbling", "Speech synthesizer", "Shout", "Bellow",
            "Whoop", "Yell", "Battle cry", "Children shouting", "Screaming",
            "Whispering", "Laughter", "Baby laughter", "Giggle", "Snicker",
            "Belly laugh", "Chuckle", "Crying", "Baby crying", "Whimper",
            "Wail", "Moan", "Sigh", "Singing", "Choir",
            "Yodeling", "Chant", "Mantra", "Male singing", "Female singing",
            "Child singing", "Synthetic singing", "Rapping", "Humming", "Groan",
            "Grunt", "Whistling", "Breathing", "Wheeze", "Snoring",
            "Gasp", "Pant", "Snort", "Cough", "Throat clearing",
            "Sneeze", "Sniff", "Run", "Shuffle", "Walk",
            "Chewing", "Mastication", "Biting", "Gargling", "Stomach rumble",
            "Burping", "Hiccup", "Fart", "Hands", "Finger snapping",
            "Clapping", "Heart sounds", "Heartbeat", "Heart murmur", "Cheering",
            "Applause", "Chatter", "Crowd", "Hubbub", "Children playing",
            "Animal", "Domestic animals", "Dog", "Bark", "Yip",
            "Howl", "Bow-wow", "Growling", "Whimper", "Cat",
            "Purr", "Meow", "Hiss", "Caterwaul", "Livestock",
            "Horse", "Clip-clop", "Neigh", "Cattle", "Moo",
            "Cowbell", "Pig", "Oink", "Goat", "Bleat",
            "Sheep", "Chicken", "Cluck", "Crowing", "Turkey",
            "Gobble", "Duck", "Quack", "Goose", "Honk",
            "Wild animals", "Roaring cats", "Roar", "Bird", "Bird vocalization",
            "Squawk", "Pigeon", "Coo", "Crow", "Caw",
            "Owl", "Hoot", "Bird flight", "Canidae", "Rodents",
            "Mouse", "Patter", "Insect", "Cricket", "Mosquito",
            "Fly", "Buzz", "Frog", "Croak",
            "Snake", "Rattle", "Whale vocalization", "Music", "Musical instrument",
            "Plucked string instrument", "Guitar", "Electric guitar", "Bass guitar", "Acoustic guitar",
            "Steel guitar", "Tapping", "Strum", "Banjo", "Sitar",
            "Mandolin", "Zither", "Ukulele", "Keyboard", "Piano",
            "Electric piano", "Organ", "Electronic organ", "Hammond organ", "Synthesizer",
            "Sampler", "Harpsichord", "Percussion", "Drum kit", "Drum machine",
            "Drum", "Snare drum", "Rimshot", "Bass drum", "Timpani",
            "Tabla", "Cymbal", "Hi-hat", "Wood block", "Tambourine",
            "Rattle", "Maraca", "Gong", "Tubular bells", "Mallet percussion",
            "Marimba", "Glockenspiel", "Vibraphone", "Steelpan", "Orchestra",
            "Brass instrument", "French horn", "Trumpet", "Trombone", "Bowed string instrument",
            "String section", "Violin", "Cello", "Double bass", "Wind instrument",
            "Woodwind instrument", "Flute", "Saxophone", "Clarinet", "Harp",
            "Bell", "Church bell", "Jingle bell", "Bicycle bell", "Tuning fork",
            "Chime", "Wind chime", "Change ringing", "Harmonica", "Accordion",
            "Bagpipes", "Didgeridoo", "Shofar", "Theremin", "Singing bowl",
            "Scratching", "Pop music", "Hip hop music", "Beatboxing", "Rock music",
            "Heavy metal", "Punk rock", "Grunge", "Progressive rock", "Rock and roll",
            "Psychedelic rock", "Rhythm and blues", "Soul music", "Reggae", "Country",
            "Swing music", "Bluegrass", "Funk", "Folk music", "Middle Eastern music",
            "Jazz", "Disco", "Classical music", "Opera", "Electronic music",
            "House music", "Techno", "Dubstep", "Drum and bass", "Electronica",
            "Electronic dance music", "Ambient music", "Trance music", "Music of Latin America", "Salsa music",
            "Flamenco", "Blues", "Music for children", "New-age music", "Vocal music",
            "A capella", "Music of Africa", "Afrobeat", "Christian music", "Gospel music",
            "Music of Asia", "Carnatic music", "Music of Bollywood", "Ska", "Traditional music",
            "Independent music", "Song", "Background music", "Theme music", "Jingle",
            "Soundtrack music", "Lullaby", "Video game music", "Christmas music", "Dance music",
            "Wedding music", "Happy music", "Sad music", "Tender music", "Exciting music",
            "Angry music", "Scary music", "Wind", "Rustling leaves", "Wind noise",
            "Thunderstorm", "Thunder", "Water", "Rain", "Raindrop",
            "Rain on surface", "Stream", "Waterfall", "Ocean", "Waves",
            "Splash", "Gurgle", "Fire", "Crackle", "Vehicle",
            "Boat", "Sailboat", "Rowboat", "Motorboat", "Ship",
            "Motor vehicle", "Car", "Vehicle horn", "Toot", "Honk",
            "Beep", "Car alarm", "Power windows", "Skidding", "Tire squeal",
            "Car passing by", "Race car", "Auto racing", "Truck", "Air brake",
            "Air horn", "Reversing beeps", "Ice cream truck", "Bus", "Emergency vehicle",
            "Police car", "Ambulance", "Fire engine", "Motorcycle", "Traffic noise",
            "Rail transport", "Train", "Train whistle", "Train horn", "Railroad car",
            "Train wheels squealing", "Subway", "Aircraft", "Aircraft engine", "Jet engine",
            "Propeller", "Fixed-wing aircraft", "Bicycle", "Skateboard", "Engine",
            "Light engine", "Dental drill", "Lawn mower", "Chainsaw", "Medium engine",
            "Heavy engine", "Engine knocking", "Engine starting", "Idling", "Accelerating",
            "Door", "Doorbell", "Ding-dong", "Sliding door", "Slam",
            "Knock", "Tap", "Squeak", "Cupboard open or close", "Drawer open or close",
            "Dishes", "Cutlery", "Chopping", "Frying", "Microwave oven",
            "Blender", "Water tap", "Sink", "Bathtub", "Hair dryer",
            "Toilet flush", "Toothbrush", "Electric toothbrush", "Vacuum cleaner", "Zipper",
            "Keys jangling", "Coin", "Scissors", "Electric shaver", "Shuffling cards",
            "Typing", "Typewriter", "Computer keyboard", "Writing", "Alarm",
            "Telephone", "Telephone bell ringing", "Ringtone", "Telephone dialing", "Dial tone",
            "Busy signal", "Alarm clock", "Siren", "Civil defense siren", "Buzzer",
            "Smoke detector", "Fire alarm", "Foghorn", "Whistle", "Steam whistle",
            "Mechanisms", "Ratchet", "Clock", "Tick", "Tick-tock",
            "Gears", "Pulleys", "Sewing machine", "Mechanical fan", "Air conditioning",
            "Cash register", "Printer", "Camera", "Single-lens reflex camera", "Tools",
            "Hammer", "Jackhammer", "Sawing", "Filing", "Sanding",
            "Power tool", "Drill", "Explosion", "Gunshot", "Machine gun",
            "Fusillade", "Artillery fire", "Cap gun", "Fireworks", "Firecracker",
            "Burst", "Eruption", "Boom", "Wood", "Chop",
            "Splinter", "Crack", "Glass", "Chink", "Shatter",
            "Liquid", "Splash", "Slosh", "Squish", "Drip",
            "Pour", "Trickle", "Gush", "Fill", "Spray",
            "Pump", "Stir", "Boiling", "Sonar", "Arrow",
            "Whoosh", "Thump", "Thunk", "Electronic tuner", "Effects unit",
            "Chorus effect", "Basketball bounce", "Bang", "Slap", "Whack",
            "Smash", "Breaking", "Bouncing", "Whip", "Flap",
            "Scratch", "Scrape", "Rub", "Roll", "Crushing",
            "Crumpling", "Tearing", "Beep", "Ping", "Ding",
            "Clang", "Squeal", "Creak", "Rustle", "Whir",
            "Clatter", "Sizzle", "Clicking", "Clickety-clack", "Rumble",
            "Plop", "Jingle", "Hum", "Zing", "Boing",
            "Crunch", "Silence", "Sine wave", "Harmonic", "Chirp tone",
            "Sound effect", "Pulse", "Inside", "Small room", "Large room",
            "Reverberation", "Echo", "Noise", "Environmental noise", "Static",
            "Mains hum", "Distortion", "Sidetone", "Cacophony", "White noise",
            "Pink noise", "Throbbing", "Vibration", "Television", "Radio",
            "Field recording"
        ]
    }
}

struct ClassificationResult {
    let label: String
    let confidence: Double
}
