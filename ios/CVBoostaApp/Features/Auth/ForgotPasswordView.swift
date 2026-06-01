import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var email: String = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: BoostaSpace.md) {
                Text("Reset Password")
                    .font(BoostaType.title)

                GlassCard {
                    VStack(spacing: BoostaSpace.sm) {
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled(true)
                            .padding(10)
                            .background(Color.white.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Button(authViewModel.isSubmitting ? "Sending..." : "Send Reset Link") {
                            Task {
                                await authViewModel.sendPasswordReset(email: email)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BoostaColor.accent)
                        .disabled(authViewModel.isSubmitting)
                    }
                }

                if let infoMessage = authViewModel.infoMessage {
                    Text(infoMessage)
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                }

                if let errorMessage = authViewModel.errorMessage {
                    Text(errorMessage)
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.danger)
                }
            }
            .padding(BoostaSpace.md)
        }
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
            .environmentObject(AuthViewModel())
    }
}
