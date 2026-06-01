import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var email: String = ""
    @State private var touchedEmail = false

    private var emailError: String? {
        guard touchedEmail else { return nil }
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Email is required."
        }
        if !email.isValidEmail {
            return "Enter a valid email address."
        }
        return nil
    }

    private var canSubmit: Bool {
        emailError == nil && !email.isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(
                    title: "Forgot Password",
                    subtitle: "We will send reset instructions to your email."
                )

                GlassCard {
                    VStack(spacing: BoostaSpace.sm) {
                        TextInputField(
                            title: "Email",
                            placeholder: "you@example.com",
                            text: $email,
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress,
                            autocapitalization: .never,
                            errorText: emailError
                        )
                        .onChange(of: email) { _, _ in touchedEmail = true }

                        PrimaryButton(
                            title: authViewModel.isSubmitting ? "Sending..." : "Send reset link",
                            isLoading: authViewModel.isSubmitting,
                            isDisabled: !canSubmit
                        ) {
                            touchedEmail = true
                            Task {
                                await authViewModel.sendPasswordReset(email: email)
                            }
                        }
                    }
                }

                if let infoMessage = authViewModel.infoMessage {
                    GlassCard {
                        Text(infoMessage)
                            .font(BoostaType.body)
                            .foregroundStyle(BoostaColor.primaryText)
                    }
                }

                if let errorMessage = authViewModel.errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                Spacer(minLength: 0)
            }
            .padding(BoostaSpace.md)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
            .environmentObject(AuthViewModel())
    }
}
