import SwiftUI

extension View {
    /// Apple Liquid Glass on iOS 26+, graceful material fallback earlier.
    /// Used only for floating chrome (the bottom bar) — everything else stays opaque.
    ///
    /// Apply to a Button's *label*, never to the Button itself: glass applied to a
    /// control participates in hit testing and swallows the control's own taps.
    @ViewBuilder
    func liquidGlass<S: InsettableShape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
                .contentShape(shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
                .contentShape(shape)
        }
    }
}
