import Foundation
import FirebaseAuth
import FirebaseFirestore

enum AdzunaConfig {
    static let appID = "bf747128"
    static let appKey = "8cdebaf06f28419d281f7d3ff754ceca"
    static let country = "us"          // gb, ca, au, de, fr...
    static let currencySymbol = "$"
}

struct JobSearchFilters {
    var location: String?
    var categoryTag: String?
    var fullTime = false
    var partTime = false
    var contract = false
    var permanent = false
    var requiredTerms: [String] = []   // every term must appear in the posting
    var excludedTerms: [String] = []   // none of these may appear
    var salaryMin: Int?
    var maxDaysOld: Int?
}



private struct AdzunaResponse: Decodable {
    let results: [AdzunaJob]
}

private struct AdzunaJob: Decodable {
    let title: String?
    let description: String?
    let redirectUrl: String?
    let company: Company?
    let location: Place?
    let category: Category?
    let salaryMin: Double?
    let salaryMax: Double?
    let salaryIsPredicted: Flag?
    let contractType: String?
    let contractTime: String?

    struct Company: Decodable { let displayName: String? }
    struct Place: Decodable { let displayName: String?; let area: [String]? }
    struct Category: Decodable { let label: String? }
}

private struct Flag: Decodable {
    let isTrue: Bool
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { isTrue = b }
        else if let i = try? c.decode(Int.self) { isTrue = i == 1 }
        else if let s = try? c.decode(String.self) { isTrue = s == "1" || s.lowercased() == "true" }
        else { isTrue = false }
    }
}

private struct UserProfile {
    var skills: [String] = []
    var workingLocations: [String] = []
}


final class JobService {
    static let shared = JobService()
    private init() {}

    private let skillWeight = 0.8
    private let locationWeight = 0.2


    private var cache: [String: (date: Date, jobs: [AdzunaJob])] = [:]


    func fetchJobs(filters: JobSearchFilters = JobSearchFilters(), count: Int = 100) async throws -> [JobCard] {
        let profile = await fetchUserProfile()

        // No location picked in the filter menu: default to the user's first saved physical location.
        var query = filters
        if query.location == nil {
            query.location = profile.workingLocations.first { !isRemote($0) }
        }

        let jobs = try await fetchRaw(filters: query, skills: profile.skills, count: count)
        return jobs.map { makeCard(from: $0, profile: profile) }
    }


    private func fetchRaw(filters f: JobSearchFilters, skills: [String], count: Int) async throws -> [AdzunaJob] {
        var items: [URLQueryItem] = []
        func add(_ name: String, _ value: String?) {
            if let value, !value.isEmpty { items.append(URLQueryItem(name: name, value: value)) }
        }

        // Ask for jobs that mention at least one of the user's skills...
        add("what_or", skills.prefix(8).joined(separator: " "))
        // ...and that satisfy every filter the user picked.
        add("what_and", f.requiredTerms.joined(separator: " "))
        add("what_exclude", f.excludedTerms.joined(separator: " "))
        add("where", f.location)
        add("category", f.categoryTag)
        if f.fullTime { add("full_time", "1") }
        if f.partTime { add("part_time", "1") }
        if f.contract { add("contract", "1") }
        if f.permanent { add("permanent", "1") }
        add("salary_min", f.salaryMin.map(String.init))
        add("max_days_old", f.maxDaysOld.map(String.init))

        let cacheKey = items.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&") + "#\(count)"
        if let hit = cache[cacheKey], Date().timeIntervalSince(hit.date) < 3600 { return hit.jobs }

        // The API returns at most 50 results per page, so page until we have `count`.
        let perPage = min(max(count, 1), 50)
        let pages = Int((Double(max(count, 1)) / Double(perPage)).rounded(.up))
        var all: [AdzunaJob] = []

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        for page in 1...pages {
            var components = URLComponents(string: "https://api.adzuna.com/v1/api/jobs/\(AdzunaConfig.country)/search/\(page)")!
            components.queryItems = [
                URLQueryItem(name: "app_id", value: AdzunaConfig.appID),
                URLQueryItem(name: "app_key", value: AdzunaConfig.appKey),
                URLQueryItem(name: "results_per_page", value: String(perPage))
            ] + items
            guard let url = components.url else { throw URLError(.badURL) }

            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let batch = try decoder.decode(AdzunaResponse.self, from: data).results
            all.append(contentsOf: batch)
            if batch.count < perPage { break }   // no more pages
        }

        cache[cacheKey] = (Date(), all)
        return all
    }


    private func fetchUserProfile() async -> UserProfile {
        guard let uid = Auth.auth().currentUser?.uid else { return UserProfile() }
        do {
            let document = try await Firestore.firestore()
                .collection("accounts").document(uid).getDocument()
            guard let data = document.data() else { return UserProfile() }
            return UserProfile(skills: stringList(data["skills"]),
                               workingLocations: stringList(data["workingLocations"]))
        } catch {
            print("Failed to load user profile: \(error.localizedDescription)")
            return UserProfile()
        }
    }

    private func stringList(_ value: Any?) -> [String] {
        let raw: [String]
        if let arr = value as? [String] { raw = arr }
        else if let s = value as? String { raw = s.components(separatedBy: ",") }
        else { raw = [] }
        return raw.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }


    private func makeCard(from job: AdzunaJob, profile: UserProfile) -> JobCard {
        let title = plainText(from: job.title ?? "Untitled role")
        let description = plainText(from: job.description ?? "")
        let categoryLabel = job.category?.label ?? ""
        let haystack = title + " " + description + " " + categoryLabel

        let matched = profile.skills.filter { mentions($0, in: haystack) }
        let match = matchScore(matchedSkillCount: matched.count, profile: profile,
                               job: job, haystack: haystack)

        let meta = [prettyContract(job.contractTime), prettyContract(job.contractType), categoryLabel]
            .compactMap { $0 }.filter { !$0.isEmpty }
        var allKeywords: [String] = []
        for k in matched + meta where !allKeywords.contains(k) { allKeywords.append(k) }
        let shown = Array(allKeywords.prefix(4))

        return JobCard(
            company: plainText(from: job.company?.displayName ?? "Company not listed"),
            title: title,
            location: job.location?.displayName ?? "Location not listed",
            description: description,
            matchPercent: match,
            keywords: shown,
            extraKeywords: max(0, allKeywords.count - shown.count),
            salary: salaryText(job),
            applyURL: job.redirectUrl.flatMap(URL.init(string:))
        )
    }

    private func prettyContract(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        return raw.replacingOccurrences(of: "_", with: "-").capitalized
    }

    private func salaryText(_ job: AdzunaJob) -> String {
        guard let lo = job.salaryMin, lo > 0 else { return "Salary not listed" }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        func fmt(_ n: Double) -> String { AdzunaConfig.currencySymbol + (f.string(from: NSNumber(value: n)) ?? "\(Int(n))") }
        let estimate = job.salaryIsPredicted?.isTrue == true ? " (est.)" : ""
        if let hi = job.salaryMax, hi > lo { return "\(fmt(lo)) - \(fmt(hi)) annually\(estimate)" }
        return "\(fmt(lo)) annually\(estimate)"
    }


    private func matchScore(matchedSkillCount: Int, profile: UserProfile,
                            job: AdzunaJob, haystack: String) -> Int {
        let skillScore: Double? = profile.skills.isEmpty
            ? nil : Double(matchedSkillCount) / Double(profile.skills.count)
        let locationScore: Double? = profile.workingLocations.isEmpty
            ? nil : (locationFits(profile.workingLocations, job: job, haystack: haystack) ? 1 : 0)

        let combined: Double
        switch (skillScore, locationScore) {
        case let (s?, l?): combined = s * skillWeight + l * locationWeight
        case let (s?, nil): combined = s
        case let (nil, l?): combined = l
        case (nil, nil):    combined = 0
        }
        return min(100, max(0, Int((combined * 100).rounded())))
    }

    private func isRemote(_ location: String) -> Bool {
        ["remote", "anywhere"].contains(location.lowercased())
    }


    private func locationFits(_ userLocations: [String], job: AdzunaJob, haystack: String) -> Bool {
        let areas = ((job.location?.area ?? []) + [job.location?.displayName ?? ""]).map { $0.lowercased() }

        for location in userLocations {
            if isRemote(location) {
                if haystack.lowercased().contains("remote") { return true }
                continue
            }
            let pieces = [location] + location.components(separatedBy: ",")
            for piece in pieces {
                let p = piece.trimmingCharacters(in: .whitespaces).lowercased()
                if p.count >= 2, areas.contains(where: { $0 == p || ($0.count > 2 && p.count > 2 && $0.contains(p)) }) {
                    return true
                }
            }
        }
        return false
    }


    private func mentions(_ skill: String, in text: String) -> Bool {
        let s = skill.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return false }
        let pattern = "(?<![A-Za-z0-9])" + NSRegularExpression.escapedPattern(for: s) + "(?![A-Za-z0-9])"
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func plainText(from html: String) -> String {
        var text = html
            .replacingOccurrences(of: "<br\\s*/?>|</p>|</li>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

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
