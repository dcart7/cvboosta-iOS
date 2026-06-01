import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var email: String = ""
    @State private var password: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: BoostaSpace.md) {
                    Text("Welcome Back")
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

                            SecureField("Password", text: $password)
                                .padding(10)
                                .background(Color.white.opacity(0.45))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            Button(authViewModel.isSubmitting ? "Signing In..." : "Sign In") {
                                Task {
                                    await authViewModel.login(email: email, password: password)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(BoostaColor.accent)
                            .disabled(authViewModel.isSubmitting)
                        }
                    }

                    if let errorMessage = authViewModel.errorMessage {
                        Text(errorMessage)
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.danger)
                    }

                    NavigationLink("Create account") {
                        RegisterView()
                    }
                    .font(BoostaType.bodyStrong)

                    NavigationLink("Forgot password?") {
                        ForgotPasswordView()
                    }
                    .font(BoostaType.caption)
                }
                .padding(BoostaSpace.md)
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
