import Foundation

extension Bundle {
    var releaseVersionString: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}
