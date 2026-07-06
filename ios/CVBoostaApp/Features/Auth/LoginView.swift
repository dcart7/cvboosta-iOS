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
            AuthBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BoostaSpace.lg) {
                    BrandMarkView(size: 60)
                        .staggered(index: 0)

                    AuthHeadlineBlock(
                        eyebrow: "Welcome back",
                        title: "Log in",
                        subtitle: "Continue with your CVBoosta account."
                    )
                    .staggered(index: 1)

                    GlassCard(padding: BoostaSpace.lg) {
                        VStack(alignment: .leading, spacing: BoostaSpace.md) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Use your CVBoosta website credentials.")
                                    .font(BoostaType.caption)
                                    .foregroundStyle(BoostaColor.secondaryText)
                            }

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
                                showsVisibilityToggle: true,
                                textContentType: .password,
                                autocapitalization: .never,
                                errorText: passwordError
                            )
                            .onChange(of: password) { _, _ in touchedPassword = true }

                            PrimaryButton(
                                title: authViewModel.isSubmitting ? "Logging in..." : "Continue to CVBoosta",
                                isLoading: authViewModel.isSubmitting,
                                isDisabled: !canSubmit
                            ) {
                                touchedEmail = true
                                touchedPassword = true
                                Task {
                                    await authViewModel.login(email: email, password: password)
                                }
                            }

                            AuthSectionDivider(title: "or")

                            AppleSignInActionButton(label: .signIn)

                            if let errorMessage = authViewModel.errorMessage {
                                ErrorBanner(message: errorMessage)
                            }

                            HStack(spacing: 14) {
                                NavigationLink("Forgot password?") {
                                    ForgotPasswordView()
                                }
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.accentSecondary)

                                Spacer()

                                NavigationLink("Create account") {
                                    RegisterView()
                                }
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.accentSecondary)
                            }
                        }
                    }
                    .staggered(index: 2)
                }
                .padding(.horizontal, BoostaSpace.lg)
                .padding(.top, 56)
                .padding(.bottom, BoostaSpace.xxl)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
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
