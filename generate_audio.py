import math
import struct
import wave
import os

SAMPLE_RATE = 44100

def create_wav(filename, samples):
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(SAMPLE_RATE)
        
        # Clamp and pack samples
        packed = bytearray()
        for s in samples:
            val = int(max(-1.0, min(1.0, s)) * 32767.0)
            packed.extend(struct.pack('<h', val))
        wav_file.writeframes(packed)
    print(f"Generated {filename} ({len(samples)} samples, {len(samples)/SAMPLE_RATE:.2f}s)")

def envelope(t, attack, decay, sustain, release, total_dur):
    if t < attack:
        return t / attack if attack > 0 else 1.0
    elif t < attack + decay:
        d_progress = (t - attack) / decay
        return 1.0 - (1.0 - sustain) * d_progress
    elif t < total_dur - release:
        return sustain
    else:
        r_progress = (t - (total_dur - release)) / release
        return max(0.0, sustain * (1.0 - r_progress))

def generate_dice_roll():
    # 0.5s of tumbling / shaking rattling clicks
    duration = 0.55
    total_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * total_samples
    
    # 7 quick tumbling impacts
    impact_times = [0.02, 0.08, 0.16, 0.24, 0.33, 0.42, 0.49]
    for it in impact_times:
        start_idx = int(it * SAMPLE_RATE)
        imp_dur = 0.04
        imp_samples = int(imp_dur * SAMPLE_RATE)
        freq = 320 + (it * 200) % 180
        for i in range(imp_samples):
            if start_idx + i < total_samples:
                t = i / SAMPLE_RATE
                env = math.exp(-i / (SAMPLE_RATE * 0.008))
                noise = (math.sin(t * 1234.5) * 43758.5453) % 1.0 - 0.5
                wave_val = math.sin(2 * math.pi * freq * t) * 0.6 + noise * 0.4
                samples[start_idx + i] += wave_val * env * 0.55
    return samples

def generate_dice_land():
    # Solid wooden clack/thud
    duration = 0.18
    total_samples = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        env1 = math.exp(-i / (SAMPLE_RATE * 0.015))
        env2 = math.exp(-i / (SAMPLE_RATE * 0.035))
        f1 = 280
        f2 = 140
        noise = (math.sin(t * 9876.5) * 43758.5453) % 1.0 - 0.5
        val = (math.sin(2 * math.pi * f1 * t) * 0.5 + 
               math.sin(2 * math.pi * f2 * t) * 0.4 + 
               noise * 0.3) * env1 + math.sin(2 * math.pi * 90 * t) * 0.3 * env2
        samples.append(val * 0.75)
    return samples

def generate_token_step():
    # Crisp wooden tap / pop
    duration = 0.12
    total_samples = int(duration * SAMPLE_RATE)
    samples = []
    freq = 680
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-i / (SAMPLE_RATE * 0.012))
        val = math.sin(2 * math.pi * freq * t) * 0.7 + math.sin(2 * math.pi * freq * 1.5 * t) * 0.3
        samples.append(val * env * 0.65)
    return samples

def generate_token_capture():
    # Energetic whoosh + arcade strike
    duration = 0.45
    total_samples = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        # pitch drops rapidly
        freq = 880 * math.exp(-t * 8) + 160
        env = math.exp(-t * 7)
        noise = ((math.sin(t * 5432.1) * 31234.5) % 1.0 - 0.5) * math.exp(-t * 12)
        val = math.sin(2 * math.pi * freq * t) * 0.7 + noise * 0.5
        samples.append(val * env * 0.8)
    return samples

def generate_token_home():
    # 4-note ascending triumphant bell chime (C5, E5, G5, C6)
    duration = 0.7
    total_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * total_samples
    notes = [(0.0, 523.25), (0.12, 659.25), (0.24, 783.99), (0.36, 1046.50)]
    for start_t, freq in notes:
        start_idx = int(start_t * SAMPLE_RATE)
        for i in range(int(0.35 * SAMPLE_RATE)):
            idx = start_idx + i
            if idx < total_samples:
                t = i / SAMPLE_RATE
                env = math.exp(-i / (SAMPLE_RATE * 0.08))
                val = math.sin(2 * math.pi * freq * t) * 0.5 + math.sin(2 * math.pi * freq * 2 * t) * 0.2
                samples[idx] += val * env * 0.45
    return samples

def generate_turn_alert():
    # 2-tone pleasant ding (E5 -> A5)
    duration = 0.35
    total_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * total_samples
    notes = [(0.0, 659.25), (0.1, 880.0)]
    for start_t, freq in notes:
        start_idx = int(start_t * SAMPLE_RATE)
        for i in range(int(0.24 * SAMPLE_RATE)):
            idx = start_idx + i
            if idx < total_samples:
                t = i / SAMPLE_RATE
                env = math.exp(-i / (SAMPLE_RATE * 0.06))
                val = math.sin(2 * math.pi * freq * t) * 0.5
                samples[idx] += val * env * 0.4
    return samples

def generate_victory():
    # Fanfare: G4 -> C5 -> E5 -> G5 triumphant sustained chord
    duration = 1.6
    total_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * total_samples
    notes = [
        (0.0, 392.00, 0.2),
        (0.18, 523.25, 0.2),
        (0.36, 659.25, 0.25),
        (0.60, 783.99, 0.95),
        (0.60, 523.25, 0.95),
        (0.60, 659.25, 0.95),
        (0.60, 1046.50, 0.95),
    ]
    for start_t, freq, note_dur in notes:
        start_idx = int(start_t * SAMPLE_RATE)
        n_samples = int(note_dur * SAMPLE_RATE)
        for i in range(n_samples):
            idx = start_idx + i
            if idx < total_samples:
                t = i / SAMPLE_RATE
                env = envelope(t, 0.02, 0.08, 0.7, 0.3, note_dur)
                val = (math.sin(2 * math.pi * freq * t) * 0.4 + 
                       math.sin(2 * math.pi * freq * 2 * t) * 0.15)
                samples[idx] += val * env * 0.22
    return samples

def generate_defeat():
    # Melancholy minor descent (G4 -> Eb4 -> C4)
    duration = 1.0
    total_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * total_samples
    notes = [(0.0, 392.00, 0.3), (0.28, 311.13, 0.3), (0.56, 261.63, 0.44)]
    for start_t, freq, note_dur in notes:
        start_idx = int(start_t * SAMPLE_RATE)
        n_samples = int(note_dur * SAMPLE_RATE)
        for i in range(n_samples):
            idx = start_idx + i
            if idx < total_samples:
                t = i / SAMPLE_RATE
                env = envelope(t, 0.03, 0.06, 0.6, 0.2, note_dur)
                val = math.sin(2 * math.pi * freq * t) * 0.45
                samples[idx] += val * env * 0.35
    return samples

def generate_bgm():
    # Gentle, soothing 4-second pentatonic ambient loop (low volume, warm sound)
    duration = 4.0
    total_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * total_samples
    
    # Melody: C4, D4, E4, G4, A4 soothing arpeggiated loop
    melody = [
        (0.0, 261.63, 0.6),
        (0.5, 329.63, 0.6),
        (1.0, 392.00, 0.6),
        (1.5, 440.00, 0.6),
        (2.0, 523.25, 0.6),
        (2.5, 392.00, 0.6),
        (3.0, 329.63, 0.6),
        (3.5, 293.66, 0.6),
    ]
    for start_t, freq, note_dur in melody:
        start_idx = int(start_t * SAMPLE_RATE)
        n_samples = int(note_dur * SAMPLE_RATE)
        for i in range(n_samples):
            idx = (start_idx + i) % total_samples
            t = i / SAMPLE_RATE
            env = math.sin(math.pi * (t / note_dur))
            val = math.sin(2 * math.pi * freq * t) * 0.5 + math.sin(2 * math.pi * freq * 0.5 * t) * 0.3
            samples[idx] += val * env * 0.15
    return samples

if __name__ == '__main__':
    out_dir = r"C:\Users\Asus\.gemini\antigravity\scratch\duo_ludo\assets\audio"
    create_wav(os.path.join(out_dir, "dice_roll.wav"), generate_dice_roll())
    create_wav(os.path.join(out_dir, "dice_land.wav"), generate_dice_land())
    create_wav(os.path.join(out_dir, "token_step.wav"), generate_token_step())
    create_wav(os.path.join(out_dir, "token_capture.wav"), generate_token_capture())
    create_wav(os.path.join(out_dir, "token_home.wav"), generate_token_home())
    create_wav(os.path.join(out_dir, "turn_alert.wav"), generate_turn_alert())
    create_wav(os.path.join(out_dir, "victory.wav"), generate_victory())
    create_wav(os.path.join(out_dir, "defeat.wav"), generate_defeat())
    create_wav(os.path.join(out_dir, "bgm.wav"), generate_bgm())
    print("All audio files generated successfully!")
