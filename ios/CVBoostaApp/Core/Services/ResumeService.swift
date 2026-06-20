import Foundation
import UIKit

struct HistoryListResponse: Decodable, Hashable {
    let items: [HistoryListItem]
}

struct HistoryListItem: Decodable, Hashable, Identifiable {
    let id: Int
    let role: String?
    let company: String?
    let score: Int
    let createdAt: Date
    let matchBefore: Int?
    let matchAfter: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case company
        case score
        case createdAt = "created_at"
        case matchBefore = "match_before"
        case matchAfter = "match_after"
    }
}

struct HistoryDetailResponse: Decodable, Hashable {
    let id: Int
    let role: String?
    let company: String?
    let score: Int
    let createdAt: Date
    let optimizedCV: String
    let jobDescription: String
    let missingSkills: [String]
    let recommendations: [String]
    let matchBefore: Int?
    let matchAfter: Int?
    let addedKeywords: [String]
    let coverLetter: String?

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case company
        case score
        case createdAt = "created_at"
        case optimizedCV = "optimized_cv"
        case jobDescription = "job_description"
        case missingSkills = "missing_skills"
        case recommendations
        case matchBefore = "match_before"
        case matchAfter = "match_after"
        case addedKeywords = "added_keywords"
        case coverLetter = "cover_letter"
    }
}

enum ResumeExportFormat: String, CaseIterable, Identifiable {
    case pdf
    case docx
    case txt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pdf:
            return "ATS Optimized PDF"
        case .docx:
            return "Editable DOCX"
        case .txt:
            return "Plain Text for ATS Systems"
        }
    }

    var subtitle: String {
        switch self {
        case .pdf:
            return "Clean ATS-readable layout"
        case .docx:
            return "Word and Google Docs friendly"
        case .txt:
            return "Machine-readable export"
        }
    }

    var shareSuccessMessage: String {
        switch self {
        case .pdf:
            return "PDF ready to share"
        case .docx:
            return "DOCX ready to share"
        case .txt:
            return "TXT ready to share"
        }
    }

    var loadingTitle: String {
        switch self {
        case .pdf:
            return "Generating PDF…"
        case .docx:
            return "Generating DOCX…"
        case .txt:
            return "Generating TXT…"
        }
    }

    var fileExtension: String {
        rawValue
    }
}

struct ResumeExportShareItem: Identifiable {
    let id = UUID()
    let url: URL
    let format: ResumeExportFormat
}

private struct ResumeExportRequest {
    let resumeName: String
    let optimizedText: String
    let format: ResumeExportFormat
}

struct ResumeExportFile {
    let url: URL
    let format: ResumeExportFormat
}

@MainActor
final class ResumeExportController: ObservableObject {
    @Published var isExportOptionsPresented = false
    @Published var isExporting = false
    @Published var shareItem: ResumeExportShareItem?
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let resumeService: ResumeService
    private var lastRequest: ResumeExportRequest?
    private var successClearTask: Task<Void, Never>?
    private(set) var lastRequestedFormat: ResumeExportFormat?

    init(resumeService: ResumeService = .shared) {
        self.resumeService = resumeService
    }

    var primaryActionTitle: String {
        if isExporting {
            return lastRequestedFormat?.loadingTitle ?? "Preparing export…"
        }
        return "Download Resume"
    }

    func presentOptions() {
        guard !isExporting else { return }
        errorMessage = nil
        isExportOptionsPresented = true
    }

    func export(
        resumeName: String,
        optimizedText: String,
        format: ResumeExportFormat
    ) {
        guard !isExporting else { return }

        let trimmed = optimizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "No optimized resume is ready to export yet."
            return
        }

        isExporting = true
        errorMessage = nil
        lastRequestedFormat = format
        lastRequest = ResumeExportRequest(
            resumeName: resumeName,
            optimizedText: optimizedText,
            format: format
        )

        Task {
            do {
                let file = try await resumeService.exportResume(
                    resumeName: resumeName,
                    optimizedText: optimizedText,
                    format: format
                )
                await MainActor.run {
                    self.isExporting = false
                    self.shareItem = ResumeExportShareItem(url: file.url, format: format)
                    self.setSuccessMessage(format.shareSuccessMessage)
                    HapticsService.success()
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func retryLastExport() {
        guard let lastRequest else { return }
        export(
            resumeName: lastRequest.resumeName,
            optimizedText: lastRequest.optimizedText,
            format: lastRequest.format
        )
    }

    func cleanupSharedFile() {
        if let url = shareItem?.url {
            try? FileManager.default.removeItem(at: url)
        }
        shareItem = nil
    }

    private func setSuccessMessage(_ message: String) {
        successClearTask?.cancel()
        successMessage = message
        successClearTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.successMessage = nil
            }
        }
    }
}

final class ResumeService {
    static let shared = ResumeService()

    private let client: AuthenticatedAPIClient
    private let historyCache = ResumeHistoryCacheStore()

    init(client: AuthenticatedAPIClient = .shared) {
        self.client = client
    }

    func history(forceRefresh: Bool = false) async throws -> [HistoryListItem] {
        if !forceRefresh, let cached = await historyCache.cachedHistory() {
            return cached
        }

        if !forceRefresh, let inFlight = await historyCache.historyTask() {
            return try await inFlight.value
        }

        let task = Task<[HistoryListItem], Error> {
            let response: HistoryListResponse = try await client.getJSON(path: "/history")
            return response.items
        }
        await historyCache.setHistoryTask(task)

        do {
            let items = try await task.value
            await historyCache.storeHistory(items)
            return items
        } catch {
            await historyCache.clearHistoryTask()
            throw error
        }
    }

    func historyDetail(id: Int) async throws -> HistoryDetailResponse {
        if let cached = await historyCache.cachedDetail(for: id) {
            return cached
        }

        if let inFlight = await historyCache.detailTask(for: id) {
            return try await inFlight.value
        }

        let task = Task<HistoryDetailResponse, Error> {
            try await client.getJSON(path: "/history/\(id)")
        }
        await historyCache.setDetailTask(task, for: id)

        do {
            let detail = try await task.value
            await historyCache.storeDetail(detail, for: id)
            return detail
        } catch {
            await historyCache.clearDetailTask(for: id)
            throw error
        }
    }

    func exportResume(
        resumeName: String,
        optimizedText: String,
        format: ResumeExportFormat
    ) async throws -> ResumeExportFile {
        let cleanedText = Self.sanitizeResumeText(optimizedText)
        guard !cleanedText.isEmpty else {
            throw APIError.server(statusCode: 422, message: "No optimized resume is ready to export yet.")
        }

        let document = Self.extractDocument(from: cleanedText, fallbackTitle: resumeName)
        let data = try await Task.detached(priority: .userInitiated) {
            try Self.makeExportData(document: document, format: format)
        }.value

        let fileURL = try await Task.detached(priority: .utility) {
            try Self.writeExportData(
                data,
                resumeName: resumeName,
                format: format
            )
        }.value

        return ResumeExportFile(url: fileURL, format: format)
    }
}

private actor ResumeHistoryCacheStore {
    private var history: [HistoryListItem]?
    private var historyUpdatedAt: Date?
    private var historyTaskValue: Task<[HistoryListItem], Error>?
    private var detailCache: [Int: HistoryDetailResponse] = [:]
    private var detailTasks: [Int: Task<HistoryDetailResponse, Error>] = [:]
    private let historyTTL: TimeInterval = 120

    func cachedHistory(now: Date = .now) -> [HistoryListItem]? {
        guard let history, let historyUpdatedAt else { return nil }
        guard now.timeIntervalSince(historyUpdatedAt) < historyTTL else { return nil }
        return history
    }

    func historyTask() -> Task<[HistoryListItem], Error>? {
        historyTaskValue
    }

    func setHistoryTask(_ task: Task<[HistoryListItem], Error>) {
        historyTaskValue = task
    }

    func clearHistoryTask() {
        historyTaskValue = nil
    }

    func storeHistory(_ items: [HistoryListItem], now: Date = .now) {
        history = items
        historyUpdatedAt = now
        historyTaskValue = nil
    }

    func cachedDetail(for id: Int) -> HistoryDetailResponse? {
        detailCache[id]
    }

    func detailTask(for id: Int) -> Task<HistoryDetailResponse, Error>? {
        detailTasks[id]
    }

    func setDetailTask(_ task: Task<HistoryDetailResponse, Error>, for id: Int) {
        detailTasks[id] = task
    }

    func clearDetailTask(for id: Int) {
        detailTasks[id] = nil
    }

    func storeDetail(_ detail: HistoryDetailResponse, for id: Int) {
        detailCache[id] = detail
        detailTasks[id] = nil
    }
}

private extension ResumeService {
    struct ResumeDocumentSection {
        let heading: String
        var lines: [ResumeDocumentLine]
    }

    enum ResumeDocumentLine: Hashable {
        case text(String)
        case bullet(String)
        case blank
    }

    struct ResumeDocument {
        let cleanedText: String
        let title: String
        let headerDetails: [String]
        let sections: [ResumeDocumentSection]
    }

    static func sanitizeResumeText(_ input: String) -> String {
        guard !input.isEmpty else { return "" }
        return input
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: #"[\u0000-\u0008\u000B-\u001F\u007F]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\*\*(.*?)\*\*"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"`+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^CVboosta\s*•\s*Page.*$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^CVboosta\s*•\s*P.*$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^\s*[•·]\s*$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extractDocument(from cleanedText: String, fallbackTitle: String) -> ResumeDocument {
        let lines = cleanedText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .newlines) }
        let titleLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? fallbackTitle
        let title = extractNameOnly(from: titleLine).isEmpty ? fallbackTitle : extractNameOnly(from: titleLine)
        let headerDetails = extractHeaderDetails(from: lines, titleLine: titleLine)
        var sections: [ResumeDocumentSection] = []
        var currentSection: ResumeDocumentSection?

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .newlines)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                if currentSection != nil {
                    currentSection?.lines.append(.blank)
                }
                continue
            }

            if trimmed == titleLine.trimmingCharacters(in: .whitespaces) {
                continue
            }

            if isSectionHeading(trimmed) {
                if let currentSection {
                    sections.append(currentSection)
                }
                currentSection = ResumeDocumentSection(
                    heading: trimmed.replacingOccurrences(of: ":", with: ""),
                    lines: []
                )
                continue
            }

            if currentSection == nil {
                currentSection = ResumeDocumentSection(heading: "Summary", lines: [])
            }

            currentSection?.lines.append(parsedLine(from: trimmed))
        }

        if let currentSection {
            sections.append(currentSection)
        }

        if !headerDetails.isEmpty, !sections.isEmpty {
            var firstSection = sections[0]
            var skipped = 0
            firstSection.lines = firstSection.lines.filter { line in
                guard skipped < headerDetails.count else { return true }
                let detail = headerDetails[skipped]
                switch line {
                case .text(let value) where value == detail:
                    skipped += 1
                    return false
                case .bullet(let value) where value == detail:
                    skipped += 1
                    return false
                default:
                    return true
                }
            }
            sections[0] = firstSection
        }

        return ResumeDocument(
            cleanedText: cleanedText,
            title: title,
            headerDetails: headerDetails,
            sections: sections
        )
    }

    static func parsedLine(from trimmed: String) -> ResumeDocumentLine {
        let patterns = [
            #"^(?:[•\-\*●○■□])\s+(.*)$"#,
            #"^(?:[•\-\*●○■□])(.*)$"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
               let range = Range(match.range(at: 1), in: trimmed) {
                let bulletText = trimmed[range].trimmingCharacters(in: .whitespacesAndNewlines)
                if !bulletText.isEmpty {
                    return .bullet(bulletText)
                }
            }
        }

        return .text(trimmed)
    }

    static func isSectionHeading(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ":", with: "")
        guard !trimmed.isEmpty else { return false }

        let key = trimmed.lowercased()
        let known: Set<String> = [
            "summary",
            "profile",
            "experience",
            "work experience",
            "employment",
            "education",
            "skills",
            "projects",
            "certifications",
            "certificates",
            "awards",
            "languages",
            "volunteering",
            "interests",
            "technical skills",
            "hard skills",
            "soft skills",
            "contact",
            "контакти",
            "досвід",
            "досвід роботи",
            "освіта",
            "навички",
            "курси",
            "сертифікати",
            "проекти",
            "професійний досвід"
        ]

        if known.contains(key) {
            return true
        }

        if trimmed.count > 48 {
            return false
        }

        let letters = trimmed.replacingOccurrences(
            of: #"[^A-Za-zА-Яа-яЁёІіЇїЄє]"#,
            with: "",
            options: .regularExpression
        )

        guard letters.count >= 4 else { return false }

        let uppercaseLetters = letters.replacingOccurrences(
            of: #"[^A-ZА-ЯЁІЇЄ]"#,
            with: "",
            options: .regularExpression
        )

        return Double(uppercaseLetters.count) / Double(letters.count) > 0.8
    }

    static func extractNameOnly(from titleLine: String) -> String {
        let raw = titleLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "Optimized CV" }

        let patterns = [
            #"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#,
            #"\+?\d[\d\s().-]{7,}\d"#,
            #"\b(?:https?:\/\/|www\.)\S+\b"#,
            #"\b(?:linkedin|github)\b[:/\s-]*\S*"#
        ]

        let cleaned = patterns.reduce(raw) { partial, pattern in
            partial.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        .replacingOccurrences(of: #"[|•]"#, with: " ", options: .regularExpression)
        .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return "Optimized CV" }
        return cleaned.split(whereSeparator: \.isWhitespace).prefix(4).joined(separator: " ")
    }

    static func extractHeaderDetails(from lines: [String], titleLine: String) -> [String] {
        let normalizedLines = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !normalizedLines.isEmpty else { return [] }

        let startIndex = max(0, normalizedLines.firstIndex(of: titleLine.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0)
        var details: [String] = []

        for index in normalizedLines.indices where index > startIndex {
            let line = normalizedLines[index]
            if isSectionHeading(line) { break }
            let normalizedBullet = line.replacingOccurrences(
                of: #"^(?:[•\-\*]+)\s+"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !normalizedBullet.isEmpty else { continue }
            details.append(normalizedBullet)
            if details.count >= 3 { break }
        }

        return details
    }

    static func makeExportData(document: ResumeDocument, format: ResumeExportFormat) throws -> Data {
        switch format {
        case .pdf:
            return try makePDFData(from: attributedDocument(for: document))
        case .docx:
            let attributed = attributedDocument(for: document)
            return try attributed.data(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType(rawValue: "org.openxmlformats.wordprocessingml.document")]
            )
        case .txt:
            guard let data = document.cleanedText.data(using: .utf8) else {
                throw APIError.server(statusCode: 500, message: "Could not encode TXT export.")
            }
            return data
        }
    }

    static func attributedDocument(for document: ResumeDocument) -> NSAttributedString {
        let titleStyle = NSMutableParagraphStyle()
        titleStyle.lineSpacing = 2
        titleStyle.paragraphSpacing = 18

        let detailStyle = NSMutableParagraphStyle()
        detailStyle.lineSpacing = 1
        detailStyle.paragraphSpacing = 4

        let headingStyle = NSMutableParagraphStyle()
        headingStyle.paragraphSpacingBefore = 12
        headingStyle.paragraphSpacing = 8

        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.lineSpacing = 3
        bodyStyle.paragraphSpacing = 6

        let bulletStyle = NSMutableParagraphStyle()
        bulletStyle.firstLineHeadIndent = 0
        bulletStyle.headIndent = 16
        bulletStyle.lineSpacing = 3
        bulletStyle.paragraphSpacing = 6

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: UIColor(red: 0.10, green: 0.18, blue: 0.30, alpha: 1),
            .paragraphStyle: titleStyle
        ]

        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor(red: 0.39, green: 0.44, blue: 0.52, alpha: 1),
            .paragraphStyle: detailStyle
        ]

        let headingAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12.5, weight: .semibold),
            .foregroundColor: UIColor(red: 0.10, green: 0.46, blue: 0.92, alpha: 1),
            .paragraphStyle: headingStyle
        ]

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11.5, weight: .regular),
            .foregroundColor: UIColor(red: 0.12, green: 0.15, blue: 0.20, alpha: 1),
            .paragraphStyle: bodyStyle
        ]

        let bulletAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11.5, weight: .regular),
            .foregroundColor: UIColor(red: 0.12, green: 0.15, blue: 0.20, alpha: 1),
            .paragraphStyle: bulletStyle
        ]

        let output = NSMutableAttributedString(
            string: document.title + "\n",
            attributes: titleAttributes
        )

        if !document.headerDetails.isEmpty {
            for detail in document.headerDetails {
                output.append(NSAttributedString(string: detail + "\n", attributes: detailAttributes))
            }
            output.append(NSAttributedString(string: "\n", attributes: bodyAttributes))
        }

        for section in document.sections {
            output.append(
                NSAttributedString(
                    string: section.heading.uppercased() + "\n",
                    attributes: headingAttributes
                )
            )

            for line in section.lines {
                switch line {
                case .text(let value):
                    output.append(NSAttributedString(string: value + "\n", attributes: bodyAttributes))
                case .bullet(let value):
                    output.append(NSAttributedString(string: "• " + value + "\n", attributes: bulletAttributes))
                case .blank:
                    output.append(NSAttributedString(string: "\n", attributes: bodyAttributes))
                }
            }

            output.append(NSAttributedString(string: "\n", attributes: bodyAttributes))
        }

        return output
    }

    static func makePDFData(from attributed: NSAttributedString) throws -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let textRect = pageRect.insetBy(dx: 42, dy: 48)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            let textStorage = NSTextStorage(attributedString: attributed)
            let layoutManager = NSLayoutManager()
            textStorage.addLayoutManager(layoutManager)

            var renderedGlyphs = 0
            var pageIndex = 0

            while renderedGlyphs < layoutManager.numberOfGlyphs || (pageIndex == 0 && attributed.length > 0) {
                let container = NSTextContainer(size: textRect.size)
                container.lineFragmentPadding = 0
                layoutManager.addTextContainer(container)

                let glyphRange = layoutManager.glyphRange(for: container)
                guard glyphRange.length > 0 || pageIndex == 0 else { break }

                context.beginPage()
                layoutManager.drawBackground(forGlyphRange: glyphRange, at: textRect.origin)
                layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: textRect.origin)

                renderedGlyphs = NSMaxRange(glyphRange)
                pageIndex += 1
            }
        }
    }

    static func writeExportData(
        _ data: Data,
        resumeName: String,
        format: ResumeExportFormat
    ) throws -> URL {
        let sanitizedName = sanitizedFilename(from: resumeName)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sanitizedName)-\(UUID().uuidString)")
            .appendingPathExtension(format.fileExtension)

        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }

    static func sanitizedFilename(from rawValue: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleanedScalars = rawValue.unicodeScalars.map { scalar -> String in
            invalidCharacters.contains(scalar) ? " " : String(scalar)
        }

        let collapsed = cleanedScalars
            .joined()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return collapsed.isEmpty ? "Optimized Resume" : collapsed
    }
}
