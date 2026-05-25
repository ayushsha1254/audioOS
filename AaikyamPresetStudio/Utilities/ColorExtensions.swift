import SwiftUI

// MARK: - Hex color initializer

extension Color {
    /// Initialize from a hex string, e.g. "#E85A3A" or "E85A3A".
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Warm Paper design tokens

extension Color {
    /// Screen background — warm off-white
    static let warmBackground    = Color(hex: "#F5EFE6")
    /// Card surface — pure white
    static let warmCard          = Color.white
    /// Primary accent — warm red (record button, slider fill, waveform active bars)
    static let warmAccent        = Color(hex: "#E85A3A")
    /// Primary text / save button background / active chip
    static let warmPrimaryText   = Color(hex: "#1A1A1A")
    /// Secondary text — muted grey (labels, locked state hints)
    static let warmSecondaryText = Color(hex: "#AAAAAA")
    /// Track color — pale warm grey (slider track, dry/wet pill background, waveform inactive bars)
    static let warmTrack         = Color(hex: "#EDE7DC")
}
