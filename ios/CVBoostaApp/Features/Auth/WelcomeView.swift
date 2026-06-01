import SwiftUI

struct WelcomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: BoostaSpace.lg) {
                    Spacer()

                    VStack(alignment: .leading, spacing: BoostaSpace.md) {
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(BoostaColor.accent)

                        Text("Get more interviews from the same experience.")
                            .font(BoostaType.title)
                            .foregroundStyle(BoostaColor.primaryText)

                        Text("Analyze, tailor, and improve your resume before ATS systems reject it.")
                            .font(BoostaType.body)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }

                    VStack(spacing: BoostaSpace.sm) {
                        NavigationLink {
                            RegisterView()
                        } label: {
                            Text("Create Account")
                                .font(BoostaType.bodyStrong)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, BoostaSpace.sm)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(BoostaColor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))

                        NavigationLink {
                            LoginView()
                        } label: {
                            Text("Log In")
                                .font(BoostaType.bodyStrong)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, BoostaSpace.sm)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(BoostaColor.primaryText)
                        .background(Color.white.opacity(0.65))
                        .overlay(
                            RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                                .stroke(BoostaColor.glassStroke, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
                    }

                    Text("Your resume data stays private and secure.")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Spacer(minLength: BoostaSpace.lg)
                }
                .padding(BoostaSpace.lg)
            }
        }
    }
}

#Preview {
    WelcomeView()
}
