import SwiftUI

/// BA6's Liquid Glass design tokens.
///
/// Centralised so every glass surface — panel, card, chip, button, tab
/// bar — pulls the same corner radii, motion timings, and glow tints.
/// Dark-first by design: every gradient starts from `surface.deep`.
enum Theme {
    enum Radius {
        static let chip: CGFloat = 14
        static let card: CGFloat = 20
        static let panel: CGFloat = 28
        static let sheet: CGFloat = 36
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Motion {
        /// The single source of truth for "BA6 feel". Tuned to feel
        /// alive but never twitchy — closer to iOS native scroll than
        /// to a marketing-page bounce.
        static let standard: Animation = .spring(response: 0.42, dampingFraction: 0.82, blendDuration: 0)
        static let snappy:   Animation = .spring(response: 0.28, dampingFraction: 0.86, blendDuration: 0)
        static let lazy:     Animation = .spring(response: 0.62, dampingFraction: 0.78, blendDuration: 0)
        static let stream:   Animation = .easeOut(duration: 0.18)
    }

    enum Surface {
        static let deep   = Color(red: 0.02, green: 0.02, blue: 0.04)
        static let mid    = Color(red: 0.06, green: 0.06, blue: 0.08)
        static let lifted = Color(red: 0.10, green: 0.10, blue: 0.12)
    }

    enum Glow {
        static let active   = Color.white.opacity(0.35)
        static let focus    = Color.white.opacity(0.20)
        static let success  = Color.green.opacity(0.40)
        static let warn     = Color.yellow.opacity(0.40)
        static let error    = Color.red.opacity(0.50)
    }

    /// Backdrop used by every full-screen feature surface.
    static var backdrop: some View {
        LinearGradient(
            colors: [Surface.deep, Surface.mid, Surface.deep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
