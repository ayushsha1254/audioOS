import SwiftUI

/// Renders a scrollable row of amplitude bars from an array of Float RMS samples.
///
/// - `samples`: RMS amplitudes (0.0–1.0), appended live during recording.
/// - `playbackProgress`: 0.0–1.0, bars to the left of this fraction are tinted accent.
/// - `isRecording`: when true all bars pulse in accent colour (recording animation).
struct WaveformView: View {
    let samples:          [Float]
    let playbackProgress: Float
    var isRecording:      Bool = false

    private let barWidth:     CGFloat = 3
    private let barSpacing:   CGFloat = 2
    private let minBarHeight: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let barCount = max(1, Int(geo.size.width / (barWidth + barSpacing)))
            let display  = resample(samples, to: barCount)

            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { i in
                    let amplitude = display[safe: i] ?? 0.1
                    let height    = max(minBarHeight, CGFloat(amplitude) * geo.size.height * 0.9)
                    let fraction  = Float(i) / Float(max(barCount - 1, 1))

                    RoundedRectangle(cornerRadius: 1.5)
                        .frame(width: barWidth, height: height)
                        .foregroundColor(barColor(atFraction: fraction))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    // MARK: - Helpers

    private func barColor(atFraction fraction: Float) -> Color {
        if isRecording {
            // Animate bars from dim to bright left-to-right during recording
            return Color.warmAccent.opacity(0.4 + Double(fraction) * 0.6)
        }
        return fraction < playbackProgress ? .warmAccent : .warmTrack
    }

    /// Nearest-neighbour resample of `samples` array to exactly `count` bars.
    private func resample(_ samples: [Float], to count: Int) -> [Float] {
        guard !samples.isEmpty, count > 0 else {
            return Array(repeating: 0.1, count: count)
        }
        return (0..<count).map { i in
            let idx = Int(Float(i) / Float(count) * Float(samples.count))
            return samples[min(idx, samples.count - 1)]
        }
    }
}

// MARK: - Safe collection subscript

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview("Recorded — playback at 40%") {
    WaveformView(
        samples: (0..<60).map { i in
            let t = Float(i) / 60
            return 0.2 + 0.8 * abs(sin(t * .pi * 4))
        },
        playbackProgress: 0.4
    )
    .frame(height: 56)
    .padding()
    .background(Color.warmBackground)
}

#Preview("Empty — recording") {
    WaveformView(
        samples: [],
        playbackProgress: 0,
        isRecording: true
    )
    .frame(height: 56)
    .padding()
    .background(Color.warmBackground)
}
