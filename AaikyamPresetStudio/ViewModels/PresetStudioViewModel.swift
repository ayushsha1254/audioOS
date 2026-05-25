import Foundation
import Combine

@MainActor
final class PresetStudioViewModel: ObservableObject {

    // MARK: - Published state

    @Published var preset:          PresetModel
    @Published var sliders:         SimpleSliders
    @Published var isAdvancedMode:  Bool = false
    @Published var isSaving:        Bool = false
    @Published var saveError:       String?
    @Published var showNamePrompt:  Bool = false
    @Published var presetName:      String = ""
    @Published var didSave:         Bool = false

    // Forwarded from AudioEngineManager
    var engineState:      AudioEngineState { audio.state }
    var waveformSamples:  [Float]  { audio.waveformSamples }
    var recordingProgress: Float   { audio.recordingProgress }
    var playbackProgress:  Float   { audio.playbackProgress }
    var isWetMode:         Bool    { audio.isWetMode }

    // MARK: - Dependencies

    private let audio:        AudioEngineManager
    private let service:      PresetRepository
    private let artistId:     UUID
    private let isNewPreset:  Bool

    // MARK: - Init

    init(
        preset:    PresetModel? = nil,
        artistId:  UUID,
        audio:     AudioEngineManager = .shared,
        service:   PresetRepository
    ) {
        self.artistId    = artistId
        self.audio       = audio
        self.service     = service
        self.isNewPreset = (preset == nil)
        let p = preset ?? {
            var blank = PresetModel.blank
            blank.artistId = artistId
            return blank
        }()
        self.preset      = p
        self.sliders     = PresetParameterMapper.slidersFromParameters(p.parameters)
        self.presetName  = p.name
    }

    // MARK: - Starting presets / templates

    func applyTemplate(_ template: PresetModel) {
        preset.parameters = template.parameters
        sliders = PresetParameterMapper.slidersFromParameters(template.parameters)
        audio.applyParameters(preset.parameters)
    }

    // MARK: - Slider updates (simple mode)

    func updateBrightness(_ v: Float) { updateSlider(\SimpleSliders.brightness, to: v) }
    func updateWarmth(_ v: Float)     { updateSlider(\SimpleSliders.warmth,     to: v) }
    func updatePunch(_ v: Float)      { updateSlider(\SimpleSliders.punch,      to: v) }
    func updateSpace(_ v: Float)      { updateSlider(\SimpleSliders.space,      to: v) }
    func updateEcho(_ v: Float)       { updateSlider(\SimpleSliders.echo,       to: v) }

    private func updateSlider(_ kp: WritableKeyPath<SimpleSliders, Float>, to value: Float) {
        sliders[keyPath: kp]  = value
        preset.parameters     = PresetParameterMapper.parametersFromSliders(sliders)
        audio.applyParameters(preset.parameters)
    }

    // MARK: - Advanced mode parameter updates

    func updateParameter(_ kp: WritableKeyPath<PresetParameters, Float>, to value: Float) {
        preset.parameters[keyPath: kp] = value
        sliders = PresetParameterMapper.slidersFromParameters(preset.parameters)
        audio.applyParameters(preset.parameters)
    }

    // MARK: - Recording

    func tapRecord() async {
        switch audio.state {
        case .idle, .recorded:
            do { try await audio.startRecording() }
            catch { saveError = error.localizedDescription }
        case .recording:
            audio.stopRecording()
        case .playing:
            audio.stopPlayback()
        }
    }

    // MARK: - Playback

    func tapPlay() {
        if audio.state == .playing {
            audio.stopPlayback()
        } else {
            audio.applyParameters(preset.parameters)
            audio.startPlayback()
        }
    }

    func setWetMode(_ wet: Bool) {
        audio.setWetMode(wet)
    }

    // MARK: - Save flow

    /// Called by the Save button — shows name prompt if new, saves directly if editing.
    func initiateSave() {
        if isNewPreset {
            showNamePrompt = true
        } else {
            Task { await savePreset() }
        }
    }

    /// Called when user confirms the name prompt.
    func savePreset() async {
        isSaving = true
        saveError = nil

        preset.name     = presetName.trimmingCharacters(in: .whitespaces).isEmpty ? "My Preset" : presetName
        preset.artistId = artistId

        // Retry once on failure
        do {
            let saved = try await service.save(preset)
            preset = saved
            didSave = true
        } catch {
            do {
                let saved = try await service.save(preset)
                preset = saved
                didSave = true
            } catch {
                saveError = "Couldn't save: \(error.localizedDescription). Check your connection and try again."
            }
        }

        isSaving = false
    }
}
