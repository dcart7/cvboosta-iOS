import Foundation
import UIKit

enum WorkspaceDailyFeature: String, CaseIterable, Codable {
    case coverLetter = "cover_letter"
    case interviewPrep = "interview_prep"

    var title: String {
        switch self {
        case .coverLetter:
            return "Cover Letter"
        case .interviewPrep:
            return "Interview Prep"
        }
    }

    var shortTitle: String {
        switch self {
        case .coverLetter:
            return "cover letters"
        case .interviewPrep:
            return "interview prep"
        }
    }
}

struct WorkspaceFeatureLimitStatus: Hashable {
    let feature: WorkspaceDailyFeature
    let dailyLimit: Int?
    let usedToday: Int
    let remainingToday: Int?
    let resetDate: Date

    var canUse: Bool {
        remainingToday == nil || (remainingToday ?? 0) > 0
    }

    var summary: String {
        if let dailyLimit, let remainingToday {
            return "\(remainingToday) left of \(dailyLimit) today"
        }
        if let remainingToday {
            return "\(remainingToday) left today"
        }
        return "Unlimited today"
    }
}

struct GeneratedCoverLetter: Codable, Hashable {
    let version: Int
    let createdAt: Date
    let title: String
    let subtitle: String
    let body: String
}

struct InterviewPrepQuestion: Codable, Hashable, Identifiable {
    let id: String
    let question: String
    let answer: String
    let focus: String
}

struct GeneratedInterviewPrep: Codable, Hashable {
    let version: Int
    let createdAt: Date
    let intro: String
    let questions: [InterviewPrepQuestion]
}

enum TrackerWorkspaceArtifactStore {
    private static let defaults = UserDefaults.standard
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func loadCoverLetter(for applicationID: UUID) -> GeneratedCoverLetter? {
        decode(GeneratedCoverLetter.self, forKey: coverLetterKey(for: applicationID))
    }

    static func saveCoverLetter(_ coverLetter: GeneratedCoverLetter, for applicationID: UUID) {
        encode(coverLetter, forKey: coverLetterKey(for: applicationID))
    }

    static func loadInterviewPrep(for applicationID: UUID) -> GeneratedInterviewPrep? {
        decode(GeneratedInterviewPrep.self, forKey: interviewPrepKey(for: applicationID))
    }

    static func saveInterviewPrep(_ interviewPrep: GeneratedInterviewPrep, for applicationID: UUID) {
        encode(interviewPrep, forKey: interviewPrepKey(for: applicationID))
    }

    private static func coverLetterKey(for applicationID: UUID) -> String {
        "cvboosta.workspace.coverLetter.\(applicationID.uuidString)"
    }

    private static func interviewPrepKey(for applicationID: UUID) -> String {
        "cvboosta.workspace.interviewPrep.\(applicationID.uuidString)"
    }

    private static func encode<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }
}

enum TrackerWorkspaceService {
    static func generateCoverLetter(for application: ApplicationRecord, version: Int) -> GeneratedCoverLetter {
        let focus = focusAreas(for: application, version: version)
        let openers = [
            "I am excited to be considered for this opportunity because it sits at the intersection of execution, ownership, and measurable impact.",
            "This role stands out to me because it combines practical delivery with the kind of momentum that compounds across a team.",
            "I am interested in this opening because it rewards thoughtful execution, fast learning, and strong collaboration."
        ]
        let bridges = [
            "What draws me most is the chance to bring clear thinking and consistent follow-through to work that matters.",
            "I would approach the role with a calm, data-aware mindset and a strong bias toward useful outcomes.",
            "My focus would be to ramp quickly, add signal early, and keep progress visible."
        ]
        let closers = [
            "Thank you for your time and consideration. I would welcome the chance to discuss how I could contribute to \(application.company).",
            "I would be glad to share more about the way I work, the pace I enjoy, and the outcomes I aim to create on a team like yours.",
            "I appreciate your review and would be excited to bring this level of focus and momentum to your team."
        ]

        let opener = openers[normalizedIndex(version, count: openers.count)]
        let bridge = bridges[normalizedIndex(version + 1, count: bridges.count)]
        let closer = closers[normalizedIndex(version + 2, count: closers.count)]

        let body = [
            "Dear Hiring Team at \(application.company),",
            opener,
            "I am applying for the \(application.role) role. Based on the context already captured in my tracker, I would position myself around \(focus[0]), \(focus[1]), and \(focus[2]). \(bridge)",
            "I work best in environments where priorities are clear, progress is visible, and execution quality matters. In this role, I would aim to translate requirements into dependable delivery, communicate tradeoffs early, and keep momentum strong from first draft to final result.",
            application.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? "A strong theme I would reinforce in conversation is this: \(application.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")"
                : "I would also emphasize adaptability, stakeholder alignment, and a habit of turning feedback into better output quickly.",
            closer
        ]
        .joined(separator: "\n\n")

        return GeneratedCoverLetter(
            version: version,
            createdAt: .now,
            title: "\(application.role) cover letter",
            subtitle: "Generated from tracker context for \(application.company)",
            body: body
        )
    }

    static func generateInterviewPrep(for application: ApplicationRecord, version: Int) -> GeneratedInterviewPrep {
        let focus = focusAreas(for: application, version: version + 2)
        let questionBank: [(question: String, answer: String, focus: String)] = [
            (
                "Walk me through your background and why this role at \(application.company) makes sense now.",
                "Answer in three beats: where you built momentum, which skill transfers most directly into the \(application.role) role, and why \(application.company) feels like the right next step. Keep it concise and outcome-focused.",
                focus[0]
            ),
            (
                "Tell me about a project that best represents the way you work.",
                "Choose one project with a clear goal, a concrete obstacle, and a measurable result. Emphasize the decisions you made, not just the tasks you completed.",
                focus[1]
            ),
            (
                "How do you prioritize when deadlines shift or inputs are incomplete?",
                "Show that you reduce ambiguity fast: clarify the decision-maker, identify the highest-leverage milestone, and communicate tradeoffs before risk grows.",
                "prioritization"
            ),
            (
                "What would your first 30 days look like in this role?",
                "Frame your answer around listening, mapping the system, and shipping something useful quickly. Hiring teams want evidence that you can create traction without noise.",
                "first-30-days plan"
            ),
            (
                "Describe a time you improved a process, metric, or quality bar.",
                "Use a before-and-after structure. Quantify the change, explain the intervention, and connect it to the kind of leverage this team values.",
                focus[2]
            ),
            (
                "How do you collaborate with cross-functional partners?",
                "Anchor the answer in clarity and rhythm: align on goals early, surface constraints before they become blockers, and keep decisions documented and easy to revisit.",
                "cross-functional communication"
            ),
            (
                "Tell me about a difficult tradeoff you had to make.",
                "Demonstrate judgment. Explain what mattered, what you intentionally did not optimize, and how you kept stakeholders aligned while moving forward.",
                "decision quality"
            ),
            (
                "What questions would you ask before starting this work?",
                "Show curiosity with structure: ask about success metrics, stakeholder expectations, technical constraints, and how the team currently defines a strong outcome.",
                "diagnostic thinking"
            )
        ]

        let rotated = rotatedItems(questionBank, seed: version)
        let selected = Array(rotated.prefix(5)).enumerated().map { index, item in
            InterviewPrepQuestion(
                id: "\(version)-\(index)-\(item.focus)",
                question: item.question,
                answer: item.answer,
                focus: item.focus.capitalized
            )
        }

        let intro = "Use these as flexible talking points for \(application.company). Re-generate to explore a different mix of angles and stories while staying anchored to the same role."

        return GeneratedInterviewPrep(
            version: version,
            createdAt: .now,
            intro: intro,
            questions: selected
        )
    }

    static func makeCoverLetterPDF(
        for application: ApplicationRecord,
        coverLetter: GeneratedCoverLetter
    ) throws -> URL {
        let fileName = "\(application.company)-\(application.role)-cover-letter-\(UUID().uuidString).pdf"
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        try renderer.writePDF(to: outputURL) { context in
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26, weight: .semibold),
                .foregroundColor: UIColor(red: 0.07, green: 0.13, blue: 0.22, alpha: 1)
            ]
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: UIColor(red: 0.28, green: 0.39, blue: 0.55, alpha: 1)
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12.5, weight: .regular),
                .foregroundColor: UIColor(red: 0.11, green: 0.14, blue: 0.20, alpha: 1)
            ]

            let margin: CGFloat = 44
            let contentWidth = pageRect.width - (margin * 2)
            let bottomLimit = pageRect.height - margin
            var currentY: CGFloat = margin

            func beginPage() {
                context.beginPage()
                currentY = margin
            }

            func draw(_ text: String, attributes: [NSAttributedString.Key: Any], spacingAfter: CGFloat) {
                let attributed = NSAttributedString(string: text, attributes: attributes)
                let size = attributed.boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).integral.size

                if currentY + size.height > bottomLimit {
                    beginPage()
                }

                attributed.draw(
                    in: CGRect(
                        x: margin,
                        y: currentY,
                        width: contentWidth,
                        height: size.height
                    )
                )
                currentY += size.height + spacingAfter
            }

            beginPage()
            draw(coverLetter.title, attributes: titleAttributes, spacingAfter: 8)
            draw(
                "\(application.company) • \(application.role) • \(coverLetter.createdAt.formatted(date: .abbreviated, time: .omitted))",
                attributes: subtitleAttributes,
                spacingAfter: 24
            )

            for paragraph in coverLetter.body.components(separatedBy: "\n\n") {
                let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                draw(trimmed, attributes: bodyAttributes, spacingAfter: 16)
            }
        }

        return outputURL
    }

    private static func focusAreas(for application: ApplicationRecord, version: Int) -> [String] {
        var values: [String] = []

        let roleTokens = application.role
            .replacingOccurrences(of: "/", with: " ")
            .split(separator: " ")
            .map(String.init)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count >= 4 }

        values.append(contentsOf: roleTokens.prefix(2).map { "\($0.lowercased()) execution" })

        switch application.status {
        case .saved:
            values.append("targeted positioning")
            values.append("clear next-step planning")
        case .applied:
            values.append("recruiter-facing clarity")
            values.append("follow-through after application")
        case .interview:
            values.append("storytelling under pressure")
            values.append("high-signal communication")
        case .offer:
            values.append("high-trust delivery")
            values.append("decision confidence")
        case .rejected:
            values.append("measurable impact framing")
            values.append("faster iteration")
        case .archived:
            values.append("pipeline organization")
            values.append("career signal quality")
        }

        if let notes = application.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
           !notes.isEmpty {
            values.append("context from tracker notes")
        }

        values.append(contentsOf: [
            "stakeholder alignment",
            "measurable outcomes",
            "systems thinking",
            "execution quality"
        ])

        let deduplicated = Array(NSOrderedSet(array: values)) as? [String] ?? values
        return Array(rotatedItems(deduplicated, seed: version).prefix(3))
    }

    private static func normalizedIndex(_ value: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return abs(value) % count
    }

    private static func rotatedItems<T>(_ items: [T], seed: Int) -> [T] {
        guard !items.isEmpty else { return [] }
        let index = normalizedIndex(seed, count: items.count)
        return Array(items[index...] + items[..<index])
    }
}
