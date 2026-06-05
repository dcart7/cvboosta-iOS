import SwiftUI
import PDFKit
import UIKit

struct HistoryPDFPreviewDocument: Identifiable {
    let id: Int
    let title: String
    let fileURL: URL
}

enum SharedHistoryPDFBuilder {
    static func makeResumePDF(title: String, subtitle: String, score: Int, body: String) throws -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("cvboosta-history-\(UUID().uuidString).pdf")

        try renderer.writePDF(to: outputURL) { context in
            context.beginPage()

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            let metaAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.label
            ]

            NSString(string: title).draw(at: CGPoint(x: 40, y: 40), withAttributes: titleAttrs)
            NSString(string: "\(subtitle) • ATS \(score)/100").draw(at: CGPoint(x: 40, y: 76), withAttributes: metaAttrs)

            let textRect = CGRect(x: 40, y: 118, width: 532, height: 630)
            NSString(string: body).draw(in: textRect, withAttributes: bodyAttrs)
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
