import XCTest
@testable import CVBoostaApp

final class ATSResponseParsingTests: XCTestCase {
    func testResumeScanResponseParsing() throws {
        let json = """
        {
          "ats_score": 81,
          "keyword_coverage": 0.73,
          "measurable_impact_ratio": 0.58,
          "readability_score": 0.81,
          "recruiter_signal_score": 0.76,
          "keyword_gaps": ["kubernetes", "observability"],
          "priority_fixes": ["Add metrics", "Add role terms"],
          "weak_bullet_examples": ["Built APIs"],
          "rewrite_suggestions": ["Shipped 12 APIs with 99.9% uptime"],
          "findings": [
            {
              "category": "keywords",
              "severity": 3,
              "message": "Coverage too low",
              "suggestion": "Add role keywords"
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ResumeScanResponse.self, from: json)

        XCTAssertEqual(decoded.atsScore, 81)
        XCTAssertEqual(decoded.keywordGaps, ["kubernetes", "observability"])
        XCTAssertEqual(decoded.findings.first?.severity, 3)
    }
}
