import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var acceptedTerms = false
    @State private var touched = Set<Field>()

    private enum Field: Hashable {
        case fullName
        case email
        case password
        case confirmPassword
        case terms
    }

    private var fullNameError: String? {
        guard touched.contains(.fullName) else { return nil }
        return fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Full name is required." : nil
    }

    private var emailError: String? {
        guard touched.contains(.email) else { return nil }
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Email is required."
        }
        if !email.isValidEmail {
            return "Enter a valid email address."
        }
        return nil
    }

    private var passwordError: String? {
        guard touched.contains(.password) else { return nil }
        if password.isEmpty {
            return "Password is required."
        }
        if password.count < 8 {
            return "Password must be at least 8 characters."
        }
        return nil
    }

    private var confirmPasswordError: String? {
        guard touched.contains(.confirmPassword) else { return nil }
        if confirmPassword.isEmpty {
            return "Confirm your password."
        }
        if confirmPassword != password {
            return "Passwords do not match."
        }
        return nil
    }

    private var termsError: String? {
        guard touched.contains(.terms), !acceptedTerms else { return nil }
        return "Please accept Terms and Privacy Policy."
    }

    private var canSubmit: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && email.isValidEmail
            && password.count >= 8
            && confirmPassword == password
            && acceptedTerms
    }

    private var isWideLayout: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        ZStack {
            AuthBackgroundView()

            ScrollView(showsIndicators: false) {
                Group {
                    if isWideLayout {
                        HStack(alignment: .top, spacing: BoostaSpace.lg) {
                            messagingColumn
                            formCard
                        }
                    } else {
                        VStack(alignment: .leading, spacing: BoostaSpace.lg) {
                            messagingColumn
                            formCard
                        }
                    }
                }
                .padding(.horizontal, BoostaSpace.lg)
                .padding(.top, BoostaSpace.xl)
                .padding(.bottom, BoostaSpace.xxl)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var messagingColumn: some View {
        VStack(alignment: .leading, spacing: BoostaSpace.md) {
            BrandMarkView(size: 64)
                .staggered(index: 0)

            AuthHeadlineBlock(
                eyebrow: "Create account",
                title: "Start clean.",
                subtitle: "One account for web, iPhone, and iPad."
            )
            .staggered(index: 1)

            HStack(spacing: BoostaSpace.sm) {
                AuthStatPill(title: "ATS", detail: "See what to improve.")
                AuthStatPill(title: "Native", detail: "Minimal, focused flow.")
            }
            .staggered(index: 2)
        }
        .frame(maxWidth: isWideLayout ? 420 : .infinity, alignment: .leading)
    }

    private var formCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Create account")
                        .font(BoostaType.title)
                        .foregroundStyle(BoostaColor.primaryText)
                    Text("Use one CVBoosta account everywhere.")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                }

                VStack(spacing: BoostaSpace.sm) {
                    TextInputField(
                        title: "Full name",
                        placeholder: "Denys Ivshyn",
                        text: $fullName,
                        textContentType: .name,
                        errorText: fullNameError
                    )
                    .onChange(of: fullName) { _, _ in touched.insert(.fullName) }

                    TextInputField(
                        title: "Email",
                        placeholder: "you@example.com",
                        text: $email,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress,
                        autocapitalization: .never,
                        errorText: emailError
                    )
                    .onChange(of: email) { _, _ in touched.insert(.email) }

                    TextInputField(
                        title: "Password",
                        placeholder: "Minimum 8 characters",
                        text: $password,
                        secure: true,
                        textContentType: .newPassword,
                        autocapitalization: .never,
                        errorText: passwordError
                    )
                    .onChange(of: password) { _, _ in touched.insert(.password) }

                    TextInputField(
                        title: "Confirm password",
                        placeholder: "Confirm password",
                        text: $confirmPassword,
                        secure: true,
                        textContentType: .newPassword,
                        autocapitalization: .never,
                        errorText: confirmPasswordError
                    )
                    .onChange(of: confirmPassword) { _, _ in touched.insert(.confirmPassword) }
                }

                VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                    Toggle(isOn: $acceptedTerms) {
                        Text("I agree to the Terms and Privacy Policy")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.primaryText)
                    }
                    .tint(BoostaColor.accent)
                    .onChange(of: acceptedTerms) { _, _ in touched.insert(.terms) }

                    if let termsError {
                        Text(termsError)
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.danger)
                    }
                }

                PrimaryButton(
                    title: authViewModel.isSubmitting ? "Creating account..." : "Create my CVBoosta account",
                    isLoading: authViewModel.isSubmitting,
                    isDisabled: !canSubmit
                ) {
                    touched = [.fullName, .email, .password, .confirmPassword, .terms]
                    Task {
                        await authViewModel.register(
                            displayName: fullName,
                            email: email,
                            password: password,
                            confirmPassword: confirmPassword
                        )
                    }
                }

                if let errorMessage = authViewModel.errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                HStack(spacing: 6) {
                    Text("Already with CVBoosta?")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                    NavigationLink("Log in") {
                        LoginView()
                    }
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.accentSecondary)
                }
            }
        }
        .frame(maxWidth: isWideLayout ? 440 : .infinity, alignment: .leading)
        .staggered(index: 2)
    }
}

#Preview {
    NavigationStack {
        RegisterView()
            .environmentObject(AuthViewModel())
    }
}
