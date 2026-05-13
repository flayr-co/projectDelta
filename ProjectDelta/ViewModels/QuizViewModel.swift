//
//  QuizViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/27/23.
//

import Foundation
import FirebaseFirestore
import Observation
import SwiftUI

@MainActor
@Observable
class QuizViewModel {
    var questions: [Question] = []
    var currentSubject: Subject?
    var currentQuestionDocId: String?
    var userProgress: UserProgress?
    var testsForSelectedSubject: [Test] = []
    
    // Explicit state to track the loading lifecycle and prevent infinite spinners
    var isGeneratingQuiz: Bool = false
    
    var subjects: [String] = [
        "Algebra",
        "Advanced Math",
        "Problem Solving & Data Analysis",
        "Geometry & Trigonometry"
    ]
    
    var authViewModel: AuthViewModel
    private let db = Firestore.firestore()

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
    
    // MARK: - Random Test Generation
    func fetchRandomTest(for subjectName: String) {
        Task {
            self.isGeneratingQuiz = true
            self.questions = []
            
            do {
                let snapshot = try await db.collection("questions")
                    .whereField("subject", isEqualTo: subjectName)
                    .getDocuments()
                
                let fetchedQuestions = snapshot.documents.compactMap { document -> Question? in
                    try? document.data(as: Question.self)
                }
                
                // Safety net: If Firestore returns nothing, provide mock data to prevent app lockup
                if fetchedQuestions.isEmpty {
                    print("No questions found in Firestore for \(subjectName). Injecting mock data for testing...")
                    self.questions = generateMockQuestions(for: subjectName)
                } else {
                    let shuffledQuestions = fetchedQuestions.shuffled()
                    self.questions = Array(shuffledQuestions.prefix(10))
                }
                
                print("Successfully loaded \(self.questions.count) questions for \(subjectName).")
                
            } catch {
                print("Failed to fetch questions for random test: \(error.localizedDescription)")
                // Even on failure, inject mock data so the UI doesn't break
                self.questions = generateMockQuestions(for: subjectName)
            }
            
            // Explicitly end the loading state
            self.isGeneratingQuiz = false
        }
    }
    
    func setCurrentQuestionDocId(for index: Int) {
        if index < questions.count {
            self.currentQuestionDocId = questions[index].id
        }
    }
    
    func updateUserProgressForSubject(userID: String, subjectArea: SubjectArea, answeredCorrectly: Bool, questionDocumentID: String) async throws {
        // Implementation to persist progress to Firestore
    }
    
    // Fallback generator for development testing
    private func generateMockQuestions(for subject: String) -> [Question] {
        return [
            Question(
                id: UUID().uuidString,
                correctOptionIndex: 1,
                options: ["Option A", "Option B", "Option C", "Option D"],
                points: 10,
                questionText: "Sample \(subject) Question 1: What is the correct answer?",
                type: "multipleChoice",
                subject: subject,
                hint: "Think about the foundational rules of \(subject)."
            ),
            Question(
                id: UUID().uuidString,
                correctOptionIndex: 2,
                options: ["12", "24", "48", "96"],
                points: 10,
                questionText: "Sample \(subject) Question 2: Evaluate the expression.",
                type: "multipleChoice",
                subject: subject,
                hint: "Double check your calculations."
            ),
            Question(
                id: UUID().uuidString,
                correctOptionIndex: 0,
                options: ["True", "False"],
                points: 10,
                questionText: "Sample \(subject) Question 3: Is this statement accurate?",
                type: "trueFalse",
                subject: subject,
                hint: "Consider the definition of the terms used."
            )
        ]
    }
}
