import AppIntents
import Foundation

@available(iOS 16.0, *)
struct RunATSScanIntent: AppIntent {
    static var title: LocalizedStringResource = "Run ATS Scan"

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
