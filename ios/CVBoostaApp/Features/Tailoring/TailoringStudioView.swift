import SwiftUI

struct TailoringStudioView: View {
    @State private var selectedRole: String = "Backend Developer"
    @State private var originalBullet = "Built APIs for internal tools"
    @State private var rewrittenBullet = "Designed and shipped 14 production APIs, reducing partner integration time by 38% through typed contracts and observability-first rollout."

    private let roles = [
        "Backend Developer",
        "Data Analyst",
        "Product Manager",
        "DevOps Engineer",
        "Marketing Manager"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: BoostaSpace.md) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                                Text("Role-Specific Optimization")
                                    .font(BoostaType.section)

                                Picker("Target Role", selection: $selectedRole) {
                                    ForEach(roles, id: \.self) { role in
                                        Text(role).tag(role)
                                    }
                                }
                                .pickerStyle(.menu)

                                Text("Using CVBoosta keyword intelligence for \(selectedRole)")
                                    .font(BoostaType.caption)
                                    .foregroundStyle(BoostaColor.secondaryText)
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                                Text("Original Bullet")
                                    .font(BoostaType.caption)
                                    .foregroundStyle(BoostaColor.secondaryText)

                                Text(originalBullet)
                                    .font(BoostaType.body)

                                Divider()

                                Text("AI Rewrite")
                                    .font(BoostaType.caption)
                                    .foregroundStyle(BoostaColor.secondaryText)

                                Text(rewrittenBullet)
                                    .font(BoostaType.bodyStrong)

                                HStack {
                                    Label("+16 ATS score impact", systemImage: "arrow.up.right")
                                        .font(BoostaType.caption)
                                        .foregroundStyle(BoostaColor.success)
                                    Spacer()
                                }
                            }
                        }

                        Button("Generate 3 More Rewrites") {
                            HapticsService.impact(.medium)
                            rewrittenBullet = "Scaled event-driven backend architecture handling 12M monthly requests, cutting incident recovery time by 52% with proactive alerting and auto-rollbacks."
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BoostaColor.accent)
                    }
                    .padding(BoostaSpace.md)
                }
            }
            .navigationTitle("Tailoring Studio")
        }
    }
}

#Preview {
    TailoringStudioView()
}
