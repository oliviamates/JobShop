import Foundation
import FirebaseAuth
import FirebaseFirestore


private struct JobicyResponse: Decodable {
    let jobs: [JobicyJob]

    private enum CodingKeys: String, CodingKey { case jobs }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        jobs = (try? c.decode(LossyArray<JobicyJob>.self, forKey: .jobs))?.elements ?? []
    }
}


private struct LossyArray<T: Decodable>: Decodable {
    let elements: [T]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var items: [T] = []
        while !container.isAtEnd {
            if let item = try? container.decode(T.self) {
                items.append(item)
            } else {
                _ = try? container.decode(DiscardedValue.self)   // advance past the bad element
            }
        }
        elements = items
    }
}

private struct DiscardedValue: Decodable {}

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


private enum GeoMapper {

    private static let supported: [(name: String, slug: String)] = [
        ("Anywhere", "anywhere"), ("APAC", "apac"), ("EMEA", "emea"), ("LATAM", "latam"),
        ("Argentina", "argentina"), ("Australia", "australia"), ("Austria", "austria"),
        ("Belgium", "belgium"), ("Brazil", "brazil"), ("Bulgaria", "bulgaria"),
        ("Canada", "canada"), ("China", "china"), ("Costa Rica", "costa-rica"),
        ("Croatia", "croatia"), ("Cyprus", "cyprus"), ("Czechia", "czechia"),
        ("Denmark", "denmark"), ("Estonia", "estonia"), ("Europe", "europe"),
        ("Finland", "finland"), ("France", "france"), ("Germany", "germany"),
        ("Greece", "greece"), ("Hong Kong", "hong-kong"), ("Hungary", "hungary"),
        ("Ireland", "ireland"), ("Israel", "israel"), ("Italy", "italy"), ("Japan", "japan"),
        ("Latvia", "latvia"), ("Lithuania", "lithuania"), ("Malaysia", "malaysia"),
        ("Mexico", "mexico"), ("Netherlands", "netherlands"), ("New Zealand", "new-zealand"),
        ("Norway", "norway"), ("Philippines", "philippines"), ("Poland", "poland"),
        ("Portugal", "portugal"), ("Romania", "romania"), ("Serbia", "serbia"),
        ("Singapore", "singapore"), ("Slovakia", "slovakia"), ("Slovenia", "slovenia"),
        ("South Korea", "south-korea"), ("Spain", "spain"), ("Sweden", "sweden"),
        ("Switzerland", "switzerland"), ("Thailand", "thailand"), ("Türkiye", "turkiye"),
        ("UAE", "united-arab-emirates"), ("UK", "uk"), ("Ukraine", "ukraine"),
        ("USA", "usa"), ("Vietnam", "vietnam"),
    ]

    private static let validSlugs: Set<String> = Set(supported.map(\.slug))

    private static let phraseToSlug: [String: String] = {
        var map: [String: String] = [:]
        for (name, slug) in supported {
            map[normalize(name)] = slug
            map[normalize(slug)] = slug
        }
        let extras: [String: String] = [
            "united states": "usa", "united states of america": "usa", "us": "usa",
            "u s": "usa", "u s a": "usa", "america": "usa",
            "united kingdom": "uk", "great britain": "uk", "britain": "uk", "england": "uk",
            "scotland": "uk", "wales": "uk", "northern ireland": "uk", "gb": "uk",
            "united arab emirates": "united-arab-emirates", "emirates": "united-arab-emirates",
            "turkey": "turkiye", "czech republic": "czechia", "holland": "netherlands",
            "korea": "south-korea", "republic of korea": "south-korea",
            "eu": "europe", "european union": "europe",
            "remote": "anywhere", "worldwide": "anywhere", "global": "anywhere",
            "everywhere": "anywhere", "asia pacific": "apac",
            "latin america": "latam", "middle east": "emea",
        ]
        for (k, v) in extras { map[k] = v }
        return map
    }()

    private static let usStateNames: Set<String> = Set([
        "alabama", "alaska", "arizona", "arkansas", "california", "colorado", "connecticut",
        "delaware", "florida", "georgia", "hawaii", "idaho", "illinois", "indiana", "iowa",
        "kansas", "kentucky", "louisiana", "maine", "maryland", "massachusetts", "michigan",
        "minnesota", "mississippi", "missouri", "montana", "nebraska", "nevada",
        "new hampshire", "new jersey", "new mexico", "new york", "north carolina",
        "north dakota", "ohio", "oklahoma", "oregon", "pennsylvania", "rhode island",
        "south carolina", "south dakota", "tennessee", "texas", "utah", "vermont",
        "virginia", "washington", "west virginia", "wisconsin", "wyoming",
        "district of columbia", "washington dc", "washington d c",
    ])

    private static let usStateCodes: Set<String> = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "ID", "IL", "IN", "IA",
        "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
        "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT",
        "VA", "WA", "WV", "WI", "WY", "DC",
    ]

    private static let canadaProvinceNames: Set<String> = Set([
        "alberta", "british columbia", "manitoba", "new brunswick", "newfoundland and labrador",
        "newfoundland", "nova scotia", "northwest territories", "nunavut", "ontario",
        "prince edward island", "quebec", "saskatchewan", "yukon",
    ])

    private static let canadaProvinceCodes: Set<String> = [
        "AB", "BC", "MB", "NB", "NL", "NS", "NT", "NU", "ON", "PE", "QC", "SK", "YT",
    ]

    private static func normalize(_ s: String) -> String {
        let lowered = s.lowercased().folding(options: .diacriticInsensitive, locale: nil)
        let scalars = lowered.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(scalars).split(separator: " ").joined(separator: " ")
    }

    private static func slug(forComponent raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let norm = normalize(trimmed)
        guard !norm.isEmpty else { return nil }
        if let s = phraseToSlug[norm] { return s }
        if usStateNames.contains(norm) { return "usa" }
        if canadaProvinceNames.contains(norm) { return "canada" }
        // Two-letter codes only count when written in capitals ("TX", not "in" or "or").
        if trimmed.count == 2, trimmed == trimmed.uppercased() {
            if usStateCodes.contains(trimmed) { return "usa" }
            if canadaProvinceCodes.contains(trimmed) { return "canada" }
        }
        return nil
    }

    static func slugs(for location: String) -> [String] {
        // 1. Whole string, e.g. "United States".
        if let s = slug(forComponent: location) { return [s] }

        // 2. Comma/slash separated parts, e.g. "Austin, TX" or "USA, Canada".
        let parts = location.components(separatedBy: CharacterSet(charactersIn: ",;/|"))
        var found: [String] = []
        for part in parts {
            if let s = slug(forComponent: part), !found.contains(s) { found.append(s) }
        }
        if !found.isEmpty { return found }

        // 3. Look for a country name inside free text, e.g. "Berlin Germany".
        var padded = " " + normalize(location) + " "
        padded = padded.replacingOccurrences(of: " new mexico ", with: " ")   // not Mexico
        for (name, slug) in supported where name != "Anywhere" {
            if padded.contains(" " + normalize(name) + " ") && !found.contains(slug) {
                found.append(slug)
            }
        }
        return found
    }

    static func isValid(_ slug: String) -> Bool { validSlugs.contains(slug) }
}



private struct SkillEntry {
    let name: String
    let key: String       // lowercase canonical key
    let isSoft: Bool      // generic/soft skills ("Teamwork", "Research", ...)
    let patterns: [NSRegularExpression]

    func matches(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return patterns.contains { $0.firstMatch(in: text, options: [], range: range) != nil }
    }
}

private enum SkillCatalog {

    static let entries: [SkillEntry] = loadNames().map { makeEntry(name: $0) }

    private static let aliasToKey: [String: String] = {
        var map: [String: String] = [:]
        for e in entries {
            map[e.key] = e.key
            for a in aliases(for: e.name) { map[a.lowercased()] = e.key }
        }
        return map
    }()

    /// Canonical lowercase key for any skill string (falls back to itself).
    static func key(for skill: String) -> String {
        let s = skill.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return aliasToKey[s] ?? s
    }

    /// Whole catalog plus entries for any of the user's skills that aren't in the CSV.
    /// Build once per fetch, not once per job.
    static func candidates(including userSkills: [String]) -> [SkillEntry] {
        let known = Set(entries.map(\.key))
        var extra: [SkillEntry] = []
        var seen = Set<String>()
        for s in userSkills {
            let name = s.trimmingCharacters(in: .whitespacesAndNewlines)
            let k = key(for: name)
            if !name.isEmpty, !known.contains(k), seen.insert(k).inserted {
                extra.append(makeEntry(name: name))
            }
        }
        return entries + extra
    }


    private static func loadNames() -> [String] {
        guard let url = Bundle.main.url(forResource: "skills", withExtension: "csv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("skills.csv not found in the app bundle (check target membership).")
            return ["Swift", "Python", "Java", "JavaScript", "TypeScript", "React", "SQL", "AWS", "Docker", "Git"]
        }
        var seen = Set<String>()
        var names: [String] = []
        for (i, raw) in text.components(separatedBy: .newlines).enumerated() {
            let line = raw
                .replacingOccurrences(of: "\u{FEFF}", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if i == 0, ["skill", "skills", "name"].contains(line.lowercased()) { continue }
            if seen.insert(line.lowercased()).inserted { names.append(line) }
        }
        return names
    }

    private static func makeEntry(name: String) -> SkillEntry {
        var terms = [name] + aliases(for: name)
        // Single letters ("C", "R") would match "R&D", "Vitamin C", etc., so require context.
        if name.count == 1 {
            terms = ["\(name) programming", "\(name) language"] + aliases(for: name)
        }
        let patterns = terms.compactMap { pattern(for: $0) }
        return SkillEntry(name: name,
                          key: name.lowercased(),
                          isSoft: softSkills.contains(name.lowercased()),
                          patterns: patterns)
    }

    private static func pattern(for term: String) -> NSRegularExpression? {
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        // Lookarounds instead of \b, since \b fails next to "+", "#" and ".".
        let p = "(?<![A-Za-z0-9])" + NSRegularExpression.escapedPattern(for: t) + "(?![A-Za-z0-9])"
        // Short or ambiguous terms ("Go", "Swift", "SAP") only match with exact casing.
        let caseSensitive = t.count <= 2 || caseSensitiveTerms.contains(t)
        return try? NSRegularExpression(pattern: p, options: caseSensitive ? [] : [.caseInsensitive])
    }

    // MARK: Configuration

    private static let caseSensitiveTerms: Set<String> = ["Swift", "Go", "Windows", "SAP", "CAD"]


    private static func aliases(for name: String) -> [String] {
        aliasTable[name.lowercased()] ?? []
    }

    private static let aliasTable: [String: [String]] = [
        // Languages
        "c": ["C/C++"],
        "c++": ["cpp"],
        "c#": ["csharp", "C Sharp"],
        "go": ["Golang"],
        "javascript": ["JS", "ECMAScript"],
        "typescript": ["TS"],
        "objective-c": ["ObjC"],
        "r": ["RStudio"],
        "powershell": ["PowerShell Core"],
        // Frameworks / platforms
        "react": ["React.js", "ReactJS"],
        "vue.js": ["Vue", "VueJS"],
        "node.js": ["Node", "NodeJS"],
        "express.js": ["Express", "ExpressJS"],
        "next.js": ["NextJS"],
        "ruby on rails": ["Rails", "RoR"],
        "spring boot": ["Spring Framework"],
        ".net": ["dotnet", ".NET Core"],
        "asp.net": ["ASP.NET Core"],
        "tailwind css": ["Tailwind"],
        "swiftui": ["Swift UI"],
        "android development": ["Android"],
        "ios development": ["iOS"],
        "web development": ["web developer"],
        "mobile app development": ["mobile development", "mobile apps"],
        "full-stack development": ["full stack", "full-stack", "fullstack"],
        "frontend development": ["front-end", "front end", "frontend"],
        "backend development": ["back-end", "back end", "backend"],
        "api development": ["API design", "building APIs"],
        "rest apis": ["REST API", "RESTful", "REST"],
        "microservices": ["microservice"],
        "object-oriented programming": ["OOP", "object oriented"],
        "version control": ["source control"],
        "agile software development": ["Agile"],
        // Cloud / infra
        "microsoft azure": ["Azure"],
        "google cloud platform": ["GCP", "Google Cloud"],
        "aws": ["Amazon Web Services"],
        "kubernetes": ["k8s"],
        "ci/cd": ["continuous integration", "continuous delivery", "continuous deployment"],
        "infrastructure as code": ["IaC", "Terraform", "CloudFormation"],
        "cybersecurity": ["cyber security", "information security"],
        "information security": ["InfoSec"],
        "penetration testing": ["pen testing", "pentesting"],
        "identity and access management": ["IAM"],
        "network administration": ["network admin"],
        "system administration": ["sysadmin", "systems administration"],
        // Data / AI
        "machine learning": ["ML"],
        "artificial intelligence": ["AI"],
        "natural language processing": ["NLP"],
        "generative ai": ["GenAI", "Gen AI"],
        "large language models": ["LLM", "LLMs", "large language model"],
        "data analysis": ["data analyst"],
        "data engineering": ["data engineer"],
        "data science": ["data scientist"],
        "scikit-learn": ["sklearn", "scikit learn"],
        "jupyter notebook": ["Jupyter"],
        "apache spark": ["Spark", "PySpark"],
        "microsoft excel": ["Excel"],
        "microsoft power bi": ["Power BI", "PowerBI"],
        "google analytics": ["GA4"],
        "postgresql": ["Postgres"],
        "mongodb": ["Mongo"],
        "microsoft sql server": ["SQL Server", "MSSQL"],
        "oracle database": ["Oracle DB", "Oracle"],
        "a/b testing": ["split testing", "AB testing"],
        // Design / office
        "ui/ux design": ["UI/UX", "UX design", "UI design"],
        "user experience research": ["UX research"],
        "adobe photoshop": ["Photoshop"],
        "adobe illustrator": ["Illustrator"],
        "adobe indesign": ["InDesign"],
        "adobe premiere pro": ["Premiere Pro", "Premiere"],
        "adobe after effects": ["After Effects"],
        "microsoft powerpoint": ["PowerPoint"],
        "microsoft outlook": ["Outlook"],
        "microsoft sharepoint": ["SharePoint"],
        "microsoft dynamics": ["Dynamics 365"],
        "microsoft project": ["MS Project"],
        "google workspace": ["G Suite", "Google Docs", "Google Sheets"],
        // Business / ops
        "quality assurance": ["QA"],
        "it support": ["IT help desk"],
        "help desk support": ["help desk", "helpdesk"],
        "technical support": ["tech support"],
        "project management": ["project manager"],
        "product management": ["product manager"],
        "business analysis": ["business analyst"],
        "talent acquisition": ["technical recruiting"],
        "social media marketing": ["social media"],
        "seo": ["search engine optimization"],
        // Soft-skill spellings
        "problem solving": ["problem-solving"],
        "complex problem solving": ["complex problem-solving"],
        "attention to detail": ["detail-oriented", "detail oriented"],
        "self-motivation": ["self-motivated", "self motivated"],
        "teamwork": ["team player"],
        "written communication": ["written communication skills"],
        "verbal communication": ["verbal communication skills"],
    ]


    private static let softSkills: Set<String> = Set([
        "Written Communication", "Verbal Communication", "Active Listening", "Presentation Skills",
        "Public Speaking", "Interpersonal Communication", "Collaboration", "Teamwork", "Leadership",
        "Mentoring", "Conflict Resolution", "Negotiation", "Persuasion", "Customer Service",
        "Client Relations", "Stakeholder Management", "Relationship Building", "Problem solving",
        "Critical Thinking", "Complex Problem Solving", "Analytical Thinking", "Decision Making",
        "Judgment", "Creativity", "Adaptability", "Time Management", "Organization",
        "Attention to Detail", "Multitasking", "Self-Motivation", "Initiative", "Learning Agility",
        "Emotional Intelligence", "Social Perceptiveness", "Coordination", "Service Orientation",
        "Instruction", "Training", "Coaching", "People Management", "Resource Management",
        "Financial Resource Management", "Change Management", "Project Planning", "Prioritization",
        "Research", "Information Gathering", "Information Evaluation", "Process Optimization",
        "Continuous Improvement", "Operations Monitoring", "Systems Analysis", "Systems Evaluation",
    ].map { $0.lowercased() })
}

private struct Requirement {
    let key: String
    let name: String     // display name for the chip
    let weight: Double   // 4 = in title, 3 = required, 1 = nice-to-have / soft skill
    let isSoft: Bool
}

/// Per-fetch data so catalog work isn't repeated for every job.
private struct MatchContext {
    let have: Set<String>
    let candidates: [SkillEntry]
}



final class JobService {
    static let shared = JobService()
    private init() {}

    private var cache: [String: (date: Date, jobs: [JobicyJob])] = [:]
    private let cacheTTL: TimeInterval = 3600


    func fetchJobs(skills: [String],
                   uid: String? = Auth.auth().currentUser?.uid,
                   industry: String? = "engineering",
                   tag: String? = nil,
                   count: Int = 20,
                   fallbackGeos: [String] = ["anywhere"]) async throws -> [JobCard] {
        // A Firestore problem shouldn't block jobs from loading.
        let locations: [String]
        do {
            locations = try await loadWorkingLocations(uid: uid)
        } catch {
            print("JobService: couldn't read workingLocations: \(error)")
            locations = []
        }

        // Map whatever the user entered onto locations Jobicy actually supports.
        var geos = orderedUnique(locations.flatMap(GeoMapper.slugs(for:)))
        print("JobService: workingLocations \(locations) -> geos \(geos)")
        if geos.isEmpty { geos = fallbackGeos }

        var raw = try await loadJobs(geos: geos, industry: industry, tag: tag, count: count)

        // Nothing for those locations (e.g. a niche country/industry combo): don't show an empty screen.
        if raw.isEmpty, geos != fallbackGeos {
            print("JobService: no jobs for \(geos), retrying with \(fallbackGeos)")
            raw = try await loadJobs(geos: fallbackGeos, industry: industry, tag: tag, count: count)
        }

        // De-duplicate (a job can appear under several locations), then map.
        var seen = Set<Int>()
        let unique = raw.filter { seen.insert($0.id).inserted }

        let context = MatchContext(have: Set(skills.map(SkillCatalog.key(for:))),
                                   candidates: SkillCatalog.candidates(including: skills))
        return unique.map { makeCard(from: $0, context: context) }
    }


    private func loadJobs(geos: [String], industry: String?, tag: String?, count: Int) async throws -> [JobicyJob] {
        var jobs: [JobicyJob] = []
        var toFetch: [String] = []
        for geo in geos {
            let key = cacheKey(geo: geo, industry: industry, tag: tag, count: count)
            if let c = cache[key], Date().timeIntervalSince(c.date) < cacheTTL {
                jobs += c.jobs
            } else {
                toFetch.append(geo)
            }
        }
        guard !toFetch.isEmpty else { return jobs }

        var firstError: Error?
        var anySuccess = false
        var fetched: [(geo: String, jobs: [JobicyJob])] = []

        await withTaskGroup(of: (String, Result<[JobicyJob], Error>).self) { group in
            for geo in toFetch {
                group.addTask {
                    do {
                        let list = try await JobService.fetchRemote(geo: geo, industry: industry, tag: tag, count: count)
                        return (geo, .success(list))
                    } catch {
                        return (geo, .failure(error))
                    }
                }
            }
            for await (geo, result) in group {
                switch result {
                case .success(let list):
                    anySuccess = true
                    fetched.append((geo, list))
                case .failure(let error):
                    print("JobService: request for geo '\(geo)' failed: \(error)")
                    if firstError == nil { firstError = error }
                }
            }
        }

        if !anySuccess, jobs.isEmpty, let firstError { throw firstError }

        for (geo, list) in fetched {
            if !list.isEmpty {   // don't cache empty results
                cache[cacheKey(geo: geo, industry: industry, tag: tag, count: count)] = (Date(), list)
            }
            jobs += list
        }
        return jobs
    }


    private func loadWorkingLocations(uid: String?) async throws -> [String] {
        guard let uid else { return [] }
        let snapshot = try await Firestore.firestore()
            .collection("accounts")
            .document(uid)
            .getDocument()
        let raw = snapshot.data()?["workingLocations"]

        if let list = raw as? [String] { return list }
        if let single = raw as? String { return [single] }
        if let list = raw as? [[String: Any]] {
            return list.compactMap { item in
                let parts = ["name", "label", "city", "state", "country"].compactMap { item[$0] as? String }
                return parts.isEmpty ? nil : parts.joined(separator: ", ")
            }
        }
        return []
    }

    private func orderedUnique(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { seen.insert($0).inserted }
    }

    private func cacheKey(geo: String, industry: String?, tag: String?, count: Int) -> String {
        "\(geo)|\(industry ?? "")|\(tag ?? "")|\(count)"
    }


    private static func fetchRemote(geo: String, industry: String?, tag: String?, count: Int) async throws -> [JobicyJob] {
        var components = URLComponents(string: "https://jobicy.com/api/v2/remote-jobs")!
        var items = [
            URLQueryItem(name: "count", value: String(min(max(count, 1), 100))),
            URLQueryItem(name: "geo", value: geo),
        ]
        if let industry { items.append(URLQueryItem(name: "industry", value: industry)) }
        if let tag, tag.count >= 3 { items.append(URLQueryItem(name: "tag", value: tag)) }
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(JobicyResponse.self, from: data).jobs
    }


    private func makeCard(from job: JobicyJob, context: MatchContext) -> JobCard {
        let fullText = plainText(from: job.jobDescription ?? job.jobExcerpt ?? "")
        let title = plainText(from: job.jobTitle)

        // What the posting asks for (weighted), and how much of it the user covers.
        let requirements = extractRequirements(title: title, body: fullText, context: context)
        let match = score(requirements: requirements, have: context.have)

        // Chips = skills the posting asks for. Technical skills first (ones the user has,
        // then by importance), then soft skills the user listed.
        let postingSkills = requirements.sorted { a, b in
            if a.isSoft != b.isSoft { return !a.isSoft }
            let aHave = context.have.contains(a.key), bHave = context.have.contains(b.key)
            if aHave != bHave { return aHave }
            if a.weight != b.weight { return a.weight > b.weight }
            return a.name < b.name
        }.map(\.name)

        // If we couldn't find any skills in the posting, fall back to level/type/industry.
        let meta = [job.jobLevel].compactMap { $0 }
            + (job.jobType?.values ?? [])
            + (job.jobIndustry?.values ?? [])
        let allKeywords = (postingSkills.isEmpty ? meta.map(plainText) : postingSkills)
            .filter { !$0.isEmpty }
        let shown = Array(allKeywords.prefix(4))

        return JobCard(
            company: plainText(from: job.companyName),
            title: title,
            location: job.jobGeo?.isEmpty == false ? "Remote – \(job.jobGeo!)" : "Remote",
            description: fullText,
            matchPercent: match,
            keywords: shown,
            extraKeywords: max(0, allKeywords.count - shown.count),
            salary: salaryText(job),
            applyURL: URL(string: job.url)
        )
    }


    private func score(requirements: [Requirement], have: Set<String>) -> Int {
        let technicalTotal = requirements.filter { !$0.isSoft }.reduce(0) { $0 + $1.weight }
        guard technicalTotal > 0 else { return 0 }
        let total = requirements.reduce(0) { $0 + $1.weight }
        let earned = requirements.filter { have.contains($0.key) }.reduce(0) { $0 + $1.weight }
        return min(100, Int((earned / total * 100).rounded()))
    }


    private func extractRequirements(title: String, body: String, context: MatchContext) -> [Requirement] {
        let (requiredPart, _) = splitSections(body)
        let full = title + "\n" + body

        var result: [Requirement] = []
        for entry in context.candidates {
            if entry.isSoft && !context.have.contains(entry.key) { continue }
            guard entry.matches(full) else { continue }   // one cheap pass first

            let weight: Double
            if entry.isSoft {
                weight = 1
            } else if entry.matches(title) {
                weight = 4
            } else if entry.matches(requiredPart) {
                weight = 3
            } else {
                weight = 1   // only appears in the nice-to-have section
            }
            result.append(Requirement(key: entry.key, name: entry.name, weight: weight, isSoft: entry.isSoft))
        }
        return result
    }

    private func splitSections(_ text: String) -> (required: String, preferred: String) {
        let pattern = "(?im)^[\\s•*\\-]*(nice[- ]to[- ]have|preferred( qualifications| skills)?|bonus( points)?|good to have|pluses)\\b[^\\n]{0,30}$"
        guard let r = text.range(of: pattern, options: .regularExpression) else { return (text, "") }
        return (String(text[..<r.lowerBound]), String(text[r.lowerBound...]))
    }


    private func salaryText(_ job: JobicyJob) -> String {
        guard let lo = job.annualSalaryMin?.value, lo > 0 else { return "Salary not listed" }
        let symbol = ["USD": "$", "EUR": "€", "GBP": "£"][job.salaryCurrency ?? "USD"] ?? ((job.salaryCurrency ?? "") + " ")
        func fmt(_ n: Double) -> String { "\(symbol)\(Int(n))" }
        if let hi = job.annualSalaryMax?.value, hi > lo { return "\(fmt(lo)) - \(fmt(hi)) annually" }
        return "\(fmt(lo)) annually"
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
