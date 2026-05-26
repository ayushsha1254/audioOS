import Foundation

// MARK: - Simple Sliders (artist-facing, 0.0–1.0)

/// Artist-facing abstraction over the DSP parameters.
/// Each slider maps 0.0–1.0 to a meaningful range via PresetParameterMapper.
/// Ephemeral UI state — not stored directly in Supabase (PresetParameters is persisted instead).
struct SimpleSliders: Equatable, Codable {
    var brightness: Float = 0.5  // → eq_high_gain: −2 to +6 dB at 8 kHz
    var warmth:     Float = 0.5  // → eq_low_gain: 0 to +4 dB; eq_high_mid_gain: 0 to −2 dB
    var punch:      Float = 0.5  // → comp_threshold: −6 to −24 dB; comp_ratio: 1.5 to 6.0
    var space:      Float = 0.0  // → reverb_preset: 0–12; reverb_mix: 0–0.5
    var echo:       Float = 0.0  // → delay_time: 80–400 ms; delay_feedback: 0–0.5; delay_mix: 0–0.3
}

// MARK: - PresetParameters (DSP floats, in-memory only)

/// In-memory representation of all DSP parameters.
/// Stored flat in Supabase using individual columns (not as a nested JSON blob).
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
    var reverbPreset:   Float = 0.0    // AVAudioUnitReverbPreset rawValue (0–12)
    var reverbMix:      Float = 0.0    // 0.0–1.0

    /// Safe accessor for AVAudioUnitReverb.loadFactoryPreset()
    var reverbPresetIndex: Int { max(0, min(12, Int(reverbPreset))) }

    // Delay — 3 params
    var delayTime:      Float = 80.0   // milliseconds
    var delayFeedback:  Float = 0.0    // 0.0–1.0
    var delayMix:       Float = 0.0    // 0.0–1.0
}

// MARK: - PresetModel (Supabase row — flat columns)

/// Represents one row in the `sound_presets` table.
/// Parameters are stored as individual flat columns (NOT a nested JSONB blob)
/// so this model is compatible with the existing web-app schema.
struct PresetModel: Identifiable, Equatable {
    var id:         UUID
    var name:       String
    var artistId:   UUID
    var createdAt:  Date?
    var updatedAt:  Date?
    var voiceType:  String?
    var parameters: PresetParameters

    // MARK: - Custom Codable (flat ↔ nested conversion)

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case artistId    = "artist_id"
        case createdAt   = "created_at"
        case updatedAt   = "updated_at"
        case voiceType   = "voice_type"
        // Flat parameter columns
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
        case compMakeup     = "comp_makeup_gain"   // web schema column name
        case reverbPreset   = "reverb_preset_val"  // added iOS column
        case reverbMix      = "reverb_mix"
        case delayTime      = "delay_time"
        case delayFeedback  = "delay_feedback"
        case delayMix       = "delay_mix"
    }
}

extension PresetModel: Codable {
    init(from decoder: Decoder) throws {
        let c       = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self,   forKey: .id)
        name        = try c.decode(String.self, forKey: .name)
        artistId    = try c.decode(UUID.self,   forKey: .artistId)
        createdAt   = try c.decodeIfPresent(Date.self,   forKey: .createdAt)
        updatedAt   = try c.decodeIfPresent(Date.self,   forKey: .updatedAt)
        voiceType   = try c.decodeIfPresent(String.self, forKey: .voiceType)

        // Rebuild PresetParameters from individual flat columns
        parameters = PresetParameters(
            hpfCutoff:     try c.decodeIfPresent(Float.self, forKey: .hpfCutoff)     ?? 120.0,
            eqLowFreq:     try c.decodeIfPresent(Float.self, forKey: .eqLowFreq)     ?? 200.0,
            eqLowGain:     try c.decodeIfPresent(Float.self, forKey: .eqLowGain)     ?? 0.0,
            eqLowMidFreq:  try c.decodeIfPresent(Float.self, forKey: .eqLowMidFreq)  ?? 400.0,
            eqLowMidGain:  try c.decodeIfPresent(Float.self, forKey: .eqLowMidGain)  ?? 0.0,
            eqLowMidQ:     try c.decodeIfPresent(Float.self, forKey: .eqLowMidQ)     ?? 1.0,
            eqHighMidFreq: try c.decodeIfPresent(Float.self, forKey: .eqHighMidFreq) ?? 3000.0,
            eqHighMidGain: try c.decodeIfPresent(Float.self, forKey: .eqHighMidGain) ?? 0.0,
            eqHighMidQ:    try c.decodeIfPresent(Float.self, forKey: .eqHighMidQ)    ?? 1.0,
            eqHighFreq:    try c.decodeIfPresent(Float.self, forKey: .eqHighFreq)    ?? 8000.0,
            eqHighGain:    try c.decodeIfPresent(Float.self, forKey: .eqHighGain)    ?? 0.0,
            compThreshold: try c.decodeIfPresent(Float.self, forKey: .compThreshold) ?? -6.0,
            compRatio:     try c.decodeIfPresent(Float.self, forKey: .compRatio)     ?? 1.5,
            compAttack:    try c.decodeIfPresent(Float.self, forKey: .compAttack)    ?? 10.0,
            compRelease:   try c.decodeIfPresent(Float.self, forKey: .compRelease)   ?? 80.0,
            compMakeup:    try c.decodeIfPresent(Float.self, forKey: .compMakeup)    ?? 0.0,
            reverbPreset:  try c.decodeIfPresent(Float.self, forKey: .reverbPreset)  ?? 0.0,
            reverbMix:     try c.decodeIfPresent(Float.self, forKey: .reverbMix)     ?? 0.0,
            delayTime:     try c.decodeIfPresent(Float.self, forKey: .delayTime)     ?? 80.0,
            delayFeedback: try c.decodeIfPresent(Float.self, forKey: .delayFeedback) ?? 0.0,
            delayMix:      try c.decodeIfPresent(Float.self, forKey: .delayMix)      ?? 0.0
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,       forKey: .id)
        try c.encode(name,     forKey: .name)
        try c.encode(artistId, forKey: .artistId)
        // createdAt / updatedAt are managed by Supabase — omit on write
        try c.encodeIfPresent(voiceType, forKey: .voiceType)

        // Flatten PresetParameters into individual columns
        let p = parameters
        try c.encode(p.hpfCutoff,     forKey: .hpfCutoff)
        try c.encode(p.eqLowFreq,     forKey: .eqLowFreq)
        try c.encode(p.eqLowGain,     forKey: .eqLowGain)
        try c.encode(p.eqLowMidFreq,  forKey: .eqLowMidFreq)
        try c.encode(p.eqLowMidGain,  forKey: .eqLowMidGain)
        try c.encode(p.eqLowMidQ,     forKey: .eqLowMidQ)
        try c.encode(p.eqHighMidFreq, forKey: .eqHighMidFreq)
        try c.encode(p.eqHighMidGain, forKey: .eqHighMidGain)
        try c.encode(p.eqHighMidQ,    forKey: .eqHighMidQ)
        try c.encode(p.eqHighFreq,    forKey: .eqHighFreq)
        try c.encode(p.eqHighGain,    forKey: .eqHighGain)
        try c.encode(p.compThreshold, forKey: .compThreshold)
        try c.encode(p.compRatio,     forKey: .compRatio)
        try c.encode(p.compAttack,    forKey: .compAttack)
        try c.encode(p.compRelease,   forKey: .compRelease)
        try c.encode(p.compMakeup,    forKey: .compMakeup)
        try c.encode(p.reverbPreset,  forKey: .reverbPreset)
        try c.encode(p.reverbMix,     forKey: .reverbMix)
        try c.encode(p.delayTime,     forKey: .delayTime)
        try c.encode(p.delayFeedback, forKey: .delayFeedback)
        try c.encode(p.delayMix,      forKey: .delayMix)
    }
}

// MARK: - Static preset templates

extension PresetModel {

    // Template IDs — deterministic
    private static let cafeSetID  = UUID(uuidString: "CAAAFE00-0000-0000-0000-000000000001")!
    private static let rawID      = UUID(uuidString: "CAAAFE00-0000-0000-0000-000000000002")!
    private static let bigRoomID  = UUID(uuidString: "CAAAFE00-0000-0000-0000-000000000003")!
    private static let blankID    = UUID(uuidString: "CAAAFE00-0000-0000-0000-000000000004")!
    private static let templateArtistID = UUID(uuidString: "CAAAFE00-0000-0000-FFFF-000000000000")!

    static let cafeSet = PresetModel(
        id: cafeSetID, name: "Cafe Set", artistId: templateArtistID,
        voiceType: "Singer",
        parameters: PresetParameters(
            hpfCutoff: 120, eqLowFreq: 200, eqLowGain: 2.5,
            eqLowMidFreq: 400, eqLowMidGain: -0.5, eqLowMidQ: 1.0,
            eqHighMidFreq: 3000, eqHighMidGain: 1.0, eqHighMidQ: 0.8,
            eqHighFreq: 8000, eqHighGain: 3.0,
            compThreshold: -12, compRatio: 2.5, compAttack: 15, compRelease: 100, compMakeup: 3.0,
            reverbPreset: 2, reverbMix: 0.25,
            delayTime: 80, delayFeedback: 0, delayMix: 0
        )
    )

    static let raw = PresetModel(
        id: rawID, name: "Raw", artistId: templateArtistID,
        voiceType: "Rapper",
        parameters: PresetParameters(
            hpfCutoff: 80, eqLowFreq: 200, eqLowGain: 0,
            eqLowMidFreq: 400, eqLowMidGain: 0, eqLowMidQ: 1.0,
            eqHighMidFreq: 3000, eqHighMidGain: 0, eqHighMidQ: 1.0,
            eqHighFreq: 8000, eqHighGain: 0,
            compThreshold: -18, compRatio: 4.0, compAttack: 5, compRelease: 50, compMakeup: 6.0,
            reverbPreset: 0, reverbMix: 0.05,
            delayTime: 80, delayFeedback: 0, delayMix: 0
        )
    )

    static let bigRoom = PresetModel(
        id: bigRoomID, name: "Big Room", artistId: templateArtistID,
        voiceType: "Singer",
        parameters: PresetParameters(
            hpfCutoff: 100, eqLowFreq: 200, eqLowGain: 1.0,
            eqLowMidFreq: 400, eqLowMidGain: -1.0, eqLowMidQ: 1.2,
            eqHighMidFreq: 3000, eqHighMidGain: 2.0, eqHighMidQ: 0.8,
            eqHighFreq: 8000, eqHighGain: 2.0,
            compThreshold: -15, compRatio: 3.0, compAttack: 10, compRelease: 80, compMakeup: 4.0,
            reverbPreset: 8, reverbMix: 0.4,
            delayTime: 180, delayFeedback: 0.2, delayMix: 0.15
        )
    )

    static let blank = PresetModel(
        id: blankID, name: "My Preset", artistId: templateArtistID,
        voiceType: nil,
        parameters: PresetParameters()
    )
}
