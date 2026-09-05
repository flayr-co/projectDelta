//
//  QuestionTemplate.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 8/13/26.
//
//
//  QuestionTemplate.swift
//  ProjectDelta
//

import Foundation
import FirebaseFirestore

/// Defines the mandatory structure for any algorithmic question generator.
protocol QuestionTemplate {
    var subject: String { get }
    var subtopic: String { get }
    func generate(testId: String?) -> QuestionWrapper
}

final class QuestionGeneratorEngine {
    static let shared = QuestionGeneratorEngine()
    
    // Register all algorithmic templates here.
    private let templates: [QuestionTemplate] = [
        LinearEquationTemplate(),
        RatiosAndProportionsTemplate() // Ensure this matches your new struct
    ]
    
    /// Routes the request to the global Firestore bank first, falling back to algorithmic templates if needed.
    func generateQuestions(subject: String, subtopic: String, count: Int, testId: String?) async -> [QuestionWrapper] {
        let db = Firestore.firestore()
        var fetchedWrappers: [QuestionWrapper] = []
        
        // 1. Query the Global Bank
        do {
            let snapshot = try await db.collection("questions")
                .whereField("subject", isEqualTo: subject)
                .whereField("subtopic", isEqualTo: subtopic)
                .getDocuments()
            
            let dbQuestions = snapshot.documents.compactMap { try? $0.data(as: Question.self) }
            
            if !dbQuestions.isEmpty {
                // Randomize to ensure assessment variance
                let shuffled = dbQuestions.shuffled()
                let selected = Array(shuffled.prefix(count))
                
                fetchedWrappers = selected.map { dbQuestion in
                    var q = dbQuestion
                    q.id = UUID().uuidString // Assign fresh ID for this test instance to prevent global overwrites
                    q.testId = testId
                    return QuestionWrapper(question: q)
                }
            }
        } catch {
            print("Failed to query global question bank: \(error.localizedDescription)")
        }
        
        // If we fulfilled the count from the DB, return early
        if fetchedWrappers.count >= count {
            return fetchedWrappers
        }
        
        let remainingCount = count - fetchedWrappers.count
        
        // 2. Algorithmic Fallback for remaining questions
        let matchingTemplates = templates.filter { $0.subject == subject && $0.subtopic == subtopic }
        
        if !matchingTemplates.isEmpty {
            let algorithmicWrappers = (0..<remainingCount).map { _ in
                let template = matchingTemplates.randomElement()!
                return template.generate(testId: testId)
            }
            fetchedWrappers.append(contentsOf: algorithmicWrappers)
            return fetchedWrappers
        }
        
        // 3. Absolute Fallback Safety
        let blankWrappers = (0..<remainingCount).map { _ in
            QuestionWrapper(question: Question(
                id: UUID().uuidString,
                correctOptionIndex: 0,
                options: ["", "", "", ""],
                points: 10,
                questionText: "",
                type: "multiple_choice",
                subject: subject,
                subtopic: subtopic,
                hint: "No database questions or algorithmic template found for \(subtopic).",
                feedback: "",
                testId: testId
            ))
        }
        
        fetchedWrappers.append(contentsOf: blankWrappers)
        return fetchedWrappers
    }
}
