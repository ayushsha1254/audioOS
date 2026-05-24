import Foundation

/// Converts between artist-facing SimpleSliders (0–1 each) and the 21 DSP floats in PresetParameters.
///
/// Forward mapping (parametersFromSliders): 5 sliders → 21 DSP params
/// Inverse mapping (slidersFromParameters): 21 DSP params → 5 sliders (uses primary param per dimension)
struct PresetParameterMapper {

    // MARK: - Forward: simple sliders → 21 DSP parameters

    static func parametersFromSliders(_ sliders: SimpleSliders) -> PresetParameters {
        var p = PresetParameters()

        // Brightness → eq_high_gain: −2 to +6 dB at 8 kHz
        p.eqHighGain    = lerp(sliders.brightness, from: -2.0, to: 6.0)

        // Warmth → eq_low_gain: 0 to +4 dB at 200 Hz
        //          eq_high_mid_gain: 0 to −2 dB at 3 kHz (cut harshness as warmth increases)
        p.eqLowGain     = lerp(sliders.warmth, from: 0.0, to: 4.0)
        p.eqHighMidGain = lerp(sliders.warmth, from: 0.0, to: -2.0)

        // Punch → comp_threshold: −6 to −24 dB (more punch = lower threshold = more compression)
        //         comp_ratio: 1.5 to 6.0
        p.compThreshold = lerp(sliders.punch, from: -6.0, to: -24.0)
        p.compRatio     = lerp(sliders.punch, from: 1.5, to: 6.0)

        // Space → reverb_preset: 0 (SmallRoom) to 12 (LargeChamber), rounded to nearest integer
        //         reverb_mix: 0 to 0.5
        p.reverbPreset  = lerp(sliders.space, from: 0.0, to: 12.0).rounded()
        p.reverbMix     = lerp(sliders.space, from: 0.0, to: 0.5)

        // Echo → delay_time: 80 to 400 ms
        //        delay_feedback: 0 to 0.5
        //        delay_mix: 0 to 0.3
        p.delayTime     = lerp(sliders.echo, from: 80.0, to: 400.0)
        p.delayFeedback = lerp(sliders.echo, from: 0.0, to: 0.5)
        p.delayMix      = lerp(sliders.echo, from: 0.0, to: 0.3)

        return p
    }

    // MARK: - Inverse: 21 DSP parameters → simple sliders
    // Uses the primary mapping parameter for each dimension.

    static func slidersFromParameters(_ params: PresetParameters) -> SimpleSliders {
        SimpleSliders(
            brightness: inverseLerp(params.eqHighGain,    from: -2.0, to: 6.0),
            warmth:     inverseLerp(params.eqLowGain,     from: 0.0,  to: 4.0),
            punch:      inverseLerp(params.compThreshold,  from: -6.0, to: -24.0),
            space:      inverseLerp(params.reverbMix,      from: 0.0,  to: 0.5),
            echo:       inverseLerp(params.delayMix,       from: 0.0,  to: 0.3)
        )
    }

    // MARK: - Math helpers

    /// Linear interpolation: maps t ∈ [0,1] → [from, to]. t is clamped to [0,1].
    static func lerp(_ t: Float, from: Float, to: Float) -> Float {
        from + (to - from) * t.clamped01
    }

    /// Inverse lerp: maps value ∈ [from, to] → [0,1]. Result is clamped.
    static func inverseLerp(_ value: Float, from: Float, to: Float) -> Float {
        guard to != from else { return 0.0 }
        return ((value - from) / (to - from)).clamped01
    }
}

// MARK: - Float clamping helpers

extension Float {
    /// Clamps the value to [0.0, 1.0].
    var clamped01: Float { Swift.max(0.0, Swift.min(1.0, self)) }

    func clamped(to r: ClosedRange<Float>) -> Float {
        Swift.max(r.lowerBound, Swift.min(r.upperBound, self))
    }
}

extension Int {
    func clamped(to r: ClosedRange<Int>) -> Int {
        Swift.max(r.lowerBound, Swift.min(r.upperBound, self))
    }
}
