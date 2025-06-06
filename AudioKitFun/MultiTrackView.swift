import AVFoundation
import AudioKit
import AudioKitEX
import AudioKitUI
import SwiftUI

class AudioTrack {
    let name: String
    let player: AudioPlayer
    let fader: Fader
    
    init(name: String, url: URL) throws {
        self.name = name
        let file = try AVAudioFile(forReading: url)
        self.player = AudioPlayer(file: file)!
        player.volume = 0.2
        self.fader = Fader(player)
        self.fader.gain = 0.5
    }
}

@Observable
class MultiTrackEngine {
    private let engine = AudioEngine()
    private let mixer = Mixer()
    private var tracks: [AudioTrack] = []
    
    var isPlaying = false
    var isLoaded = false
    var playbackProgress: Double = 0
    
    private var playStartTime: TimeInterval = 0
    private var pausedAt: TimeInterval = 0
    
    init() {
        engine.output = mixer
    }
    
    func loadTracks() {
        let trackFiles: [(filename: String, instrument: String)] = [
            ("syn_34.wav", "Synthesizer"),
            ("Audio 10_07.wav", "Lead Synth"),
            ("Audio 11_06.wav", "Pad"),
            ("bs_10.wav", "Bass")
        ]

        do {
            stop()
            tracks.removeAll()
            mixer.removeAllInputs()
            
            print("Loading tracks...")
            
            for (filename, instrument) in trackFiles {
                print("Loading [\(filename)]...")
                let url = Bundle.main.url(forResource: filename, withExtension: nil)!
                let track = try AudioTrack(name: instrument, url: url)
                tracks.append(track)
                mixer.addInput(track.fader)
            }
            print("Done loading tracks.")
            isLoaded = true
            
            try engine.start()
        } catch {
            print("Error loading tracks: \(error)")
        }
    }
    
    // MARK: - playback
    
    func stop() {
        for track in tracks {
            track.player.stop()
        }
    }
    
    func startSynchronizedPlayback() {
        guard isLoaded else { return }
        
        // Schedule all tracks to play at the same time
        let now = AVAudioTime.now()
        let sampleRate: Double = 44100.0
        let sampleTime = now.sampleTime + Int64(0.1 * sampleRate) // 4410
        let startTime = AVAudioTime(sampleTime: sampleTime, atRate: sampleRate)
        
        for track in tracks {
            track.player.play(from: pausedAt, at: startTime)
        }
        
        playStartTime = Date().timeIntervalSinceReferenceDate - pausedAt
        isPlaying = true
    }
    
    func pause() {
        pausedAt = Date().timeIntervalSinceReferenceDate - playStartTime
        for track in tracks {
            track.player.pause()
        }
        
        isPlaying = false
    }
    
    // MARK: - volume/mute
    
    func volume(for track: AudioTrack) -> Float {
        Float(track.fader.gain)
    }
    
    func setVolume(for track: AudioTrack, to value: Float) {
        track.fader.gain = AUValue(value)
    }
    
    func toggleMute(for track: AudioTrack) {
        let fader = track.fader
        track.fader.gain = fader.gain > 0 ? 0 : 0.2
    }
    
    // MARK: - progress tracking
    
    var duration: TimeInterval {
        guard let firstTrack = tracks.first else { return 0 }
        return firstTrack.player.duration
    }
    
    func updateProgress() {
        guard isPlaying else { return }
        let duraton = self.duration
        guard duration > 0 else { return }
        
        let elapsedTime = Date().timeIntervalSinceReferenceDate - playStartTime
        playbackProgress = min(elapsedTime / duration, 1.0)
    }
}


struct MultiTrackView: View {
    @State private var engine = MultiTrackEngine()
    
    var body: some View {
        Color.white
    }
}


#Preview {
    NavigationStack {
        MultiTrackView()
    }
}
