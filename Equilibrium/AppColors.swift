import SwiftUI

// MARK: - Adaptive semantic colors
//
// Colors backed by asset-catalog entries so they work on iOS and watchOS,
// and respond to both the system appearance AND the per-app
// `.preferredColorScheme` override set in RootView.
//
// For text colors, use SwiftUI's built-in semantics directly:
//   .primary   → white in dark mode, near-black in light mode
//   .secondary → dimmer version of primary

extension Color {
    /// Deepest background — dark navy in dark mode, icy white in light mode.
    static let appBg = Color("AppBg")

    /// Elevated surface — sheets, input fields, cards.
    static let appSurface = Color("AppSurface")

    /// Subtle list-row tint — lighter than appBg in dark, a hair darker in light.
    static let appRowFill = Color("AppRowFill")

    /// Hairline / separator tint.
    static let appSeparator = Color("AppSeparator")
}
