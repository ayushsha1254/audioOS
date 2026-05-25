import SwiftUI

struct PresetStudioView: View {
    @StateObject private var vm: PresetStudioViewModel
    @Environment(\.dismiss) private var dismiss

    init(preset: PresetModel? = nil, artistId: UUID, service: PresetRepository) {
        _vm = StateObject(wrappedValue: PresetStudioViewModel(
            preset: preset,
            artistId: artistId,
            service: service
        ))
    }

    var body: some View {
        ZStack {
            Color.warmBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    navHeader
                    startFromSection
                    recordCard
                    if vm.engineState != .idle { playbackRow }
                    effectsCard
                    saveButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        // Name prompt
        .alert("Name Your Preset", isPresented: $vm.showNamePrompt) {
            TextField("e.g. Cafe Set", text: $vm.presetName)
                .autocapitalization(.words)
            Button("Save") { Task { await vm.savePreset() } }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Give this preset a name so you can find it on the venue box.")
        }
        // Error alert
        .alert("Save Failed", isPresented: Binding(
            get: { vm.saveError != nil },
            set: { if !$0 { vm.saveError = nil } }
        )) {
            Button("Try Again") { Task { await vm.savePreset() } }
            Button("OK", role: .cancel) { }
        } message: {
            Text(vm.saveError ?? "")
        }
        .onChange(of: vm.didSave) { saved in
            if saved { dismiss() }
        }
    }

    // MARK: - Navigation Header

    private var navHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.warmPrimaryText)
            }
            Spacer()
            Text("My Sound")
                .font(.custom("Syne-Bold", size: 18))
                .foregroundColor(.warmPrimaryText)
            Spacer()
            // Balance spacer
            Image(systemName: "chevron.left").opacity(0)
        }
        .padding(.top, 8)
    }

    // MARK: - Start From Chips

    private var startFromSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start from")
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundColor(.warmSecondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("☀️ Cafe Set",    preset: .cafeSet)
                    chip("🌑 Raw",         preset: .raw)
                    chip("🏟️ Big Room",   preset: .bigRoom)
                    chip("🎤 Singer")      { vm.applyTemplate(.cafeSet) }
                    chip("🎤 Rapper")      { vm.applyTemplate(.raw) }
                    chip("🗣️ Spoken Word") { vm.applyTemplate(.raw) }
                    chip("➕ Blank")       { vm.applyTemplate(.blank) }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func chip(_ label: String, preset: PresetModel) -> some View {
        chip(label) { vm.applyTemplate(preset) }
    }

    private func chip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundColor(.warmPrimaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.warmTrack)
                .cornerRadius(20)
        }
    }

    // MARK: - Record Card

    private var recordCard: some View {
        VStack(spacing: 16) {
            recordButton
            WaveformView(
                samples:          vm.waveformSamples,
                playbackProgress: vm.engineState == .playing ? vm.playbackProgress : vm.recordingProgress,
                isRecording:      vm.engineState == .recording
            )
            .frame(height: 56)
            Text(recordStatusText)
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundColor(.warmSecondaryText)
        }
        .padding(20)
        .background(Color.warmCard)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private var recordButton: some View {
        Button(action: { Task { await vm.tapRecord() } }) {
            ZStack {
                Circle()
                    .fill(recordButtonFill)
                    .frame(width: 80, height: 80)
                    .shadow(color: recordButtonFill.opacity(0.35),
                            radius: vm.engineState == .recording ? 22 : 8)
                    .scaleEffect(vm.engineState == .recording ? 1.05 : 1.0)
                    .animation(
                        vm.engineState == .recording
                            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .default,
                        value: vm.engineState
                    )

                if vm.engineState == .recording {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .frame(width: 26, height: 26)
                } else {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 32, height: 32)
                }
            }
        }
    }

    private var recordButtonFill: Color {
        switch vm.engineState {
        case .idle, .recording: return .warmAccent
        case .recorded, .playing: return Color(hex: "#888888")
        }
    }

    private var recordStatusText: String {
        switch vm.engineState {
        case .idle:      return "Tap to record — up to 15 seconds"
        case .recording: return "Recording… tap to stop"
        case .recorded:  return "Tap record again to re-record"
        case .playing:   return "Looping — drag sliders to hear changes live"
        }
    }

    // MARK: - Playback Row

    private var playbackRow: some View {
        HStack(spacing: 12) {
            Button(action: { vm.tapPlay() }) {
                Label(
                    vm.engineState == .playing ? "Stop" : "Play",
                    systemImage: vm.engineState == .playing ? "stop.fill" : "play.fill"
                )
                .font(.custom("DMSans-Medium", size: 14))
                .foregroundColor(.warmPrimaryText)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.warmTrack)
                .cornerRadius(10)
            }

            HStack(spacing: 0) {
                dryWetPill("Dry", selected: !vm.isWetMode) { vm.setWetMode(false) }
                dryWetPill("Wet", selected: vm.isWetMode)  { vm.setWetMode(true) }
            }
            .background(Color.warmTrack)
            .cornerRadius(10)
        }
    }

    private func dryWetPill(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom(selected ? "DMSans-Medium" : "DMSans-Regular", size: 13))
                .foregroundColor(selected ? .white : .warmSecondaryText)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(selected ? Color.warmPrimaryText : Color.clear)
                .cornerRadius(8)
        }
    }

    // MARK: - Effects Card

    private var effectsCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Your Sound")
                    .font(.custom("Syne-Bold", size: 16))
                    .foregroundColor(.warmPrimaryText)
                Spacer()
                Button(action: { vm.isAdvancedMode.toggle() }) {
                    Label("Advanced", systemImage: "gearshape")
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundColor(.warmSecondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.warmTrack))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider().overlay(Color.warmTrack).padding(.horizontal, 20)

            if vm.isAdvancedMode {
                advancedSection
            } else {
                simpleSection
            }
        }
        .background(Color.warmCard)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .opacity(vm.engineState == .idle ? 0.45 : 1.0)
        .disabled(vm.engineState == .idle)
    }

    // MARK: Simple sliders

    private var simpleSection: some View {
        VStack(spacing: 14) {
            simpleSlider("✨ Brightness", value: Binding(
                get: { vm.sliders.brightness },
                set: { vm.updateBrightness($0) }
            ))
            simpleSlider("🔥 Warmth", value: Binding(
                get: { vm.sliders.warmth },
                set: { vm.updateWarmth($0) }
            ))
            simpleSlider("💪 Punch", value: Binding(
                get: { vm.sliders.punch },
                set: { vm.updatePunch($0) }
            ))
            simpleSlider("🌊 Space", value: Binding(
                get: { vm.sliders.space },
                set: { vm.updateSpace($0) }
            ))
            simpleSlider("🔁 Echo", value: Binding(
                get: { vm.sliders.echo },
                set: { vm.updateEcho($0) }
            ))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func simpleSlider(_ label: String, value: Binding<Float>) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundColor(.warmPrimaryText)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.custom("JetBrainsMono-Regular", size: 12))
                    .foregroundColor(.warmSecondaryText)
            }
            Slider(value: value, in: 0...1)
                .tint(.warmAccent)
        }
    }

    // MARK: Advanced sliders

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            advancedGroup("EQ") {
                advRow("HPF Cutoff",   \PresetParameters.hpfCutoff,      20...500,  "Hz")
                advRow("Low Gain",     \PresetParameters.eqLowGain,      -12...12,  "dB")
                advRow("Low-Mid Gain", \PresetParameters.eqLowMidGain,   -12...12,  "dB")
                advRow("High-Mid Gain", \PresetParameters.eqHighMidGain, -12...12,  "dB")
                advRow("High Gain",    \PresetParameters.eqHighGain,     -12...12,  "dB")
            }
            advancedGroup("Compressor") {
                advRow("Threshold", \PresetParameters.compThreshold, -40...0,    "dB")
                advRow("Ratio",     \PresetParameters.compRatio,     1...20,     ":1")
                advRow("Attack",    \PresetParameters.compAttack,    1...200,    "ms")
                advRow("Release",   \PresetParameters.compRelease,   10...1000,  "ms")
                advRow("Makeup",    \PresetParameters.compMakeup,    0...24,     "dB")
            }
            advancedGroup("Reverb") {
                advRow("Room Size", \PresetParameters.reverbPreset, 0...12, "")
                advRow("Mix",       \PresetParameters.reverbMix,    0...1,  "")
            }
            advancedGroup("Delay") {
                advRow("Time",     \PresetParameters.delayTime,     80...400, "ms")
                advRow("Feedback", \PresetParameters.delayFeedback, 0...0.9, "")
                advRow("Mix",      \PresetParameters.delayMix,      0...1,   "")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private func advancedGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(.warmSecondaryText)
                .textCase(.uppercase)
                .kerning(0.8)
            content()
        }
    }

    private func advRow(
        _ label: String,
        _ kp: WritableKeyPath<PresetParameters, Float>,
        _ range: ClosedRange<Float>,
        _ unit: String
    ) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundColor(.warmPrimaryText)
                Spacer()
                Text("\(String(format: range.upperBound > 10 ? "%.0f" : "%.2f", vm.preset.parameters[keyPath: kp]))\(unit)")
                    .font(.custom("JetBrainsMono-Regular", size: 11))
                    .foregroundColor(.warmSecondaryText)
            }
            Slider(value: Binding(
                get: { vm.preset.parameters[keyPath: kp] },
                set: { vm.updateParameter(kp, to: $0) }
            ), in: range)
            .tint(.warmAccent)
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: { vm.initiateSave() }) {
            HStack(spacing: 8) {
                if vm.isSaving {
                    ProgressView().tint(.white).scaleEffect(0.8)
                }
                Text(vm.isSaving ? "Saving…" : "Save Preset →")
                    .font(.custom("Syne-Bold", size: 16))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(vm.engineState == .idle
                        ? Color.warmSecondaryText
                        : Color.warmPrimaryText)
            .cornerRadius(14)
        }
        .disabled(vm.engineState == .idle || vm.isSaving)
    }
}

// MARK: - Preview

#Preview {
    PresetStudioView(
        preset: .cafeSet,
        artistId: UUID(),
        service: PreviewPresetService()
    )
}

private final class PreviewPresetService: PresetRepository {
    func loadAll(artistId: UUID) async throws -> [PresetModel] { [] }
    func save(_ p: PresetModel) async throws -> PresetModel { p }
    func delete(id: UUID) async throws { }
}
