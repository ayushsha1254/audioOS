import Foundation
import AVFoundation
import AudioToolbox

// MARK: - State

/// Lifecycle state of the audio engine.
enum AudioEngineState: Equatable {
    case idle        // No recording yet — effects card locked
    case recording   // Mic tap active, writing to CAF temp file
    case recorded    // File ready, not playing
    case playing     // PlayerNode streaming from file through effects, looping
}

// MARK: - Errors

enum AudioEngineError: LocalizedError {
    case micPermissionDenied
    case engineStartFailed(Error)
    case sessionSetupFailed(Error)

    var errorDescription: String? {
        switch self {
        case .micPermissionDenied:
            return "Microphone access denied. Please enable it in Settings → Privacy → Microphone."
        case .engineStartFailed(let e):
            return "Audio engine failed to start: \(e.localizedDescription). Try restarting the app."
        case .sessionSetupFailed(let e):
            return "Audio session setup failed: \(e.localizedDescription)"
        }
    }
}

// MARK: - AudioEngineManager

@MainActor
final class AudioEngineManager: ObservableObject {

    static let shared = AudioEngineManager()

    // MARK: Published state (observed by ViewModel)
    @Published var state:             AudioEngineState = .idle
    @Published var recordingProgress: Float = 0.0   // 0–1 over 15 seconds
    @Published var playbackProgress:  Float = 0.0   // 0–1 over clip duration
    @Published var waveformSamples:   [Float] = []
    @Published var isWetMode:         Bool = true

    // MARK: AVAudioEngine graph
    private let engine       = AVAudioEngine()
    private let playerNode   = AVAudioPlayerNode()
    private let eqNode       = AVAudioUnitEQ(numberOfBands: 5)
    // AVAudioUnitDynamicsProcessor was removed in iOS 26; use AVAudioUnitEffect
    // with kAudioUnitSubType_DynamicsProcessor from AudioToolbox instead.
    private let compNode: AVAudioUnitEffect = {
        let desc = AudioComponentDescription(
            componentType:         kAudioUnitType_Effect,
            componentSubType:      kAudioUnitSubType_DynamicsProcessor,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags:        0,
            componentFlagsMask:    0
        )
        return AVAudioUnitEffect(audioComponentDescription: desc)
    }()
    private let reverbNode   = AVAudioUnitReverb()
    private let delayNode    = AVAudioUnitDelay()

    // MARK: Recording bookkeeping
    private var recordedFileURL: URL?
    private var recordedFile:    AVAudioFile?
    private var recordTimer:     Timer?
    private let maxDuration:     TimeInterval = 15.0
    private var recordStartTime: Date?
    private var progressTimer:   Timer?

    // MARK: Playback bookkeeping
    private var playbackTimer:   Timer?
    private var clipDuration:    TimeInterval = 0

    // MARK: - Init

    private init() {
        buildGraph()
        registerInterruptionObserver()
    }

    private func registerInterruptionObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    // MARK: - AVAudioEngine Graph Construction

    private func buildGraph() {
        engine.attach(playerNode)
        engine.attach(eqNode)
        engine.attach(compNode)
        engine.attach(reverbNode)
        engine.attach(delayNode)

        // Player → EQ → Compressor → Reverb → Delay → MainMixer
        // Use nil format: AVAudioEngine negotiates sample rate automatically after
        // the AVAudioSession is configured (avoids init-time vs recording-time mismatch).
        engine.connect(playerNode,  to: eqNode,     format: nil)
        engine.connect(eqNode,      to: compNode,   format: nil)
        engine.connect(compNode,    to: reverbNode, format: nil)
        engine.connect(reverbNode,  to: delayNode,  format: nil)
        engine.connect(delayNode,   to: engine.mainMixerNode, format: nil)

        configureEQDefaults()
    }

    private func configureEQDefaults() {
        // Band 0: High-pass filter — removes low rumble
        eqNode.bands[0].filterType = .highPass
        eqNode.bands[0].frequency  = 120.0
        eqNode.bands[0].bypass     = false

        // Band 1: Low shelf — warmth EQ
        eqNode.bands[1].filterType = .lowShelf
        eqNode.bands[1].frequency  = 200.0
        eqNode.bands[1].gain       = 0.0
        eqNode.bands[1].bypass     = false

        // Band 2: Low-mid parametric
        eqNode.bands[2].filterType = .parametric
        eqNode.bands[2].frequency  = 400.0
        eqNode.bands[2].gain       = 0.0
        eqNode.bands[2].bandwidth  = 1.0   // octaves (≈ Q of 1)
        eqNode.bands[2].bypass     = false

        // Band 3: High-mid parametric
        eqNode.bands[3].filterType = .parametric
        eqNode.bands[3].frequency  = 3000.0
        eqNode.bands[3].gain       = 0.0
        eqNode.bands[3].bandwidth  = 1.0
        eqNode.bands[3].bypass     = false

        // Band 4: High shelf — brightness EQ
        eqNode.bands[4].filterType = .highShelf
        eqNode.bands[4].frequency  = 8000.0
        eqNode.bands[4].gain       = 0.0
        eqNode.bands[4].bypass     = false
    }

    // MARK: - AVAudioSession Configuration

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,       // disables iOS noise reduction / AGC
            options: [.defaultToSpeaker, .allowBluetooth]
        )
        try session.setActive(true)
    }

    @objc private nonisolated func handleInterruption(_ note: Notification) {
        guard
            let info = note.userInfo,
            let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else { return }

        Task { @MainActor in
            if type == .began {
                if self.state == .playing   { self.stopPlayback() }
                if self.state == .recording { self.stopRecording() }
            } else if type == .ended {
                try? AVAudioSession.sharedInstance().setActive(true)
            }
        }
    }

    // MARK: - Microphone Permission

    private func requestMicPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Recording

    func startRecording() async throws {
        guard await requestMicPermission() else {
            throw AudioEngineError.micPermissionDenied
        }
        do { try configureSession() }
        catch { throw AudioEngineError.sessionSetupFailed(error) }

        // Defensively remove any leftover tap from a previous (possibly failed) session.
        engine.inputNode.removeTap(onBus: 0)

        // Stop the engine if still running from a previous playback session.
        if engine.isRunning { engine.stop() }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("aaikyam_clip.caf")

        // After configureSession(), the input node reports the hardware format correctly.
        let inputFormat = engine.inputNode.outputFormat(forBus: 0)

        // Validate format — fall back to 44100 Hz mono PCM if sample rate is 0
        let fileSettings: [String: Any]
        if inputFormat.sampleRate > 0 {
            fileSettings = inputFormat.settings
        } else {
            fileSettings = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
        }
        recordedFile    = try AVAudioFile(forWriting: url, settings: fileSettings)
        recordedFileURL = url

        // Use nil format so AVAudioEngine matches the tap to the node's native format.
        engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] buffer, _ in
            guard let self else { return }
            try? self.recordedFile?.write(from: buffer)
            self.extractWaveformSample(from: buffer)
        }

        do { try engine.start() }
        catch { throw AudioEngineError.engineStartFailed(error) }

        state           = .recording
        waveformSamples = []
        recordStartTime = Date()
        recordingProgress = 0

        // Auto-stop at 15 s
        recordTimer = Timer.scheduledTimer(withTimeInterval: maxDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.stopRecording() }
        }

        // Progress ticker (updates every 100 ms)
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] t in
            Task { @MainActor [weak self] in
                guard let self, self.state == .recording, let start = self.recordStartTime else {
                    t.invalidate(); return
                }
                self.recordingProgress = Float(min(Date().timeIntervalSince(start) / self.maxDuration, 1.0))
            }
        }
    }

    func stopRecording() {
        progressTimer?.invalidate()
        progressTimer = nil
        recordTimer?.invalidate()
        recordTimer = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        recordedFile = nil

        // Cache clip duration for playback progress
        if let url = recordedFileURL,
           let f   = try? AVAudioFile(forReading: url) {
            clipDuration = Double(f.length) / f.processingFormat.sampleRate
        }

        state             = .recorded
        recordingProgress = 0
    }

    // MARK: - Looping Playback

    func startPlayback() {
        guard let url = recordedFileURL,
              let file = try? AVAudioFile(forReading: url) else { return }

        if !engine.isRunning { try? engine.start() }
        scheduleLoop(file: file, url: url)
        playerNode.play()
        state           = .playing
        playbackProgress = 0

        // Playback progress ticker
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.state == .playing, self.clipDuration > 0 else { return }
                if let nodeTime = self.playerNode.lastRenderTime,
                   let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) {
                    let elapsed = Double(playerTime.sampleTime) / playerTime.sampleRate
                    let loopPos = elapsed.truncatingRemainder(dividingBy: self.clipDuration)
                    self.playbackProgress = Float(loopPos / self.clipDuration)
                }
            }
        }
    }

    private func scheduleLoop(file: AVAudioFile, url: URL) {
        playerNode.scheduleFile(file, at: nil) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.state == .playing,
                      let f = try? AVAudioFile(forReading: url) else { return }
                self.scheduleLoop(file: f, url: url)
            }
        }
    }

    func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        playerNode.stop()
        if engine.isRunning { engine.stop() }
        state            = .recorded
        playbackProgress = 0
    }

    // MARK: - Dry / Wet Bypass

    /// Bypasses all 4 effect nodes simultaneously (Wet=false → Dry).
    func setWetMode(_ wet: Bool) {
        isWetMode     = wet
        let bypass    = !wet
        eqNode.bypass    = bypass
        compNode.bypass  = bypass
        reverbNode.bypass = bypass
        delayNode.bypass  = bypass
    }

    // MARK: - Apply DSP Parameters

    /// Apply all 21 PresetParameters to the AVAudioUnit graph.
    /// Safe to call while playing — AVAudioUnit parameter updates are real-time thread safe.
    func applyParameters(_ params: PresetParameters) {
        // EQ — HPF
        eqNode.bands[0].frequency = params.hpfCutoff

        // EQ — Low shelf
        eqNode.bands[1].frequency = params.eqLowFreq
        eqNode.bands[1].gain      = params.eqLowGain

        // EQ — Low-mid parametric (bandwidth in octaves ≈ 1/Q)
        eqNode.bands[2].frequency = params.eqLowMidFreq
        eqNode.bands[2].gain      = params.eqLowMidGain
        eqNode.bands[2].bandwidth = max(0.05, min(5.0, 1.0 / params.eqLowMidQ))

        // EQ — High-mid parametric
        eqNode.bands[3].frequency = params.eqHighMidFreq
        eqNode.bands[3].gain      = params.eqHighMidGain
        eqNode.bands[3].bandwidth = max(0.05, min(5.0, 1.0 / params.eqHighMidQ))

        // EQ — High shelf
        eqNode.bands[4].frequency = params.eqHighFreq
        eqNode.bands[4].gain      = params.eqHighGain

        // Compressor — set via AudioUnitSetParameter (AVAudioUnitDynamicsProcessor removed in iOS 26)
        // headRoom approximates ratio: higher ratio → tighter compression → lower headRoom
        let au = compNode.audioUnit
        AudioUnitSetParameter(au, kDynamicsProcessorParam_Threshold,   kAudioUnitScope_Global, 0, params.compThreshold, 0)
        AudioUnitSetParameter(au, kDynamicsProcessorParam_HeadRoom,    kAudioUnitScope_Global, 0, max(0.1, 40.0 / params.compRatio), 0)
        AudioUnitSetParameter(au, kDynamicsProcessorParam_AttackTime,  kAudioUnitScope_Global, 0, params.compAttack  / 1000.0, 0)
        AudioUnitSetParameter(au, kDynamicsProcessorParam_ReleaseTime, kAudioUnitScope_Global, 0, params.compRelease / 1000.0, 0)
        AudioUnitSetParameter(au, kDynamicsProcessorParam_OverallGain, kAudioUnitScope_Global, 0, params.compMakeup, 0)

        // Reverb — use reverbPresetIndex (computed Int, clamped 0–12)
        if let rvPreset = AVAudioUnitReverbPreset(rawValue: params.reverbPresetIndex) {
            reverbNode.loadFactoryPreset(rvPreset)
        }
        reverbNode.wetDryMix = params.reverbMix * 100   // 0–1 → 0–100

        // Delay
        delayNode.delayTime  = TimeInterval(params.delayTime / 1000.0)  // ms → s
        delayNode.feedback   = params.delayFeedback * 100               // 0–1 → 0–100 %
        delayNode.wetDryMix  = params.delayMix * 100                    // 0–1 → 0–100
    }

    // MARK: - Waveform Sample Extraction

    /// Called from the audio tap (background thread). Posts samples to main actor.
    private nonisolated func extractWaveformSample(from buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        var peak: Float = 0

        // Compute peak RMS in 64-sample chunks
        stride(from: 0, to: frameLength, by: 64).forEach { start in
            let end   = min(start + 64, frameLength)
            let count = end - start
            var sum: Float = 0
            for i in 0..<count { sum += data[start + i] * data[start + i] }
            peak = max(peak, sqrt(sum / Float(count)))
        }

        Task { @MainActor [weak self] in
            self?.waveformSamples.append(peak)
        }
    }
}
