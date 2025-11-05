import torch
import torchaudio
import librosa
import numpy as np
import csv
from cnn14_setup import create_cnn14_model

def load_audio(audio_path, target_sr=16000, duration=5):
    """Load and preprocess audio file."""
    # Load audio with librosa (supports more formats)
    waveform, sr = librosa.load(audio_path, sr=target_sr)
    
    # Convert to mono if stereo
    if len(waveform.shape) > 1:
        waveform = librosa.to_mono(waveform)
    
    # Ensure consistent duration
    target_length = int(target_sr * duration)
    if waveform.shape[0] < target_length:
        # Pad if too short
        waveform = np.pad(waveform, (0, target_length - waveform.shape[0]))
    else:
        # Truncate if too long
        waveform = waveform[:target_length]
    
    # Convert to tensor
    waveform = torch.FloatTensor(waveform)
    
    return waveform

def load_labels():
    """Load AudioSet class labels."""
    # If we don't have enough labels, use generic ones
    labels = [f"Sound_{i}" for i in range(527)]
    
    try:
        with open('class_labels_indices.csv', 'r', newline='') as f:
            reader = csv.DictReader(f)
            for i, row in enumerate(reader):
                if i < 527:  # Only use up to 527 labels
                    labels[i] = row['display_name'].strip('"')
    except Exception as e:
        print(f"Warning: Error loading labels: {e}")
        print("Using generic labels instead")
    
    return labels

def predict_audio(model, waveform, labels, top_k=5):
    """Make predictions on audio."""
    model.eval()
    
    # Add batch dimension and ensure input is 2D
    waveform = waveform.unsqueeze(0)
    
    with torch.no_grad():
        output = model(waveform)
        output = torch.sigmoid(output)  # Convert to probabilities
        
    # Get top k predictions
    probs, indices = output.mean(dim=1).topk(top_k)
    
    results = []
    for prob, idx in zip(probs[0], indices[0]):
        results.append({
            'label': labels[idx],
            'probability': float(prob) * 100
        })
    
    return results

def main():
    # Load the model
    model = create_cnn14_model(pretrained=True, checkpoint_path='Cnn14_16k_mAP=0.438.pth')
    
    # Load AudioSet labels
    try:
        labels = load_labels()
    except FileNotFoundError:
        print("Warning: class_labels_indices.csv not found. Using dummy labels.")
        labels = [f"Class_{i}" for i in range(527)]
    
    # Process sample audio
    audio_path = 'complex_audio.wav'  # You'll need to provide this
    try:
        waveform = load_audio(audio_path)
        print(f"\nProcessing audio file: {audio_path}")
        
        # Make predictions
        predictions = predict_audio(model, waveform, labels)
        
        # Print results
        print("\nTop 5 predictions:")
        for pred in predictions:
            print(f"{pred['label']}: {pred['probability']:.2f}%")
            
    except FileNotFoundError:
        print(f"\nError: Audio file '{audio_path}' not found.")
        print("Please place a sample audio file in the current directory.")

if __name__ == "__main__":
    main()