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
    var isGeneratingQuiz: Bool = false
    
    // Snapshot & Evaluation State
    var userAnswers: [String: Int] = [:] // Maps Question ID to selected option index
    var isQuizComplete: Bool = false
    var currentSnapshot: QuizSnapshot?
    
    var subjects: [String] = [
        "Algebra",
        "Advanced Math",
        "Problem Solving & Data Analysis",
        "Geometry & Trigonometry"
    ]
    
    var authViewModel: AuthViewModel
    private let db = Firestore.firestore()
    private let firestoreManager = FirestoreManager()

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
    
    /// Records the user's selected option index for a specific question.
    func selectAnswer(for questionId: String, optionIndex: Int) {
        userAnswers[questionId] = optionIndex
    }
    
    /// The powerhouse of the test system: Fetches 10 random questions filtered by Subject and Subtopic
    func fetchSubtopicTest(for subjectName: String, subtopic: String? = nil) {
        Task {
            self.isGeneratingQuiz = true
            // IMPORTANT: Clear current questions to prevent index out of range crashes during TabView transitions
            self.questions = []
            self.userAnswers = [:]
            self.isQuizComplete = false
            self.currentSnapshot = nil
            
            do {
                var query: Query = db.collection("questions").whereField("subject", isEqualTo: subjectName)
                
                if let subtopic = subtopic, !subtopic.isEmpty {
                    query = query.whereField("subtopic", isEqualTo: subtopic)
                }
                
                let snapshot = try await query.getDocuments()
                let fetchedQuestions = snapshot.documents.compactMap { document -> Question? in
                    try? document.data(as: Question.self)
                }
                
                if fetchedQuestions.isEmpty {
                    print("No questions found for \(subjectName) - \(subtopic ?? "All"). Using fallback data.")
                    self.questions = generateMockQuestions(for: subjectName)
                } else {
                    self.questions = Array(fetchedQuestions.shuffled().prefix(10))
                }
                
            } catch {
                print("Firestore Error: \(error.localizedDescription)")
                self.questions = generateMockQuestions(for: subjectName)
            }
            
            self.isGeneratingQuiz = false
        }
    }
    
    /// Evaluates all recorded answers, builds the immutable snapshot, and persists progress.
    func finishQuiz(subjectId: String, subtopic: String) async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        var correctCount = 0
        var results: [QuestionResult] = []
        
        for question in questions {
            let questionId = question.id ?? UUID().uuidString
            let selectedIndex = userAnswers[questionId]
            let isCorrect = (selectedIndex == question.correctOptionIndex)
            
            if isCorrect {
                correctCount += 1
            }
            
            let result = QuestionResult(
                questionId: questionId,
                questionText: question.questionText,
                options: question.options,
                correctOptionIndex: question.correctOptionIndex,
                userSelectedOptionIndex: selectedIndex,
                isCorrect: isCorrect,
                feedback: question.feedback ?? "No additional feedback provided."
            )
            results.append(result)
            
            // Update continuous progress data per question silently
            do {
                try await firestoreManager.updateUserProgress(userId: userId, subjectId: subjectId, questionId: questionId, isCorrect: isCorrect)
            } catch {
                print("Failed to update continuous progress: \(error.localizedDescription)")
            }
        }
        
        let snapshot = QuizSnapshot(
            userId: userId,
            subjectId: subjectId,
            subtopic: subtopic,
            score: correctCount,
            totalQuestions: questions.count,
            dateTaken: Date(),
            questionResults: results
        )
        
        self.currentSnapshot = snapshot
        
        do {
            try await firestoreManager.saveQuizSnapshot(snapshot)
            let pointsGained = correctCount * 10
            let currentPoints = authViewModel.currentUser?.points ?? 0
            let newTotal = currentPoints + pointsGained
            
            await authViewModel.updateUserPointsInFirestore(newPoints: newTotal)
            await authViewModel.storeTodaysPoints(pointsGainedToday: pointsGained)
            
            self.isQuizComplete = true
        } catch {
            print("Failed to complete quiz pipeline: \(error.localizedDescription)")
        }
    }
    
    func setCurrentQuestionDocId(for index: Int) {
        if index >= 0 && index < questions.count {
            self.currentQuestionDocId = questions[index].id
        }
    }
    
    private func generateMockQuestions(for subject: String) -> [Question] {
        return [
            Question(id: UUID().uuidString, correctOptionIndex: 1, options: ["Option A", "Option B", "Option C", "Option D"], points: 10, questionText: "Calculated \(subject) Question: Solve for x if 2x + 5 = 15.", type: "multipleChoice", subject: subject, hint: "Subtract 5 from both sides first.", feedback: "2x = 10 -> x = 5."),
            Question(id: UUID().uuidString, correctOptionIndex: 2, options: ["12", "24", "48", "96"], points: 10, questionText: "Advanced \(subject) Logic: What is the area of a circle with radius 4?", type: "multipleChoice", subject: subject, hint: "Formula is πr².", feedback: "Area = π(4)² = 16π ≈ 50.26. Closest functional abstract is 48 in this mock data."),
            Question(id: UUID().uuidString, correctOptionIndex: 0, options: ["True", "False"], points: 10, questionText: "Fundamental Theory: Is the square root of 144 equal to 12?", type: "trueFalse", subject: subject, hint: "Multiply 12 by itself.", feedback: "12 * 12 = 144. The principal root is positive 12.")
        ]
    }
}
