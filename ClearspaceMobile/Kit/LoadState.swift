import SwiftUI

/// Standard async load state for record screens.
enum LoadState<T> {
    case loading
    case loaded(T)
    case failed(String)
}

/// Full-screen states for loading/error/empty, shared by all list & detail screens.
struct LoadStateView: View {
    let message: String
    var isError: Bool = false
    var retry: (() async -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            if isError {
                Image(systemName: "wifi.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let retry {
                Button("Try Again") { Task { await retry() } }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
