//
//  QuestionTemplate.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 8/13/26.
//


//
//  QuestionGeneratorEngine.swift
//  ProjectDelta
//

import Foundation

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
        LinearEquationTemplate()
        // Initialize future templates here (e.g., QuadraticTemplate(), PolynomialTemplate())
    ]
    
    /// Routes the request to the correct template and generates the requested number of questions.
    func generateQuestions(subject: String, subtopic: String, count: Int, testId: String?) -> [QuestionWrapper] {
        let matchingTemplates = templates.filter { $0.subject == subject && $0.subtopic == subtopic }
        
        // Fallback safety: If no template exists for the requested lesson, return blank scaffolds.
        guard !matchingTemplates.isEmpty else {
            return (0..<count).map { _ in
                QuestionWrapper(question: Question(
                    id: UUID().uuidString,
                    correctOptionIndex: 0,
                    options: ["", "", "", ""],
                    points: 10,
                    questionText: "",
                    type: "multiple_choice",
                    subject: subject,
                    subtopic: subtopic,
                    hint: "No algorithmic template found for \(subtopic).",
                    feedback: "",
                    testId: testId
                ))
            }
        }
        
        // Execute the algorithmic generation.
        return (0..<count).map { _ in
            let template = matchingTemplates.randomElement()!
            return template.generate(testId: testId)
        }
    }
}