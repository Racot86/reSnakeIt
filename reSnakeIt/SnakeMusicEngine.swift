//
//  SnakeMusicEngine.swift
//  reSnakeIt
//

import Foundation
import AVFoundation

final class SnakeMusicEngine {
    static let shared = SnakeMusicEngine()

    private enum Waveform {
        case sine
        case triangle
        case softSaw
        case noise
    }

    private struct Voice {
        var waveform: Waveform
        var startSample: Int64
        var durationSamples: Int64
        var elapsedSamples: Int64 = 0
        var phase: Double = 0
        var freqStart: Double
        var freqEnd: Double
        var amplitude: Double
        var attack: Double
        var release: Double
        var pan: Double
    }

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let lock = NSLock()

    private var isStarted = false
    private var sampleRate: Double = 44_100
    private var renderSampleClock: Int64 = 0
    private var voices: [Voice] = []

    private var isGameplayMode = false
    private var themeHue: Double = 0.52
    private var rootMidi: Int = 45
    private var moveCounter = 0
    private var foodCounter = 0
    private var turnCounter = 0
    private var noiseState: UInt64 = 0x1234_5678_9ABC_DEF0

    private let bpm: Double = 76
    private let scale: [Int] = [0, 2, 4, 7, 9] // major pentatonic
    private let progression: [Int] = [0, 5, 7, 2]
    private let bassPatternDegrees: [Int] = [0, 2, 1, 3, 0, 2, 4, 1]
    private let leadPatternDegrees: [Int] = [2, 4, 3, 1, 4, 2, 0, 3]

    private init() {}

    func startIfNeeded() {
        lock.lock()
        if isStarted {
            lock.unlock()
            return
        }
        lock.unlock()

        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            #endif

            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
            let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
                guard let self else { return noErr }
                self.render(frameCount: Int(frameCount), audioBufferList: audioBufferList)
                return noErr
            }

            sourceNode = node
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.outputVolume = 0.62
            try engine.start()

            lock.lock()
            isStarted = true
            voices.removeAll()
            renderSampleClock = 0
            lock.unlock()
        } catch {
            // Fail silently: game should remain playable without sound.
        }
    }

    func setThemeHue(_ hue: CGFloat) {
        lock.lock()
        themeHue = Double(hue)
        // Neon hue also nudges musical root, keeping sessions distinct but melodic.
        rootMidi = 43 + Int(round(themeHue * 10.0))
        moveCounter = 0
        foodCounter = 0
        turnCounter = 0
        lock.unlock()
    }

    func setGameplayMode(isGameplay: Bool) {
        lock.lock()
        isGameplayMode = isGameplay
        lock.unlock()
    }

    func playMoveBass(speed: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        guard isStarted else { return }

        let degree = bassPatternDegrees[moveCounter % bassPatternDegrees.count]
        let octave = moveCounter % 8 >= 4 ? 0 : -12
        let midi = currentChordRootMidi() + scale[degree] + octave
        let hz = midiToHz(midi)
        let normalizedSpeed = max(0.0, min(1.0, (0.22 - speed) / (0.22 - 0.085)))
        let amp = 0.028 + normalizedSpeed * 0.014
        addVoiceLocked(
            waveform: .triangle,
            freqStart: hz,
            freqEnd: hz,
            amplitude: amp,
            duration: 0.12,
            attack: 0.008,
            release: 0.08,
            pan: -0.08
        )
        moveCounter += 1
    }

    func playTurn(comboCount: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard isStarted else { return }

        let degree = (turnCounter + max(0, comboCount - 1)) % scale.count
        let midi = currentChordRootMidi() + scale[degree] + 12
        let hz = midiToHz(midi)
        let boost = min(1.0, Double(comboCount) * 0.12)
        addVoiceLocked(
            waveform: .triangle,
            freqStart: hz,
            freqEnd: hz * (1.0 + 0.004 + boost * 0.008),
            amplitude: 0.026 + boost * 0.012,
            duration: 0.11,
            attack: 0.006,
            release: 0.08,
            pan: 0.08
        )
        turnCounter += 1
    }

    func playFood() {
        lock.lock()
        defer { lock.unlock() }
        guard isStarted else { return }

        let base = currentChordRootMidi() + 12
        let degA = leadPatternDegrees[foodCounter % leadPatternDegrees.count]
        let degB = (degA + 2) % scale.count
        let degC = (degA + 4) % scale.count
        let notes = [scale[degA], scale[degB], scale[degC] + 12]
        for (i, offset) in notes.enumerated() {
            let hz = midiToHz(base + offset)
            addVoiceLocked(
                waveform: .sine,
                freqStart: hz,
                freqEnd: hz * 1.01,
                amplitude: 0.05 - Double(i) * 0.008,
                duration: 0.16,
                attack: 0.01,
                release: 0.11,
                pan: Double(i - 1) * 0.09,
                startOffset: Double(i) * 0.05
            )
        }
        foodCounter += 1
    }

    func playSpecialFood() {
        lock.lock()
        defer { lock.unlock() }
        guard isStarted else { return }

        let base = currentChordRootMidi() + 19
        let pattern = [0, 2, 4, 2, 4, 0]
        for (i, degreeIndex) in pattern.enumerated() {
            let midi = base + scale[degreeIndex] + (i >= 3 ? 12 : 0)
            let hz = midiToHz(midi)
            addVoiceLocked(
                waveform: .triangle,
                freqStart: hz,
                freqEnd: hz * 1.008,
                amplitude: 0.06 - Double(i) * 0.006,
                duration: 0.12,
                attack: 0.008,
                release: 0.08,
                pan: Double.random(in: -0.18...0.18),
                startOffset: Double(i) * 0.04
            )
        }
    }

    func playWallCrash() {
        lock.lock()
        defer { lock.unlock() }
        guard isStarted else { return }

        for i in 0..<5 {
            let midi = currentChordRootMidi() + 5 - i * 2
            let hz = midiToHz(midi)
            addVoiceLocked(
                waveform: .sine,
                freqStart: hz,
                freqEnd: max(55, hz * 0.86),
                amplitude: 0.05 - Double(i) * 0.006,
                duration: 0.14,
                attack: 0.006,
                release: 0.1,
                pan: -0.06 + Double(i) * 0.03,
                startOffset: Double(i) * 0.045
            )
        }
    }

    func playSelfBite() {
        lock.lock()
        defer { lock.unlock() }
        guard isStarted else { return }

        let swirl = [4, 2, 1, 0]
        for i in 0..<swirl.count {
            let midi = currentChordRootMidi() + 12 + scale[swirl[i]]
            let hz = midiToHz(midi)
            addVoiceLocked(
                waveform: .triangle,
                freqStart: hz,
                freqEnd: hz * (i % 2 == 0 ? 0.992 : 1.006),
                amplitude: 0.044,
                duration: 0.12,
                attack: 0.006,
                release: 0.09,
                pan: i % 2 == 0 ? -0.12 : 0.12,
                startOffset: Double(i) * 0.04
            )
        }
    }

    func playStarved() {
        lock.lock()
        defer { lock.unlock() }
        guard isStarted else { return }

        let offsets = [0, -2, -5, -7]
        for i in 0..<offsets.count {
            let midi = currentChordRootMidi() - 5 + offsets[i]
            let hz = midiToHz(midi)
            addVoiceLocked(
                waveform: .sine,
                freqStart: hz * (1.0 + Double.random(in: -0.012...0.012)),
                freqEnd: hz * 0.95,
                amplitude: 0.036,
                duration: 0.2,
                attack: 0.012,
                release: 0.14,
                pan: Double.random(in: -0.15...0.15),
                startOffset: Double(i) * 0.07
            )
        }
    }

    func playWin() {
        lock.lock()
        defer { lock.unlock() }
        guard isStarted else { return }

        let degrees = [0, 2, 3, 4, 2, 4]
        for (i, degreeIndex) in degrees.enumerated() {
            let midi = currentChordRootMidi() + 12 + scale[degreeIndex] + (i >= 3 ? 12 : 0)
            let hz = midiToHz(midi)
            addVoiceLocked(
                waveform: .sine,
                freqStart: hz,
                freqEnd: hz * 1.01,
                amplitude: 0.052,
                duration: 0.17,
                attack: 0.01,
                release: 0.12,
                pan: Double(i % 2 == 0 ? -1 : 1) * 0.12,
                startOffset: Double(i) * 0.055
            )
        }
    }

    private func render(frameCount: Int, audioBufferList: UnsafeMutablePointer<AudioBufferList>) {
        lock.lock()
        defer { lock.unlock() }

        let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
        guard !abl.isEmpty else { return }

        let leftPtr = abl[0].mData?.assumingMemoryBound(to: Float.self)
        let rightPtr = (abl.count > 1 ? abl[1].mData : abl[0].mData)?.assumingMemoryBound(to: Float.self)

        for frame in 0..<frameCount {
            let sampleIndex = renderSampleClock
            let t = Double(sampleIndex) / sampleRate

            var left = backgroundSample(at: t) * (isGameplayMode ? 0.95 : 0.8)
            var right = left

            var idx = 0
            while idx < voices.count {
                var voice = voices[idx]
                if sampleIndex < voice.startSample {
                    voices[idx] = voice
                    idx += 1
                    continue
                }

                if voice.elapsedSamples >= voice.durationSamples {
                    voices.remove(at: idx)
                    continue
                }

                let progress = Double(voice.elapsedSamples) / Double(max(1, voice.durationSamples))
                let env = envelope(progress: progress, attack: voice.attack, release: voice.release)
                let freq = voice.freqStart + (voice.freqEnd - voice.freqStart) * progress
                let sample = sampleForVoice(&voice, frequency: freq) * env * voice.amplitude
                let panL = (1.0 - voice.pan) * 0.5
                let panR = (1.0 + voice.pan) * 0.5
                left += sample * panL
                right += sample * panR

                voice.elapsedSamples += 1
                voices[idx] = voice
                idx += 1
            }

            let softL = tanh(left * 0.8) * 0.9
            let softR = tanh(right * 0.8) * 0.9
            leftPtr?[frame] = Float(softL)
            rightPtr?[frame] = Float(softR)
            renderSampleClock += 1
        }
    }

    private func backgroundSample(at time: Double) -> Double {
        let beats = time * bpm / 60.0
        let bar = Int(floor(beats / 4.0))
        let beatInBar = beats.truncatingRemainder(dividingBy: 4.0)
        let eighth = Int(floor(beats * 2.0))
        let eighthPhase = (beats * 2.0).truncatingRemainder(dividingBy: 1.0)

        let chordRoot = rootMidi + progression[bar % progression.count]
        let rootHz = midiToHz(chordRoot)
        let fifthHz = midiToHz(chordRoot + 7)
        let padLFO = 0.78 + 0.22 * sin(time * 2.0 * .pi * 0.11)
        let padAmp = isGameplayMode ? 0.018 : 0.024

        let pad =
            sin(2.0 * .pi * rootHz * time) * padAmp * padLFO +
            sin(2.0 * .pi * fifthHz * time) * (padAmp * 0.55) * (0.9 - 0.2 * cos(time * 2.0 * .pi * 0.07))

        let arpPattern = [0, 2, 4, 2, 1, 3, 4, 1]
        let arpDegree = arpPattern[eighth % arpPattern.count]
        let arpMidi = chordRoot + 12 + scale[arpDegree]
        let arpHz = midiToHz(arpMidi)
        let gate = exp(-eighthPhase * 4.4)
        let beatAccent = beatInBar < 0.01 ? 1.08 : 1.0
        let arpAmp = (isGameplayMode ? 0.009 : 0.012) * gate * beatAccent
        let arp = sin(2.0 * .pi * arpHz * time) * arpAmp

        return pad + arp
    }

    private func envelope(progress: Double, attack: Double, release: Double) -> Double {
        if progress <= 0 { return 0 }
        if progress >= 1 { return 0 }
        let a = max(0.0001, attack)
        let r = max(0.0001, release)
        let attackEnd = min(0.95, a)
        let releaseStart = max(0.05, 1.0 - r)

        if progress < attackEnd {
            return progress / attackEnd
        }
        if progress > releaseStart {
            return max(0, (1.0 - progress) / (1.0 - releaseStart))
        }
        return 1.0
    }

    private func sampleForVoice(_ voice: inout Voice, frequency: Double) -> Double {
        switch voice.waveform {
        case .noise:
            noiseState = noiseState &* 6364136223846793005 &+ 1
            let u = Double((noiseState >> 33) & 0xFFFF) / Double(0xFFFF)
            return (u * 2.0) - 1.0
        case .sine, .triangle, .softSaw:
            let increment = (2.0 * .pi * frequency) / sampleRate
            voice.phase += increment
            if voice.phase > (2.0 * .pi) {
                voice.phase.formTruncatingRemainder(dividingBy: 2.0 * .pi)
            }
            switch voice.waveform {
            case .sine:
                return sin(voice.phase)
            case .triangle:
                return (2.0 / .pi) * asin(sin(voice.phase))
            case .softSaw:
                let saw = 2.0 * (voice.phase / (2.0 * .pi)) - 1.0
                let sine = sin(voice.phase)
                return (saw * 0.5) + (sine * 0.5)
            case .noise:
                return 0
            }
        }
    }

    private func addVoiceLocked(
        waveform: Waveform,
        freqStart: Double,
        freqEnd: Double,
        amplitude: Double,
        duration: Double,
        attack: Double,
        release: Double,
        pan: Double,
        startOffset: Double = 0
    ) {
        let start = renderSampleClock + Int64(startOffset * sampleRate)
        let dur = max(Int64(duration * sampleRate), 1)
        voices.append(
            Voice(
                waveform: waveform,
                startSample: start,
                durationSamples: dur,
                freqStart: freqStart,
                freqEnd: freqEnd,
                amplitude: amplitude,
                attack: attack / max(duration, 0.001),
                release: release / max(duration, 0.001),
                pan: max(-1, min(1, pan))
            )
        )
        if voices.count > 128 {
            voices.removeFirst(voices.count - 128)
        }
    }

    private func currentChordRootMidi() -> Int {
        let beats = Double(renderSampleClock) / sampleRate * bpm / 60.0
        let bar = Int(floor(beats / 4.0))
        return rootMidi + progression[bar % progression.count]
    }

    private func midiToHz(_ midi: Int) -> Double {
        440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0)
    }
}
