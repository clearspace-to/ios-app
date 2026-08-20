import SwiftUI

/// Navy brand login screen (mockup: Login). Single action — Microsoft SSO.
struct LoginView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var isSigningIn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Text("clearspace_")
                .font(.system(size: 30, weight: .bold, design: .default))
                .foregroundStyle(.white)
            Text("MOBILE")
                .font(.caption.weight(.medium))
                .kerning(1.5)
                .foregroundStyle(.white)
                .padding(.top, 6)
                .padding(.bottom, 44)

            Button {
                isSigningIn = true
                Task {
                    await auth.signInWithMicrosoft()
                    isSigningIn = false
                }
            } label: {
                HStack {
                    if isSigningIn {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "person.badge.key.fill")
                    }
                    Text("Sign in with Microsoft")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.blue)
            .disabled(isSigningIn)

            if let error = auth.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Theme.red)
                    .padding(.top, 14)
            }

            Button {
                auth.enterPreviewMode()
            } label: {
                Text("Explore with sample data")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .foregroundStyle(.white)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.22)))
            .padding(.top, 12)

            Text("Access is limited to Clearspace accounts.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 28)

            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.navy)
    }
}
