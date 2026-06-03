import Foundation

protocol ResumeAPIServiceProtocol {
    func optimizePDF(
        fileURL: URL,
        targetRole: String,
        jobDescription: String?,
        experienceLevel: String,
        targetMarket: String
    ) async throws -> ResumeScanResponse
}

final class ResumeAPIService: ResumeAPIServiceProtocol {
    private struct ParsedCvResponse: Decodable {
        let rawText: String

        enum CodingKeys: String, CodingKey {
            case rawText = "raw_text"
        }
    }

    private struct AnalyzeCvRequest: Encodable {
        let cvText: String

        enum CodingKeys: String, CodingKey {
            case cvText = "cv_text"
        }
    }

    private struct AnalyzeCvResponse: Decodable {
        let cvAnalysis: String

        enum CodingKeys: String, CodingKey {
            case cvAnalysis = "cv_analysis"
        }
    }

    private struct AnalyzeJobRequest: Encodable {
        let jobText: String

        enum CodingKeys: String, CodingKey {
            case jobText = "job_text"
        }
    }

    private struct AnalyzeJobResponse: Decodable {
        let jobAnalysis: String

        enum CodingKeys: String, CodingKey {
            case jobAnalysis = "job_analysis"
        }
    }

    private struct OptimizeRequest: Encodable {
        let cvText: String
        let jobText: String
        let cvAnalysis: String
        let jobAnalysis: String
        let targetRole: String
        let targetCompany: String

        enum CodingKeys: String, CodingKey {
            case cvText = "cv_text"
            case jobText = "job_text"
            case cvAnalysis = "cv_analysis"
            case jobAnalysis = "job_analysis"
            case targetRole = "target_role"
            case targetCompany = "target_company"
        }
    }

    private struct OptimizeResponse: Decodable {
        let optimizedCV: String
        let feedback: String
        let missingSkills: [String]
        let addedKeywords: [String]
        let recommendations: [String]
        let matchBefore: Int?
        let matchAfter: Int?
        let analysisID: Int?

        enum CodingKeys: String, CodingKey {
            case optimizedCV = "optimized_cv"
            case feedback
            case missingSkills = "missing_skills"
            case addedKeywords = "added_keywords"
            case recommendations
            case matchBefore = "match_before"
            case matchAfter = "match_after"
            case analysisID = "analysis_id"
        }
    }

    private let apiClient: APIClient
    private let client: AuthenticatedAPIClient

    init(
        apiClient: APIClient = .shared,
        client: AuthenticatedAPIClient = .shared
    ) {
        self.apiClient = apiClient
        self.client = client
    }

    func optimizePDF(
        fileURL: URL,
        targetRole: String,
        jobDescription: String?,
        experienceLevel: String,
        targetMarket: String
    ) async throws -> ResumeScanResponse {
        let pdfData = try Data(contentsOf: fileURL)
        let parsed: ParsedCvResponse = try await apiClient.uploadMultipart(
            path: "/analyze/upload",
            fields: [:],
            fileFieldName: "file",
            fileName: fileURL.lastPathComponent,
            mimeType: "application/pdf",
            fileData: pdfData
        )

        let cvText = parsed.rawText
        let jobText = (jobDescription?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? targetRole.trimmingCharacters(in: .whitespacesAndNewlines)

        async let cvAnalysis: AnalyzeCvResponse = apiClient.postJSON(
            path: "/analyze/cv",
            body: AnalyzeCvRequest(cvText: cvText)
        )

        async let jobAnalysis: AnalyzeJobResponse = apiClient.postJSON(
            path: "/analyze/job",
            body: AnalyzeJobRequest(jobText: jobText)
        )

        let optimize = OptimizeRequest(
            cvText: cvText,
            jobText: jobText,
            cvAnalysis: (try? await cvAnalysis.cvAnalysis) ?? "",
            jobAnalysis: (try? await jobAnalysis.jobAnalysis) ?? "",
            targetRole: targetRole,
            targetCompany: ""
        )

        let response: OptimizeResponse = try await client.postJSON(path: "/optimize", body: optimize)

        return ResumeScanResponse(
            atsScore: response.matchBefore ?? response.matchAfter ?? 0,
            matchBefore: response.matchBefore,
            matchAfter: response.matchAfter,
            missingSkills: response.missingSkills,
            addedKeywords: response.addedKeywords,
            recommendations: response.recommendations,
            optimizedCV: response.optimizedCV,
            feedback: response.feedback,
            originalCVText: cvText,
            jobText: jobText,
            analysisID: response.analysisID
        )
    }
}
