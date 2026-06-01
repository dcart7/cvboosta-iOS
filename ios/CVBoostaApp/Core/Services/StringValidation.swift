import Foundation

extension String {
    var isValidEmail: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        let regex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return trimmed.range(of: regex, options: .regularExpression) != nil
    }
}
