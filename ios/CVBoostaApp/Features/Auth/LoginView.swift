import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var touchedEmail = false
    @State private var touchedPassword = false

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

    private var passwordError: String? {
        guard touchedPassword else { return nil }
        return password.isEmpty ? "Password is required." : nil
    }

    private var canSubmit: Bool {
        emailError == nil && passwordError == nil && !email.isEmpty && !password.isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: BoostaSpace.md) {
                    SectionHeader(
                        title: "Log In",
                        subtitle: "Use your CVBoosta website account credentials."
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

                            TextInputField(
                                title: "Password",
                                placeholder: "Your password",
                                text: $password,
                                secure: true,
                                textContentType: .password,
                                autocapitalization: .never,
                                errorText: passwordError
                            )
                            .onChange(of: password) { _, _ in touchedPassword = true }

                            PrimaryButton(
                                title: authViewModel.isSubmitting ? "Logging In..." : "Log In",
                                isLoading: authViewModel.isSubmitting,
                                isDisabled: !canSubmit
                            ) {
                                touchedEmail = true
                                touchedPassword = true
                                Task {
                                    await authViewModel.login(email: email, password: password)
                                }
                            }
                        }
                    }

                    if let errorMessage = authViewModel.errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    NavigationLink("Forgot password?") {
                        ForgotPasswordView()
                    }
                    .font(BoostaType.bodyStrong)
                    .foregroundStyle(BoostaColor.accent)

                    NavigationLink("Create account") {
                        RegisterView()
                    }
                    .font(BoostaType.bodyStrong)
                    .foregroundStyle(BoostaColor.accent)
                }
                .padding(BoostaSpace.md)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
