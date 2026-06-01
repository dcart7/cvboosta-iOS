import CoreSpotlight
import UniformTypeIdentifiers

final class SpotlightIndexer {
    static let shared = SpotlightIndexer()

    private init() {}

    func indexResume(id: String, role: String, score: Int) {
        let attributes = CSSearchableItemAttributeSet(itemContentType: UTType.text.identifier)
        attributes.title = "\(role) Resume"
        attributes.contentDescription = "ATS score \(score)"
        attributes.keywords = ["resume", "ats", role.lowercased(), "cvboosta"]

        let item = CSSearchableItem(
            uniqueIdentifier: id,
            domainIdentifier: "com.cvboosta.resume",
            attributeSet: attributes
        )

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error {
                print("Spotlight indexing error: \(error)")
            }
        }
    }
}
