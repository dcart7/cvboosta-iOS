import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

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
                        title: "Create Account",
                        subtitle: "Use the same account as on the CVBoosta website."
                    )

                    GlassCard {
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

                            Toggle(isOn: $acceptedTerms) {
                                Text("I agree to the Terms and Privacy Policy")
                                    .font(BoostaType.caption)
                                    .foregroundStyle(BoostaColor.primaryText)
                            }
                            .onChange(of: acceptedTerms) { _, _ in touched.insert(.terms) }
                            if let termsError {
                                Text(termsError)
                                    .font(BoostaType.caption)
                                    .foregroundStyle(BoostaColor.danger)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            PrimaryButton(
                                title: authViewModel.isSubmitting ? "Creating Account..." : "Create Account",
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
                        }
                    }

                    if let errorMessage = authViewModel.errorMessage {
                        ErrorBanner(message: errorMessage)
                    }
                }
                .padding(BoostaSpace.md)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        RegisterView()
            .environmentObject(AuthViewModel())
    }
}
