//
//  ResumeSkills.swift
//  JobShop
//
//  Created by Mansi Madhani on 11/5/26.
//

import Foundation
import FirebaseAILogic

struct SkillMatchResponse: Codable {
    let matchedSkills: [String]
}

class ResumeSkills {

    // Gemini model
    private let model: GenerativeModel

    init() {
        let ai = FirebaseAI.firebaseAI(backend: .googleAI())
        let jsonSchema = Schema.object(
            properties: [
                "matchedSkills": Schema.array(
                    items: .string()
                )
            ]
        )

        // initialize model
        model = ai.generativeModel(
            modelName: "gemini-3.8-flash",
            generationConfig: GenerationConfig(
                responseMIMEType: "application/json",
                responseSchema: jsonSchema
            )
        )
    }
    
    func loadSkills() -> [String] {
        return loadCSV(fileName: "skills")
    }

    // function for reading a CSV file
    func loadCSV(fileName: String) -> [String] {
        guard let url = Bundle.main.url(
            forResource: fileName,
            withExtension: "csv"
        ) else {
            print("Unable to find \(fileName).csv")
            return []
        }

        guard let data = try? String(contentsOf: url, encoding: .utf8) else {
            print("Unable to read \(fileName).csv")
            return []
        }

        let values = data.components(separatedBy: .newlines)

        let cleanedValues = values.compactMap { value -> String? in
            let name = value.trimmingCharacters(in: .whitespacesAndNewlines)

            if name.isEmpty {
                return nil
            }

            return name
        }

        // Remove duplicates and alphabetize
        return Array(Set(cleanedValues)).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    // Match resume skills against skills from our csv file
    func matchSkills(
        resumeText: String
    ) async throws -> [String] {

        let skills = loadSkills()
        let skillsProcessed = skills.joined(separator: ", ")
        let prompt = """
        You are a resume skill extraction assistant.

        Analyze the resume and identify all skills demonstrated through
        education, work experience, projects, and the candidate's listed skills.

        AVAILABLE SKILLS:
        \(skillsProcessed)

        RESUME:
        \(resumeText)

        RULES:
        1. Only return skills that exist in the AVAILABLE SKILLS list.
        2. Recognize synonyms, abbreviations, acronyms, and alternative names.
        3. Map equivalent terms in the resume to the exact skill name in the AVAILABLE SKILLS list.

        Examples:
        - JS, Javascript, and Java Script -> JavaScript
        - React.js -> React
        - Node -> Node.js
        - Postgres -> PostgreSQL
        - Object-Oriented Programming -> OOP
        - ML -> Machine Learning
        - UI/UX -> UI/UX Design (if that exact skill exists in the list)

        4. Return the exact spelling and capitalization used in the AVAILABLE SKILLS list.
        5. Do not return duplicate skills.
        6. Do not infer skills without reasonable evidence in the resume.
        7. Return an empty array if no skills match.

        Return only skills from the AVAILABLE SKILLS list.
        """

        // send prompt to Gemini
        let response = try await model.generateContent(prompt)
        guard let responseText = response.text,
              let data = responseText.data(using: .utf8) else {
            throw NSError(
                domain: "ResumeSkills",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Gemini returned an empty response."
                ]
            )
        }
        let decodedResponse = try JSONDecoder().decode(
            SkillMatchResponse.self,
            from: data
        )

        // only keep skills that actually exist in the CSV
        let availableSkillSet = Set(skills)

        let validSkills = decodedResponse.matchedSkills.filter {
            availableSkillSet.contains($0)
        }

        // remove duplicates
        var seenSkills = Set<String>()
        let uniqueSkills = validSkills.filter {
            seenSkills.insert($0).inserted
        }
        return uniqueSkills
    }
}

