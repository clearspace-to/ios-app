import SwiftUI

/// Height reserved below scrollable content so the floating bottom bar never
/// permanently covers the last row. Content still scrolls *under* the glass.
enum BottomBarMetrics {
    static let height: CGFloat = 48
    static let bottomPadding: CGFloat = 12
    static var scrollInset: CGFloat { height + bottomPadding + 16 }
}

extension View {
    /// Apply to every scrollable screen that sits behind the floating bottom bar.
    func bottomBarInset() -> some View {
        contentMargins(.bottom, BottomBarMetrics.scrollInset, for: .scrollContent)
    }
}
