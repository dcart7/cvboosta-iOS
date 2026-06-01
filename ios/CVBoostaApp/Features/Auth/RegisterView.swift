import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: BoostaSpace.md) {
                Text("Create Account")
                    .font(BoostaType.title)

                GlassCard {
                    VStack(spacing: BoostaSpace.sm) {
                        TextField("Display name (optional)", text: $displayName)
                            .padding(10)
                            .background(Color.white.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

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

                        SecureField("Confirm password", text: $confirmPassword)
                            .padding(10)
                            .background(Color.white.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Button(authViewModel.isSubmitting ? "Creating..." : "Create Account") {
                            Task {
                                await authViewModel.register(
                                    displayName: displayName,
                                    email: email,
                                    password: password,
                                    confirmPassword: confirmPassword
                                )
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
            }
            .padding(BoostaSpace.md)
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView()
            .environmentObject(AuthViewModel())
    }
}
