import XCTest
@testable import AaikyamPresetStudio

final class PresetModelTests: XCTestCase {

    // MARK: - PresetParameters encoding

    func test_presetParameters_encodesToSnakeCaseKeys() throws {
        let params = PresetParameters()
        let data = try JSONEncoder().encode(params)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["hpf_cutoff"],       "Missing hpf_cutoff")
        XCTAssertNotNil(json["eq_low_freq"],       "Missing eq_low_freq")
        XCTAssertNotNil(json["eq_low_mid_q"],      "Missing eq_low_mid_q")
        XCTAssertNotNil(json["comp_threshold"],    "Missing comp_threshold")
        XCTAssertNotNil(json["reverb_preset"],     "Missing reverb_preset")
        XCTAssertNotNil(json["delay_mix"],         "Missing delay_mix")
    }

    func test_presetParameters_has21Fields() throws {
        let data = try JSONEncoder().encode(PresetParameters())
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json.count, 21, "PresetParameters must encode exactly 21 fields")
    }

    // MARK: - PresetParameters decoding

    func test_presetParameters_decodesFromSpecJSON() throws {
        let jsonString = """
        {
            "hpf_cutoff": 120.0, "eq_low_freq": 200.0, "eq_low_gain": 2.5,
            "eq_low_mid_freq": 400.0, "eq_low_mid_gain": -1.0, "eq_low_mid_q": 1.2,
            "eq_high_mid_freq": 3000.0, "eq_high_mid_gain": 1.5, "eq_high_mid_q": 0.8,
            "eq_high_freq": 8000.0, "eq_high_gain": 3.0,
            "comp_threshold": -18.0, "comp_ratio": 3.5, "comp_attack": 10.0,
            "comp_release": 80.0, "comp_makeup": 4.0,
            "reverb_preset": 2.0, "reverb_mix": 0.25,
            "delay_time": 180.0, "delay_feedback": 0.2, "delay_mix": 0.15
        }
        """
        let params = try JSONDecoder().decode(PresetParameters.self, from: jsonString.data(using: .utf8)!)

        XCTAssertEqual(params.hpfCutoff,      120.0, accuracy: 0.001)
        XCTAssertEqual(params.eqLowGain,        2.5, accuracy: 0.001)
        XCTAssertEqual(params.eqLowMidQ,        1.2, accuracy: 0.001)
        XCTAssertEqual(params.compThreshold,  -18.0, accuracy: 0.001)
        XCTAssertEqual(params.reverbPreset,     2.0, accuracy: 0.001)
        XCTAssertEqual(params.delayMix,         0.15, accuracy: 0.001)
    }

    // MARK: - Static presets

    func test_cafeSet_hasCorrectNameAndReverb() {
        let preset = PresetModel.cafeSet
        XCTAssertEqual(preset.name, "Cafe Set")
        XCTAssertEqual(preset.parameters.reverbMix, 0.25, accuracy: 0.001)
        XCTAssertEqual(preset.parameters.delayMix,  0.0,  accuracy: 0.001)
    }

    func test_raw_hasNoReverbOrDelay() {
        let preset = PresetModel.raw
        XCTAssertEqual(preset.name, "Raw")
        XCTAssertLessThan(preset.parameters.reverbMix, 0.1)
        XCTAssertEqual(preset.parameters.delayMix, 0.0, accuracy: 0.001)
    }

    func test_bigRoom_hasHeavyReverbAndDelay() {
        let preset = PresetModel.bigRoom
        XCTAssertEqual(preset.name, "Big Room")
        XCTAssertGreaterThan(preset.parameters.reverbMix, 0.3)
        XCTAssertGreaterThan(preset.parameters.delayMix, 0.1)
    }

    func test_blank_hasNeutralValues() {
        let preset = PresetModel.blank
        XCTAssertEqual(preset.parameters.eqLowGain,    0.0, accuracy: 0.001)
        XCTAssertEqual(preset.parameters.reverbMix,    0.0, accuracy: 0.001)
        XCTAssertEqual(preset.parameters.delayMix,     0.0, accuracy: 0.001)
        XCTAssertEqual(preset.parameters.compMakeup,   0.0, accuracy: 0.001)
    }
}
