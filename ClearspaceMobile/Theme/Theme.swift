import SwiftUI

/// Clearspace brand colors on top of standard iOS semantics.
/// Everything else uses system colors so the app inherits light/dark mode for free.
enum Theme {
    /// Clearspace Light Blue — links, actions, accents.
    static let blue = Color(red: 0x3B / 255, green: 0xAB / 255, blue: 0xFF / 255)
    /// Clearspace Navy — brand surfaces (login, avatar chips).
    static let navy = Color(red: 0x32 / 255, green: 0x3D / 255, blue: 0x4C / 255)
    /// Destructive red used in the mockups.
    static let red = Color(red: 0xF0 / 255, green: 0x5A / 255, blue: 0x5A / 255)

    /// Badge palette for stages/statuses. Keyed loosely; unknown values fall back to gray.
    static func stageColor(_ name: String) -> Color {
        switch name.lowercased() {
        case let s where s.contains("identified"): return .blue
        case let s where s.contains("feasibility"): return .purple
        case let s where s.contains("design"): return .indigo
        case let s where s.contains("proposal"): return .orange
        case let s where s.contains("negotiat"): return .yellow
        case let s where s.contains("won") || s.contains("closed won") || s.contains("complete") || s.contains("approved"): return .green
        case let s where s.contains("lost") || s.contains("archive"): return .red
        case let s where s.contains("hold") || s.contains("pending"): return .gray
        case let s where s.contains("progress") || s.contains("active") || s.contains("sent"): return .teal
        // safe_space statuses
        case let s where s.contains("scheduled"): return .blue
        case let s where s.contains("open"): return .green
        case let s where s.contains("reviewed"): return .green
        case let s where s.contains("submitted"): return .blue
        case let s where s.contains("incident"): return .red
        case let s where s.contains("passed"): return .green
        // FPU states
        case let s where s.contains("filed"): return .green
        case let s where s.contains("procore"): return .blue
        case let s where s.contains("draft"): return .yellow
        case let s where s.contains("outstanding"): return .orange
        case let s where s.contains("done"): return .gray
        default: return .gray
        }
    }
}

extension View {
    /// Standard inset-grouped list styling used across all record screens.
    func clearspaceList() -> some View {
        self.listStyle(.insetGrouped)
    }
}
