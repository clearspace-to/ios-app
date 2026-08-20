import Foundation

enum AppEnvironment {
    /// Sample-data mode: modules serve mock data instead of calling the real APIs.
    ///
    /// Set by the `-preview` launch argument (UI tests, screenshots) or at runtime
    /// by "Explore with sample data" on the login screen. It must be a runtime flag,
    /// not just a launch argument — otherwise the button skips login while the
    /// modules keep calling live APIs with no token.
    private(set) static var isPreview = ProcessInfo.processInfo.arguments.contains("-preview")

    static func enableSampleData() {
        isPreview = true
    }
}
