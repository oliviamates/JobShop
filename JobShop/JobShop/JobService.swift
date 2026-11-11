import Foundation


private struct JobicyResponse: Decodable {
    let jobs: [JobicyJob]
}

private struct JobicyJob: Decodable {
    let id: Int
    let url: String
    let jobTitle: String
    let companyName: String
    let jobIndustry: StringList?
    let jobType: StringList?
    let jobLevel: String?
    let jobGeo: String?
    let jobExcerpt: String?
    let jobDescription: String?
    let annualSalaryMin: FlexibleNumber?
    let annualSalaryMax: FlexibleNumber?
    let salaryCurrency: String?
}


private struct StringList: Decodable {
    let values: [String]
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let arr = try? c.decode([String].self) { values = arr }
        else if let s = try? c.decode(String.self) { values = [s] }
        else { values = [] }
    }
}


private struct FlexibleNumber: Decodable {
    let value: Double?
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Double.self) { value = d }
        else if let s = try? c.decode(String.self) { value = Double(s) }
        else { value = nil }
    }
}


final class JobService {
    static let shared = JobService()
    private init() {}


    private var cache: (key: String, date: Date, jobs: [JobicyJob])?

    /// geo: "usa", "canada", "europe", "anywhere"... (see https://jobicy.com/api/v2/remote-jobs?get=locations)
    /// industry: "engineering", "marketing"... (see ...?get=industries)
    func fetchJobs(skills: [String],
                   geo: String? = "usa",
                   industry: String? = "engineering",
                   tag: String? = nil,
                   count: Int = 20) async throws -> [JobCard] {
        let cacheKey = "\(geo ?? "")|\(industry ?? "")|\(tag ?? "")|\(count)"
        if let c = cache, c.key == cacheKey, Date().timeIntervalSince(c.date) < 3600 {
            return c.jobs.map { makeCard(from: $0, skills: skills) }
        }

        var components = URLComponents(string: "https://jobicy.com/api/v2/remote-jobs")!
        var items = [URLQueryItem(name: "count", value: String(min(max(count, 1), 100)))]
        if let geo { items.append(URLQueryItem(name: "geo", value: geo)) }
        if let industry { items.append(URLQueryItem(name: "industry", value: industry)) }
        if let tag, tag.count >= 3 { items.append(URLQueryItem(name: "tag", value: tag)) }
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let result = try JSONDecoder().decode(JobicyResponse.self, from: data)
        cache = (cacheKey, Date(), result.jobs)
        return result.jobs.map { makeCard(from: $0, skills: skills) }
    }

    // MARK: - Mapping

    private func makeCard(from job: JobicyJob, skills: [String]) -> JobCard {
        let fullText = plainText(from: job.jobDescription ?? job.jobExcerpt ?? "")
        let haystack = job.jobTitle + " " + fullText

        // Which of the user's skills does this posting mention?
        let matched = skills.filter { mentions($0, in: haystack) }
        let match = skills.isEmpty ? 0 : min(100, Int((Double(matched.count) / Double(skills.count) * 100).rounded()))

        // Keywords: matched skills first, then level/type/industry.
        let meta = [job.jobLevel].compactMap { $0 }
            + (job.jobType?.values ?? [])
            + (job.jobIndustry?.values ?? [])
        let allKeywords = (matched + meta.map(plainText)).filter { !$0.isEmpty }
        let shown = Array(allKeywords.prefix(4))

        return JobCard(
            company: plainText(from: job.companyName),
            title: plainText(from: job.jobTitle),
            location: job.jobGeo?.isEmpty == false ? "Remote – \(job.jobGeo!)" : "Remote",
            description: fullText,
            matchPercent: match,
            keywords: shown,
            extraKeywords: max(0, allKeywords.count - shown.count),
            salary: salaryText(job),
            applyURL: URL(string: job.url)
        )
    }

    /// Whole-word, case-insensitive match, so "Java" doesn't match "JavaScript"
    /// and "iOS" doesn't match "scenarios". Works for skills like "C++", "C#" and ".NET".
    private func mentions(_ skill: String, in text: String) -> Bool {
        let s = skill.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return false }
        let pattern = "(?<![A-Za-z0-9])" + NSRegularExpression.escapedPattern(for: s) + "(?![A-Za-z0-9])"
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func salaryText(_ job: JobicyJob) -> String {
        guard let lo = job.annualSalaryMin?.value, lo > 0 else { return "Salary not listed" }
        let symbol = ["USD": "$", "EUR": "€", "GBP": "£"][job.salaryCurrency ?? "USD"] ?? ((job.salaryCurrency ?? "") + " ")
        func fmt(_ n: Double) -> String { "\(symbol)\(Int(n))" }
        if let hi = job.annualSalaryMax?.value, hi > lo { return "\(fmt(lo)) - \(fmt(hi)) annually" }
        return "\(fmt(lo)) annually"
    }

    /// Descriptions are HTML (and titles are sometimes double-encoded); strip tags and decode entities.
    private func plainText(from html: String) -> String {
        var text = html
            .replacingOccurrences(of: "<br\\s*/?>|</p>|</li>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Run twice so "&amp;#8211;" becomes "&#8211;" and then "–".
        for _ in 0..<2 {
            let named = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
                         "&#39;": "'", "&nbsp;": " ", "&rsquo;": "’", "&ndash;": "–"]
            for (k, v) in named { text = text.replacingOccurrences(of: k, with: v) }
            text = decodeNumericEntities(text)
        }
        text = text.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeNumericEntities(_ s: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "&#(\\d+);") else { return s }
        var result = s
        for m in regex.matches(in: s, range: NSRange(s.startIndex..., in: s)).reversed() {
            if let whole = Range(m.range, in: result),
               let num = Range(m.range(at: 1), in: result),
               let code = UInt32(result[num]), let scalar = Unicode.Scalar(code) {
                result.replaceSubrange(whole, with: String(Character(scalar)))
            }
        }
        return result
    }
}
