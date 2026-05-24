import XCTest
@testable import AaikyamPresetStudio

final class PresetParameterMapperTests: XCTestCase {

    // MARK: - Brightness → eq_high_gain  (−2 to +6 dB)

    func test_brightness_zero_givesMinusTwo() {
        let p = PresetParameterMapper.parametersFromSliders(SimpleSliders(brightness: 0, warmth: 0.5, punch: 0.5, space: 0, echo: 0))
        XCTAssertEqual(p.eqHighGain, -2.0, accuracy: 0.001)
    }

    func test_brightness_one_givesPlusSix() {
        let p = PresetParameterMapper.parametersFromSliders(SimpleSliders(brightness: 1, warmth: 0.5, punch: 0.5, space: 0, echo: 0))
        XCTAssertEqual(p.eqHighGain, 6.0, accuracy: 0.001)
    }

    func test_brightness_half_givesTwo() {
        let p = PresetParameterMapper.parametersFromSliders(SimpleSliders(brightness: 0.5, warmth: 0.5, punch: 0.5, space: 0, echo: 0))
        XCTAssertEqual(p.eqHighGain, 2.0, accuracy: 0.001)
    }

    // MARK: - Warmth → eq_low_gain (0 to +4) + eq_high_mid_gain (0 to −2)

    func test_warmth_zero_givesZeroLowGain() {
        let p = PresetParameterMapper.parametersFromSliders(SimpleSliders(brightness: 0.5, warmth: 0, punch: 0.5, space: 0, echo: 0))
        XCTAssertEqual(p.eqLowGain,     0.0, accuracy: 0.001)
        XCTAssertEqual(p.eqHighMidGain, 0.0, accuracy: 0.001)
    }

    func test_warmth_one_givesMaxLowGainAndReducedHighMid() {
        let p = PresetParameterMapper.parametersFromSliders(SimpleSliders(brightness: 0.5, warmth: 1, punch: 0.5, space: 0, echo: 0))
        XCTAssertEqual(p.eqLowGain,      4.0, accuracy: 0.001)
        XCTAssertEqual(p.eqHighMidGain, -2.0, accuracy: 0.001)
    }

    // MARK: - Punch → comp_threshold (−6 to −24) + comp_ratio (1.5 to 6)

    func test_punch_zero_givesHighThresholdLowRatio() {
        let p = PresetParameterMapper.parametersFromSliders(SimpleSliders(brightness: 0.5, warmth: 0.5, punch: 0, space: 0, echo: 0))
        XCTAssertEqual(p.compThreshold, -6.0, accuracy: 0.001)
        XCTAssertEqual(p.compRatio,      1.5, accuracy: 0.001)
    }

    func test_punch_one_givesLowThresholdHighRatio() {
        let p = PresetParameterMapper.parametersFromSliders(SimpleSliders(brightness: 0.5, warmth: 0.5, punch: 1, space: 0, echo: 0))
        XCTAssertEqual(p.compThreshold, -24.0, accuracy: 0.001)
        XCTAssertEqual(p.compRatio,       6.0, accuracy: 0.001)
    }

    // MARK: - Space → reverb_preset (0–12) + reverb_mix (0–0.5)

    func test_space_zero_givesNoReverb() {
        let p = PresetParameterMapper.parametersFromSliders(SimpleSliders(brightness: 0.5, warmth: 0.5, punch: 0.5, space: 0, echo: 0))
        XCTAssertEqual(p.reverbPreset, 0.0, accuracy: 0.001)
        XCTAssertEqual(p.reverbMix,    0.0, accuracy: 0.001)
    }

    func test_space_one_givesMaxReverbPresetAndMix() {
        let p = PresetParameterMapper.parametersFromSliders(SimpleSliders(brightness: 0.5, warmth: 0.5, punch: 0.5, space: 1, echo: 0))
        XCTAssertEqual(p.reverbPreset, 12.0, accuracy: 0.5)   // rounded to nearest integer preset
        XCTAssertEqual(p.reverbMix,     0.5, accuracy: 0.001)
    }

    // MARK: - Echo → delay_time (80–400 ms) + delay_feedback (0–0.5) + delay_mix (0–0.3)

    func test_echo_zero_givesMinDelayNoMix() {
        let p = PresetParameterMapper.parametersFromSliders(SimpleSliders(brightness: 0.5, warmth: 0.5, punch: 0.5, space: 0, echo: 0))
        XCTAssertEqual(p.delayTime,      80.0, accuracy: 0.001)
        XCTAssertEqual(p.delayFeedback,   0.0, accuracy: 0.001)
        XCTAssertEqual(p.delayMix,        0.0, accuracy: 0.001)
    }

    func test_echo_one_givesMaxDelay() {
        let p = PresetParameterMapper.parametersFromSliders(SimpleSliders(brightness: 0.5, warmth: 0.5, punch: 0.5, space: 0, echo: 1))
        XCTAssertEqual(p.delayTime,     400.0, accuracy: 0.001)
        XCTAssertEqual(p.delayFeedback,   0.5, accuracy: 0.001)
        XCTAssertEqual(p.delayMix,        0.3, accuracy: 0.001)
    }

    // MARK: - Inverse mapping

    func test_slidersFromParameters_invertsBrightness() {
        var params = PresetParameters()
        params.eqHighGain = 4.0   // t = (4 - (-2)) / (6 - (-2)) = 6/8 = 0.75
        let s = PresetParameterMapper.slidersFromParameters(params)
        XCTAssertEqual(s.brightness, 0.75, accuracy: 0.01)
    }

    func test_slidersFromParameters_invertsPunch() {
        var params = PresetParameters()
        params.compThreshold = -15.0   // t = (-15 - (-6)) / (-24 - (-6)) = -9/-18 = 0.5
        params.compRatio = 3.75
        let s = PresetParameterMapper.slidersFromParameters(params)
        XCTAssertEqual(s.punch, 0.5, accuracy: 0.01)
    }

    // MARK: - Roundtrip

    func test_roundtrip_preservesAllDimensions() {
        let original = SimpleSliders(brightness: 0.7, warmth: 0.4, punch: 0.6, space: 0.3, echo: 0.2)
        let params   = PresetParameterMapper.parametersFromSliders(original)
        let recovered = PresetParameterMapper.slidersFromParameters(params)

        XCTAssertEqual(recovered.brightness, original.brightness, accuracy: 0.01)
        XCTAssertEqual(recovered.warmth,     original.warmth,     accuracy: 0.01)
        XCTAssertEqual(recovered.punch,      original.punch,      accuracy: 0.01)
        XCTAssertEqual(recovered.space,      original.space,      accuracy: 0.02)
        XCTAssertEqual(recovered.echo,       original.echo,       accuracy: 0.01)
    }

    // MARK: - Clamping

    func test_slider_above1_clampedToMax() {
        let p = PresetParameterMapper.parametersFromSliders(SimpleSliders(brightness: 1.5, warmth: 0.5, punch: 0.5, space: 0, echo: 0))
        XCTAssertEqual(p.eqHighGain, 6.0, accuracy: 0.001)
    }

    func test_slider_belowZero_clampedToMin() {
        let p = PresetParameterMapper.parametersFromSliders(SimpleSliders(brightness: -0.5, warmth: 0.5, punch: 0.5, space: 0, echo: 0))
        XCTAssertEqual(p.eqHighGain, -2.0, accuracy: 0.001)
    }

    func test_slidersFromParameters_outOfRangeParam_clampedToOne() {
        // Supabase preset with out-of-range eq_high_gain (e.g. hand-edited) should not crash or exceed [0,1]
        var params = PresetParameters()
        params.eqHighGain = 20.0  // well above max of 6.0 dB
        let s = PresetParameterMapper.slidersFromParameters(params)
        XCTAssertEqual(s.brightness, 1.0, accuracy: 0.001)
    }
}
