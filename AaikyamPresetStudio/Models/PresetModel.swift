import Foundation

// MARK: - Simple Sliders (artist-facing, 0.0–1.0)

/// Artist-facing abstraction over the 21 DSP parameters.
/// Each slider maps 0.0–1.0 to a meaningful range via PresetParameterMapper.
/// Ephemeral UI state — not stored directly in Supabase (PresetParameters is persisted instead).
struct SimpleSliders: Equatable, Codable {
    var brightness: Float = 0.5  // → eq_high_gain: −2 to +6 dB at 8 kHz
    var warmth:     Float = 0.5  // → eq_low_gain: 0 to +4 dB; eq_high_mid_gain: 0 to −2 dB
    var punch:      Float = 0.5  // → comp_threshold: −6 to −24 dB; comp_ratio: 1.5 to 6.0
    var space:      Float = 0.0  // → reverb_preset: 0–12; reverb_mix: 0–0.5
    var echo:       Float = 0.0  // → delay_time: 80–400 ms; delay_feedback: 0–0.5; delay_mix: 0–0.3
}

// MARK: - PresetParameters (21 DSP floats, Codable, snake_case keys)

struct PresetParameters: Codable, Equatable {
    // EQ — 11 params
    var hpfCutoff:      Float = 120.0
    var eqLowFreq:      Float = 200.0
    var eqLowGain:      Float = 0.0
    var eqLowMidFreq:   Float = 400.0
    var eqLowMidGain:   Float = 0.0
    var eqLowMidQ:      Float = 1.0
    var eqHighMidFreq:  Float = 3000.0
    var eqHighMidGain:  Float = 0.0
    var eqHighMidQ:     Float = 1.0
    var eqHighFreq:     Float = 8000.0
    var eqHighGain:     Float = 0.0

    // Compressor — 5 params
    var compThreshold:  Float = -6.0
    var compRatio:      Float = 1.5
    var compAttack:     Float = 10.0   // milliseconds
    var compRelease:    Float = 80.0   // milliseconds
    var compMakeup:     Float = 0.0    // dB

    // Reverb — 2 params
    // Stores AVAudioUnitReverbPreset.rawValue as Float for JSON wire compatibility.
    // Values: 0=SmallRoom, 1=MediumRoom, 2=LargeRoom, ..., 12=LargeChamber
    // Use `reverbPresetIndex` when calling AVAudioUnitReverb.loadFactoryPreset()
    var reverbPreset:   Float = 0.0
    var reverbMix:      Float = 0.0   // 0.0–1.0

    /// Safe accessor for AVAudioUnitReverb.loadFactoryPreset() — clamps to valid range 0...12
    var reverbPresetIndex: Int { max(0, min(12, Int(reverbPreset))) }

    // Delay — 3 params
    var delayTime:      Float = 80.0  // milliseconds
    var delayFeedback:  Float = 0.0   // 0.0–1.0
    var delayMix:       Float = 0.0   // 0.0–1.0

    enum CodingKeys: String, CodingKey {
        case hpfCutoff      = "hpf_cutoff"
        case eqLowFreq      = "eq_low_freq"
        case eqLowGain      = "eq_low_gain"
        case eqLowMidFreq   = "eq_low_mid_freq"
        case eqLowMidGain   = "eq_low_mid_gain"
        case eqLowMidQ      = "eq_low_mid_q"
        case eqHighMidFreq  = "eq_high_mid_freq"
        case eqHighMidGain  = "eq_high_mid_gain"
        case eqHighMidQ     = "eq_high_mid_q"
        case eqHighFreq     = "eq_high_freq"
        case eqHighGain     = "eq_high_gain"
        case compThreshold  = "comp_threshold"
        case compRatio      = "comp_ratio"
        case compAttack     = "comp_attack"
        case compRelease    = "comp_release"
        case compMakeup     = "comp_makeup"
        case reverbPreset   = "reverb_preset"
        case reverbMix      = "reverb_mix"
        case delayTime      = "delay_time"
        case delayFeedback  = "delay_feedback"
        case delayMix       = "delay_mix"
    }
}

// MARK: - PresetModel (top-level Supabase row)

struct PresetModel: Codable, Identifiable, Equatable {
    var id:         UUID
    var name:       String
    var artistId:   UUID
    var createdAt:  Date?
    var updatedAt:  Date?
    var parameters: PresetParameters
    var voiceType:  String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case artistId  = "artist_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case parameters
        case voiceType = "voice_type"
    }

    // MARK: Static presets

    // Template IDs — deterministic so static presets are Equatable
    // artistId is intentionally a placeholder; callers set it before saving to Supabase
    private static let cafeSetTemplateID = UUID(uuidString: "CAAAFE00-0000-0000-0000-000000000001")!
    private static let rawTemplateID     = UUID(uuidString: "CAAAFE00-0000-0000-0000-000000000002")!
    private static let bigRoomTemplateID = UUID(uuidString: "CAAAFE00-0000-0000-0000-000000000003")!
    private static let blankTemplateID   = UUID(uuidString: "CAAAFE00-0000-0000-0000-000000000004")!
    private static let templateArtistID  = UUID(uuidString: "CAAAFE00-0000-0000-FFFF-000000000000")!

    static let cafeSet: PresetModel = PresetModel(
        id: cafeSetTemplateID, name: "Cafe Set", artistId: templateArtistID,
        parameters: PresetParameters(
            hpfCutoff: 120, eqLowFreq: 200, eqLowGain: 2.5,
            eqLowMidFreq: 400, eqLowMidGain: -0.5, eqLowMidQ: 1.0,
            eqHighMidFreq: 3000, eqHighMidGain: 1.0, eqHighMidQ: 0.8,
            eqHighFreq: 8000, eqHighGain: 3.0,
            compThreshold: -12, compRatio: 2.5, compAttack: 15, compRelease: 100, compMakeup: 3.0,
            reverbPreset: 2, reverbMix: 0.25,
            delayTime: 80, delayFeedback: 0, delayMix: 0
        ),
        voiceType: "Singer"
    )

    static let raw: PresetModel = PresetModel(
        id: rawTemplateID, name: "Raw", artistId: templateArtistID,
        parameters: PresetParameters(
            hpfCutoff: 80, eqLowFreq: 200, eqLowGain: 0,
            eqLowMidFreq: 400, eqLowMidGain: 0, eqLowMidQ: 1.0,
            eqHighMidFreq: 3000, eqHighMidGain: 0, eqHighMidQ: 1.0,
            eqHighFreq: 8000, eqHighGain: 0,
            compThreshold: -18, compRatio: 4.0, compAttack: 5, compRelease: 50, compMakeup: 6.0,
            reverbPreset: 0, reverbMix: 0.05,
            delayTime: 80, delayFeedback: 0, delayMix: 0
        ),
        voiceType: "Rapper"
    )

    static let bigRoom: PresetModel = PresetModel(
        id: bigRoomTemplateID, name: "Big Room", artistId: templateArtistID,
        parameters: PresetParameters(
            hpfCutoff: 100, eqLowFreq: 200, eqLowGain: 1.0,
            eqLowMidFreq: 400, eqLowMidGain: -1.0, eqLowMidQ: 1.2,
            eqHighMidFreq: 3000, eqHighMidGain: 2.0, eqHighMidQ: 0.8,
            eqHighFreq: 8000, eqHighGain: 2.0,
            compThreshold: -15, compRatio: 3.0, compAttack: 10, compRelease: 80, compMakeup: 4.0,
            reverbPreset: 8, reverbMix: 0.4,
            delayTime: 180, delayFeedback: 0.2, delayMix: 0.15
        ),
        voiceType: "Singer"
    )

    static let blank: PresetModel = PresetModel(
        id: blankTemplateID, name: "My Preset", artistId: templateArtistID,
        parameters: PresetParameters(),
        voiceType: nil
    )
}
