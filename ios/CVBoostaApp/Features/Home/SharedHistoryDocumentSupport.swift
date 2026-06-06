import SwiftUI
import PDFKit
import UIKit

struct HistoryPDFPreviewDocument: Identifiable {
    let id: Int
    let title: String
    let fileURL: URL
}

enum SharedHistoryPDFBuilder {
    static func makeResumePDF(item: HistoryListItem, detail: HistoryDetailResponse) throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("cvboosta-history-\(UUID().uuidString).pdf")
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        try renderer.writePDF(to: outputURL) { context in
            let layout = PDFLayout(context: context, pageRect: pageRect)
            layout.beginPage(withHeaderFor: item, detail: detail, pageIndex: 1)

            layout.drawSummaryCard(item: item, detail: detail)
            layout.drawSection(title: "Missing Keywords")
            layout.drawTagCloud(detail.missingSkills.isEmpty ? ["No critical gaps detected"] : detail.missingSkills)

            layout.drawSection(title: "Recommendations")
            layout.drawBullets(detail.recommendations.isEmpty ? ["No recommendations available for this history item."] : detail.recommendations)

            if let coverLetter = detail.coverLetter, !coverLetter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                layout.drawSection(title: "Cover Letter")
                layout.drawParagraphs(coverLetter)
            }

            layout.drawSection(title: "Optimized Resume")
            layout.drawParagraphs(detail.optimizedCV, bodyFont: layout.bodyFont)
        }

        return outputURL
    }
}

struct HistoryPDFPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let document: HistoryPDFPreviewDocument

    var body: some View {
        NavigationStack {
            PDFKitView(url: document.fileURL)
                .navigationTitle(document.title)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { dismiss() }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: document.fileURL)
                    }
                }
        }
    }
}

private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .systemBackground
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(url: url)
    }
}

private final class PDFLayout {
    let context: UIGraphicsPDFRendererContext
    let pageRect: CGRect
    let margin: CGFloat = 40
    let headerHeight: CGFloat = 86
    let footerHeight: CGFloat = 30
    let accent = UIColor(red: 0.10, green: 0.46, blue: 0.92, alpha: 1)
    let accentSoft = UIColor(red: 0.91, green: 0.96, blue: 1.0, alpha: 1)
    let primaryText = UIColor(red: 0.08, green: 0.12, blue: 0.18, alpha: 1)
    let secondaryText = UIColor(red: 0.35, green: 0.41, blue: 0.49, alpha: 1)

    let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
    let sectionFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
    let bodyFont = UIFont.systemFont(ofSize: 11.5, weight: .regular)
    let bodyStrongFont = UIFont.systemFont(ofSize: 11.5, weight: .semibold)
    let smallFont = UIFont.systemFont(ofSize: 9.5, weight: .medium)

    var currentY: CGFloat = 0
    var pageIndex = 1
    var contentWidth: CGFloat { pageRect.width - margin * 2 }
    var bottomLimit: CGFloat { pageRect.height - margin - footerHeight }

    init(context: UIGraphicsPDFRendererContext, pageRect: CGRect) {
        self.context = context
        self.pageRect = pageRect
    }

    func beginPage(withHeaderFor item: HistoryListItem, detail: HistoryDetailResponse, pageIndex: Int) {
        context.beginPage()
        self.pageIndex = pageIndex
        drawPageHeader(item: item, detail: detail)
        drawPageFooter()
        currentY = margin + headerHeight + 18
    }

    func drawSummaryCard(item: HistoryListItem, detail: HistoryDetailResponse) {
        let cardRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 108)
        context.cgContext.saveGState()
        UIBezierPath(roundedRect: cardRect, cornerRadius: 18).addClip()
        accentSoft.setFill()
        UIRectFill(cardRect)
        context.cgContext.restoreGState()

        let scoreRect = CGRect(x: cardRect.maxX - 104, y: cardRect.minY + 16, width: 72, height: 72)
        let scorePath = UIBezierPath(ovalIn: scoreRect)
        scorePath.lineWidth = 8
        UIColor.white.withAlphaComponent(0.75).setStroke()
        scorePath.stroke()

        let scoreValue = detail.matchAfter ?? detail.score
        drawCircularProgress(in: scoreRect, progress: CGFloat(max(min(scoreValue, 100), 0)) / 100)
        drawText("\(scoreValue)", in: scoreRect.offsetBy(dx: 0, dy: 18), font: UIFont.systemFont(ofSize: 22, weight: .bold), color: accent, alignment: .center)
        drawText("ATS", in: scoreRect.offsetBy(dx: 0, dy: 42), font: smallFont, color: secondaryText, alignment: .center)

        drawText(item.role ?? "CV Optimization", at: CGPoint(x: cardRect.minX + 20, y: cardRect.minY + 18), font: sectionFont, color: primaryText)
        drawText(item.company ?? "CVBoosta", at: CGPoint(x: cardRect.minX + 20, y: cardRect.minY + 40), font: bodyFont, color: secondaryText)
        drawText("Created \(detail.createdAt.formatted(date: .abbreviated, time: .shortened))", at: CGPoint(x: cardRect.minX + 20, y: cardRect.minY + 58), font: smallFont, color: secondaryText)

        let deltas = [
            ("Before", detail.matchBefore ?? detail.score),
            ("After", detail.matchAfter ?? detail.score),
            ("Keywords", detail.addedKeywords.count)
        ]

        var chipX = cardRect.minX + 20
        for chip in deltas {
            let label = "\(chip.0): \(chip.1)"
            let chipWidth = (label as NSString).size(withAttributes: [.font: smallFont]).width + 18
            let chipRect = CGRect(x: chipX, y: cardRect.minY + 78, width: chipWidth, height: 22)
            let path = UIBezierPath(roundedRect: chipRect, cornerRadius: 11)
            UIColor.white.withAlphaComponent(0.92).setFill()
            path.fill()
            drawText(label, in: chipRect.insetBy(dx: 9, dy: 4), font: smallFont, color: accent)
            chipX += chipWidth + 8
        }

        currentY = cardRect.maxY + 22
    }

    func drawSection(title: String) {
        ensureSpace(32, fallbackHeaderTitle: title)
        drawText(title.uppercased(), at: CGPoint(x: margin, y: currentY), font: smallFont, color: accent)
        currentY += 20
    }

    func drawTagCloud(_ values: [String]) {
        var x = margin
        var y = currentY
        let horizontalPadding: CGFloat = 10
        let verticalPadding: CGFloat = 6
        let lineHeight: CGFloat = 28

        for value in values {
            let size = (value as NSString).size(withAttributes: [.font: bodyFont])
            let width = min(size.width + horizontalPadding * 2, contentWidth)
            if x + width > pageRect.width - margin {
                x = margin
                y += lineHeight + 8
            }
            if y + lineHeight > bottomLimit {
                beginContinuationPage(title: "Keywords")
                x = margin
                y = currentY
            }
            let rect = CGRect(x: x, y: y, width: width, height: lineHeight)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 14)
            UIColor.white.setFill()
            path.fill()
            drawText(value, in: rect.insetBy(dx: horizontalPadding, dy: verticalPadding), font: bodyFont, color: primaryText)
            x += width + 8
        }

        currentY = y + lineHeight + 18
    }

    func drawBullets(_ bullets: [String]) {
        for bullet in bullets {
            let lines = wrappedLines(for: bullet, font: bodyFont, width: contentWidth - 18)
            ensureSpace(CGFloat(lines.count) * 16 + 4, fallbackHeaderTitle: "Recommendations")
            drawText("•", at: CGPoint(x: margin, y: currentY), font: bodyStrongFont, color: accent)
            drawLines(lines, startX: margin + 16)
            currentY += 6
        }
        currentY += 8
    }

    func drawParagraphs(_ text: String, bodyFont: UIFont) {
        let paragraphs = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        for paragraph in paragraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                currentY += 10
                continue
            }
            let lines = wrappedLines(for: trimmed, font: bodyFont, width: contentWidth)
            ensureSpace(CGFloat(lines.count) * 16 + 6, fallbackHeaderTitle: "Resume")
            drawLines(lines, startX: margin, font: bodyFont, color: primaryText)
            currentY += 6
        }
    }

    private func drawLines(_ lines: [String], startX: CGFloat, font: UIFont? = nil, color: UIColor? = nil) {
        let font = font ?? bodyFont
        let color = color ?? primaryText
        for line in lines {
            ensureSpace(16, fallbackHeaderTitle: "Resume")
            drawText(line, at: CGPoint(x: startX, y: currentY), font: font, color: color)
            currentY += 15.5
        }
    }

    private func ensureSpace(_ height: CGFloat, fallbackHeaderTitle: String) {
        if currentY + height > bottomLimit {
            beginContinuationPage(title: fallbackHeaderTitle)
        }
    }

    private func beginContinuationPage(title: String) {
        let placeholderItem = HistoryListItem(id: 0, role: title, company: nil, score: 0, createdAt: .now, matchBefore: nil, matchAfter: nil)
        let placeholderDetail = HistoryDetailResponse(id: 0, role: title, company: nil, score: 0, createdAt: .now, optimizedCV: "", jobDescription: "", missingSkills: [], recommendations: [], matchBefore: nil, matchAfter: nil, addedKeywords: [], coverLetter: nil)
        beginPage(withHeaderFor: placeholderItem, detail: placeholderDetail, pageIndex: pageIndex + 1)
        drawText("\(title) — continued", at: CGPoint(x: margin, y: currentY), font: bodyStrongFont, color: secondaryText)
        currentY += 20
    }

    private func drawPageHeader(item: HistoryListItem, detail: HistoryDetailResponse) {
        let headerRect = CGRect(x: 0, y: 0, width: pageRect.width, height: margin + headerHeight)
        UIColor.white.setFill()
        UIRectFill(headerRect)

        let topBar = CGRect(x: 0, y: 0, width: pageRect.width, height: 12)
        accent.setFill()
        UIRectFill(topBar)

        drawText("CVBoosta", at: CGPoint(x: margin, y: margin + 6), font: UIFont.systemFont(ofSize: 14, weight: .bold), color: accent)
        drawText(item.role ?? "Optimized Resume", at: CGPoint(x: margin, y: margin + 28), font: titleFont, color: primaryText)
        let subtitle = [item.company, detail.createdAt.formatted(date: .abbreviated, time: .shortened)]
            .compactMap { $0 }
            .joined(separator: " • ")
        drawText(subtitle, at: CGPoint(x: margin, y: margin + 56), font: bodyFont, color: secondaryText)
    }

    private func drawPageFooter() {
        drawText("Generated by CVBoosta", at: CGPoint(x: margin, y: pageRect.height - margin + 6), font: smallFont, color: secondaryText)
        drawText("Page \(pageIndex)", at: CGPoint(x: pageRect.width - margin - 50, y: pageRect.height - margin + 6), font: smallFont, color: secondaryText)
    }

    private func drawCircularProgress(in rect: CGRect, progress: CGFloat) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2 - 4
        let startAngle = -CGFloat.pi / 2
        let endAngle = startAngle + progress * CGFloat.pi * 2

        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        path.lineWidth = 8
        accent.setStroke()
        path.stroke()
    }

    private func wrappedLines(for text: String, font: UIFont, width: CGFloat) -> [String] {
        let words = text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        var lines: [String] = []
        var currentLine = ""

        for word in words {
            let candidate = currentLine.isEmpty ? word : "\(currentLine) \(word)"
            let candidateWidth = (candidate as NSString).size(withAttributes: [.font: font]).width
            if candidateWidth <= width || currentLine.isEmpty {
                currentLine = candidate
            } else {
                lines.append(currentLine)
                currentLine = word
            }
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        return lines
    }

    private func drawText(_ text: String, at point: CGPoint, font: UIFont, color: UIColor) {
        (text as NSString).draw(at: point, withAttributes: [
            .font: font,
            .foregroundColor: color
        ])
    }

    private func drawText(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        (text as NSString).draw(in: rect, withAttributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
    }
}
