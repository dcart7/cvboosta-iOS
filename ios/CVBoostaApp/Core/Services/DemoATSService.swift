import Foundation

enum DemoATSService {
    static func mockScanResult(for role: String) -> ResumeScanResponse {
        ResumeScanResponse(
            atsScore: 77,
            keywordCoverage: 0.67,
            measurableImpactRatio: 0.52,
            readabilityScore: 0.83,
            recruiterSignalScore: 0.71,
            keywordGaps: ["observability", "distributed systems", "kubernetes", "incident response"],
            priorityFixes: [
                "Add measurable outcomes to 2 more bullets.",
                "Include 3 missing role terms naturally in impact bullets.",
                "Reframe summary to align with \(role) recruiter language."
            ],
            weakBulletExamples: [
                "Built APIs for internal tools",
                "Worked with cross-functional teams to improve platform",
                "Responsible for backend maintenance"
            ],
            rewriteSuggestions: [
                "Designed and shipped 14 production APIs, cutting partner integration time by 38%.",
                "Scaled event-driven services to 12M monthly requests with 99.95% uptime.",
                "Reduced incident recovery time by 52% with proactive alerting and auto-rollback workflows."
            ],
            findings: [
                ATSFinding(
                    category: "keywords",
                    severity: 3,
                    message: "Role keyword coverage is below top-decile candidate baseline.",
                    suggestion: "Embed missing terms in recent experience bullets and skills section."
                ),
                ATSFinding(
                    category: "impact",
                    severity: 3,
                    message: "Not enough quantified business impact signals.",
                    suggestion: "Add growth, savings, speed, reliability, or volume metrics."
                )
            ]
        )
    }
}
